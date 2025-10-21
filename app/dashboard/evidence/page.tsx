"use client";
import { useEffect, useState } from "react";

type Evidence = {
  id: string;
  filename: string;
  url: string;
  vendor?: string | null;
  size?: number | null;
  createdAt: string;
};

export default function EvidencePage() {
  const [items, setItems] = useState<Evidence[]>([]);
  const [vendor, setVendor] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function load() {
    setErr(null);
    const res = await fetch("/api/evidence/list", { cache: "no-store" });
    if (!res.ok) { setErr("Failed to load"); return; }
    const data = await res.json();
    setItems(data.items ?? []);
  }

  useEffect(() => { load(); }, []);

  async function onUpload(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true); setErr(null);
    const form = new FormData(e.currentTarget);
    const res = await fetch("/api/evidence/upload", { method: "POST", body: form });
    setBusy(false);
    if (!res.ok) { setErr("Upload failed"); return; }
    e.currentTarget.reset();
    setVendor("");
    load();
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-10">
      <h1 className="text-2xl font-bold">Evidence</h1>
      <p className="mt-1 text-zinc-600">Upload vendor evidence and view your recent files.</p>

      <form onSubmit={onUpload} className="mt-6 grid gap-3 rounded-xl border bg-white p-4">
        <div className="grid gap-1">
          <label className="text-sm">Vendor (optional)</label>
          <input name="vendor" value={vendor} onChange={e=>setVendor(e.target.value)} className="rounded-md border px-3 py-2" placeholder="Acme, Globex..." />
        </div>
        <div className="grid gap-1">
          <label className="text-sm">File</label>
          <input name="file" type="file" required className="rounded-md border px-3 py-2" />
        </div>
        <div className="flex gap-3">
          <button disabled={busy} className="rounded-md bg-black px-4 py-2 text-white disabled:opacity-60">{busy ? "Uploading..." : "Upload"}</button>
          {err && <div className="self-center text-sm text-red-600">{err}</div>}
        </div>
      </form>

      <section className="mt-8">
        <h2 className="text-lg font-semibold">Recent evidence</h2>
        <div className="mt-3 grid gap-3">
          {items.map(it => (
            <div key={it.id} className="rounded-lg border bg-white p-3">
              <div className="flex items-center justify-between">
                <div className="font-medium">{it.filename}</div>
                <div className="text-xs text-zinc-500">{new Date(it.createdAt).toLocaleString()}</div>
              </div>
              <div className="mt-1 text-sm text-zinc-600">
                {it.vendor ? `Vendor: ${it.vendor}` : "Vendor: —"} • {it.size ? `${Math.round(it.size/1024)} KB` : "Size: —"}
              </div>
              <div className="mt-2 text-sm">
                <a className="text-blue-700 underline" href={it.url} target="_blank">View (private Blob URL)</a>
              </div>
            </div>
          ))}
          {items.length === 0 && <div className="text-sm text-zinc-500">No evidence yet.</div>}
        </div>
      </section>
    </main>
  );
}
