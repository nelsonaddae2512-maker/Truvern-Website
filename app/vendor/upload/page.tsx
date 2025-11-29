// app/vendor/upload/page.tsx
"use client";

import { useState, FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function VendorUploadPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const vendorIdParam = searchParams.get("vendorId");
  const vendorId = vendorIdParam ? parseInt(vendorIdParam, 10) : NaN;

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [fileUrl, setFileUrl] = useState("");
  const [uploadedBy, setUploadedBy] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!Number.isInteger(vendorId)) {
    return (
      <div className="mx-auto max-w-xl px-4 py-12">
        <h1 className="text-2xl font-semibold mb-4">Upload evidence</h1>
        <p className="text-sm text-red-400">
          Missing or invalid <code>vendorId</code> in the URL.
        </p>
      </div>
    );
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);

    if (!title.trim()) {
      setError("Title is required.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch("/api/evidence/upload", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          vendorId,
          title,
          description,
          fileUrl,
          uploadedBy,
        }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        setError(
          data?.error || `Upload failed with status ${res.status}.`
        );
        setSubmitting(false);
        return;
      }

      // On success, go back to the vendor detail page
      router.push(`/vendors/${vendorId}`);
      router.refresh();
    } catch (err) {
      console.error("Upload error:", err);
      setError("Unexpected error during upload.");
      setSubmitting(false);
    }
  }

  return (
    <div className="mx-auto max-w-xl px-4 py-12 space-y-6">
      <button
        type="button"
        onClick={() => router.back()}
        className="text-sm text-slate-400 hover:text-slate-200 mb-4"
      >
        ← Back
      </button>

      <header>
        <h1 className="text-2xl font-semibold tracking-tight">
          Upload evidence
        </h1>
        <p className="mt-1 text-sm text-slate-400">
          Add supporting documentation for this vendor. Attach a link to
          an external file (for example, Box, Google Drive, SharePoint, or
          a public PDF URL).
        </p>
      </header>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-slate-200 mb-1">
            Title<span className="text-rose-400">*</span>
          </label>
          <input
            type="text"
            className="w-full rounded-md border border-slate-700 bg-slate-900/60 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="SOC 2 report, PEN test, DPIA..."
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-200 mb-1">
            Description / notes
          </label>
          <textarea
            className="w-full rounded-md border border-slate-700 bg-slate-900/60 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
            rows={3}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Short summary of what this evidence covers."
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-200 mb-1">
            Evidence file URL
          </label>
          <input
            type="url"
            className="w-full rounded-md border border-slate-700 bg-slate-900/60 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
            value={fileUrl}
            onChange={(e) => setFileUrl(e.target.value)}
            placeholder="https://..."
          />
          <p className="mt-1 text-xs text-slate-500">
            Paste a link to your evidence file (for now, Truvern stores
            the link, not the binary file).
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-200 mb-1">
            Uploaded by
          </label>
          <input
            type="text"
            className="w-full rounded-md border border-slate-700 bg-slate-900/60 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
            value={uploadedBy}
            onChange={(e) => setUploadedBy(e.target.value)}
            placeholder="Your name or team (optional)"
          />
        </div>

        {error && (
          <div className="rounded-md border border-rose-500/60 bg-rose-950/50 px-3 py-2 text-xs text-rose-100">
            {error}
          </div>
        )}

        <div className="flex items-center justify-between pt-2">
          <button
            type="button"
            onClick={() => router.push(`/vendors/${vendorId}`)}
            className="text-sm text-slate-400 hover:text-slate-200"
          >
            Cancel
          </button>

          <button
            type="submit"
            disabled={submitting}
            className="inline-flex items-center rounded-md bg-emerald-500 px-4 py-2 text-sm font-medium text-black hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-70"
          >
            {submitting ? "Saving..." : "Save evidence"}
          </button>
        </div>
      </form>
    </div>
  );
}
