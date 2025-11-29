'use client';

import { useState, useTransition, FormEvent } from 'react';

type EvidenceItemLite = {
  id: number;
  title: string | null;
  type: string | null;
  createdAt: string | null;
};

type Props = {
  vendorId: number;
  initialEvidence: EvidenceItemLite[];
};

export function VendorEvidencePanel({ vendorId, initialEvidence }: Props) {
  const [evidence, setEvidence] = useState<EvidenceItemLite[]>(initialEvidence);
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [kind, setKind] = useState('SOC 2');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!file) {
      setError('Choose a file to upload.');
      return;
    }

    startTransition(async () => {
      try {
        // 1) Ask backend for a presigned URL
        const presignRes = await fetch('/api/evidence/presign', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            vendorId,
            fileName: file.name,
            contentType: file.type || 'application/octet-stream',
            title: title || file.name,
            type: kind,
          }),
        });

        if (!presignRes.ok) {
          let message = `Presign failed (${presignRes.status})`;
          try {
            const data = await presignRes.json();
            if (data?.message || data?.error) {
              message = String(data.message || data.error);
            }
          } catch {
            // ignore JSON parse errors, keep default message
          }
          throw new Error(message);
        }

        const presignData: {
          uploadUrl: string;
          evidenceId?: number;
          fileUrl?: string;
        } = await presignRes.json();

        // 2) Upload the file directly to storage
        const uploadRes = await fetch(presignData.uploadUrl, {
          method: 'PUT',
          body: file,
        });

        if (!uploadRes.ok) {
          throw new Error(`File upload failed (${uploadRes.status})`);
        }

        // 3) Optimistically add to local table
        const nowIso = new Date().toISOString();
        setEvidence((prev) => [
          {
            id: presignData.evidenceId ?? Date.now(),
            title: title || file.name,
            type: kind,
            createdAt: nowIso,
          },
          ...prev,
        ]);

        setFile(null);
        setTitle('');
        setKind('SOC 2');
        (e.target as HTMLFormElement).reset();
        setSuccess('Evidence uploaded successfully.');
      } catch (err: any) {
        console.error(err);
        setError(err?.message || 'Upload failed. Please try again.');
      }
    });
  }

  return (
    <section className="border rounded-lg px-4 py-4 space-y-3">
      <div className="flex items-center justify-between gap-2">
        <h2 className="text-lg font-medium">Evidence</h2>
      </div>

      {/* Upload form */}
      <form
        onSubmit={handleSubmit}
        className="grid gap-3 sm:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_auto]"
      >
        <input
          type="file"
          onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          className="text-sm"
          required
        />

        <div className="flex flex-col gap-1">
          <input
            type="text"
            placeholder="Evidence title (optional)"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="border rounded-md px-2 py-1 text-sm"
          />
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value)}
            className="border rounded-md px-2 py-1 text-sm"
          >
            <option>SOC 2</option>
            <option>ISO 27001</option>
            <option>Pentest report</option>
            <option>DPIA</option>
            <option>Policy document</option>
            <option>Other</option>
          </select>
        </div>

        <button
          type="submit"
          disabled={isPending}
          className="self-start border rounded-md px-3 py-2 text-sm font-medium hover:bg-muted transition-colors disabled:opacity-60"
        >
          {isPending ? 'Uploading…' : 'Upload evidence'}
        </button>
      </form>

      {error && (
        <p className="text-xs text-red-600" role="alert">
          {error}
        </p>
      )}
      {success && (
        <p className="text-xs text-emerald-600" role="status">
          {success}
        </p>
      )}

      {/* Evidence table */}
      {evidence.length === 0 ? (
        <p className="text-sm text-muted-foreground mt-2">
          No evidence has been linked to this vendor yet. You can add SOC
          reports, ISO certificates, DPIAs, and other proof as your workflow
          evolves.
        </p>
      ) : (
        <div className="overflow-x-auto border rounded-md mt-3">
          <table className="min-w-full text-sm">
            <thead className="bg-muted/60">
              <tr className="text-left">
                <th className="px-4 py-2 font-medium">Title</th>
                <th className="px-4 py-2 font-medium">Type</th>
                <th className="px-4 py-2 font-medium">Uploaded</th>
              </tr>
            </thead>
            <tbody>
              {evidence.map((item) => (
                <tr key={item.id} className="border-t">
                  <td className="px-4 py-2">
                    {item.title ?? `Evidence #${item.id}`}
                  </td>
                  <td className="px-4 py-2 text-muted-foreground">
                    {item.type ?? '—'}
                  </td>
                  <td className="px-4 py-2 text-muted-foreground">
                    {item.createdAt
                      ? new Date(item.createdAt).toLocaleDateString()
                      : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
