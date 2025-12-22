// components/new-vendor-form.tsx
"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

async function safeJson(res: Response) {
  const txt = await res.text().catch(() => "");
  try {
    return txt ? JSON.parse(txt) : {};
  } catch {
    return { raw: txt };
  }
}

export default function NewVendorForm() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState("");
  const [summary, setSummary] = useState("");
  const [category, setCategory] = useState("");
  const [tier, setTier] = useState("");
  const [criticality, setCriticality] = useState("");

  const canSubmit = useMemo(
    () => name.trim().length > 0 && !pending,
    [name, pending]
  );

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setPending(true);

    try {
      const res = await fetch("/api/vendors", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name,
          summary,
          category,
          tier,
          criticality,
        }),
      });

      const data = await safeJson(res);
      if (!res.ok) {
        setError(String(data?.error ?? "Failed to create vendor."));
        setPending(false);
        return;
      }

      const id = Number(data?.id);
      if (!Number.isFinite(id)) {
        setError("Vendor created, but response did not include a valid id.");
        setPending(false);
        return;
      }

      router.push(`/vendors/${id}`);
      router.refresh();
    } catch (err: any) {
      setError(String(err?.message ?? err));
      setPending(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="glass-soft mt-8 space-y-6 rounded-2xl p-6">
      {error ? (
        <div className="rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
          {error}
        </div>
      ) : null}

      <div>
        <label className="block text-sm font-medium text-slate-200">
          Vendor name
        </label>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          className="input-glass mt-1 text-sm"
          placeholder="Acme Corporation"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-slate-200">
          Summary / Description
        </label>
        <textarea
          value={summary}
          onChange={(e) => setSummary(e.target.value)}
          rows={4}
          className="input-glass mt-1 text-sm"
          placeholder="What does this vendor provide?"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label className="block text-sm font-medium text-slate-200">
            Category
          </label>
          <input
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="input-glass mt-1 text-sm"
            placeholder="Cloud, Payments, Security…"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-200">Tier</label>
          <select
            value={tier}
            onChange={(e) => setTier(e.target.value)}
            className="input-glass mt-1 text-sm"
          >
            <option value="">—</option>
            <option value="CRITICAL">Critical</option>
            <option value="IMPORTANT">Important</option>
            <option value="STANDARD">Standard</option>
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label className="block text-sm font-medium text-slate-200">
            Criticality
          </label>
          <select
            value={criticality}
            onChange={(e) => setCriticality(e.target.value)}
            className="input-glass mt-1 text-sm"
          >
            <option value="">—</option>
            <option value="HIGH">High</option>
            <option value="MEDIUM">Medium</option>
            <option value="LOW">Low</option>
          </select>
        </div>

        <div className="flex items-end justify-end gap-3">
          <Link href="/vendors" className="btn-glass">
            Cancel
          </Link>
          <button type="submit" disabled={!canSubmit} className="btn-primary">
            {pending ? "Creating…" : "Create vendor"}
          </button>
        </div>
      </div>
    </form>
  );
}
