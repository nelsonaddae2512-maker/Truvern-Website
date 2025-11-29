'use client';

import { useState, FormEvent } from 'react';

type EvidenceItem = {
  id: number;
  filename: string;
  type: string;
  createdAt: string | null;
};

type VendorEvidencePanelProps = {
  vendorId: number;
  initialEvidence: EvidenceItem[];
};

export function VendorEvidencePanel({
  vendorId,
  initialEvidence,
}: VendorEvidencePanelProps) {
  const [evidence, setEvidence] = useState<EvidenceItem[]>(initialEvidence ?? []);
  const [file, setFile] = useState<File | null>(null);
  const [filename, setFilename] = useState('');
  const [type, setType] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!file || !filename.trim() || !type.trim()) {
      setError('Filename, type, and file are required.');
      return;
    }

    setIsSubmitting(true);

    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('vendorId', String(vendorId));
      formData.append('filename', filename.trim());
      formData.append('type', type.trim());

      const res = await fetch('/api/evidence/upload', {
        method: 'POST',
        body: formData,
      });

      const data = await res.json().catch(() => null);

      if (!res.ok) {
        throw new Error(data?.error ?? 'Upload failed');
      }

      const newEvidence = data.evidence as {
        id: number;
        filename: string;
        type: string;
        createdAt?: string | null;
      };

      setEvidence((prev) => [
        {
          id: newEvidence.id,
          filename: newEvidence.filename,
          type: newEvidence.type,
          createdAt: newEvidence.createdAt ?? null,
        },
        ...prev,
      ]);

      // reset form
      setFile(null);
      setFilename('');
      setType('');
      (e.target as HTMLFormElement).reset();

      setSuccess('Evidence saved.');
    } catch (err: any) {
      setError(err?.message ?? 'Upload failed.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="border rounded-lg px-4 py-4 space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h2 className="text-lg font-medium">Evidence</h2>
        {success && (
          <p className="text-xs text-emerald-600">{success}</p>
        )}
      </div>

      <p className="text-sm text-muted-foreground">
        Attach SOC reports, ISO certificates, DPIAs, and other proof that this
        vendor meets your requirements.
      </p>

      <form onSubmit={handleSubmit} className="space-y-3">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">
              File
            </label>
            <input
              type="file"
              className="block w-full text-sm"
              onChange={(e) => {
                const f = e.target.files?.[0] ?? null;
                setFile(f);
                if (f && !filename) {
                  setFilename(f.name);
                }
              }}
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">
              Filename
            </label>
            <input
              type="text"
              className="w-full rounded-md border px-2 py-1.5 text-sm"
              value={filename}
              onChange={(e) => setFilename(e.target.value)}
              placeholder="e.g. Vendor-SOC2-2025.pdf"
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">
              Type
            </label>
            <input
              type="text"
              className="w-full rounded-md border px-2 py-1.5 text-sm"
              value={type}
              onChange={(e) => setType(e.target.value)}
              placeholder="e.g. SOC 2, ISO 27001"
            />
          </div>
        </div>

        {error && (
          <p className="text-xs text-red-600">
            {error}
          </p>
        )}

        {!error && (
          <p className="text-xs text-red-500">
            filename and type are required
          </p>
        )}

        <button
          type="submit"
          disabled={isSubmitting}
          className="inline-flex items-center rounded-md border px-3 py-1.5 text-sm font-medium hover:bg-muted disabled:opacity-60"
        >
          {isSubmitting ? 'Saving…' : 'Upload evidence'}
        </button>
      </form>

      <div className="pt-2 border-t mt-4">
        <h3 className="text-sm font-medium mb-2">Linked evidence</h3>
        {evidence.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            No evidence has been linked to this vendor yet.
          </p>
        ) : (
          <ul className="space-y-1 text-sm">
            {evidence.map((item) => (
              <li
                key={item.id}
                className="flex items-center justify-between rounded-md border px-3 py-2"
              >
                <div>
                  <div className="font-medium">
                    {item.filename}
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {item.type}
                    {item.createdAt
                      ? ` • ${new Date(item.createdAt).toLocaleDateString()}`
                      : null}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}
