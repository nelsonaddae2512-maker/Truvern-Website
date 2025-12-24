"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

type TierValue = "" | "LOW" | "IMPORTANT" | "CRITICAL";
type CriticalityValue = "" | "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";

export default function NewVendorForm() {
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState("");
  const [summary, setSummary] = useState("");
  const [category, setCategory] = useState("");
  const [tier, setTier] = useState<TierValue>("");
  const [criticality, setCriticality] = useState<CriticalityValue>("");

  const canSubmit = useMemo(
    () => name.trim().length > 0 && !submitting,
    [name, submitting]
  );

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const payload = {
      name: name.trim(),
      summary: summary.trim() || null,
      category: category.trim() || null,
      tier: tier || null,
      criticality: criticality || null,
    };

    setSubmitting(true);
    try {
      const res = await fetch("/api/vendors", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });

      // If auth redirects or returns HTML, res.json() may throw
      let data: any = null;
      try {
        data = await res.json();
      } catch (jsonErr) {
        const text = await res.text().catch(() => "");
        console.error("POST /api/vendors non-JSON response:", {
          status: res.status,
          text: text?.slice?.(0, 500) ?? text,
        });
        setError(
          `Create failed: server returned non-JSON (HTTP ${res.status}).`
        );
        return;
      }

      // Debug: see what the API returns
      console.log("POST /api/vendors response:", data);

      if (!res.ok || data?.ok === false) {
        setError(data?.error || `Create failed (HTTP ${res.status})`);
        return;
      }

      const vendorId =
        data?.vendorId ??
        data?.id ??
        data?.vendor?.id ??
        data?.vendor?.vendorId;

      if (!vendorId || !Number.isFinite(Number(vendorId))) {
        setError("Vendor created, but response did not include a valid id.");
        return;
      }

      router.push("/vendors");
      router.refresh();
    } catch (err: any) {
      setError(err?.message || "Create failed.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form
      onSubmit={onSubmit}
      className="mt-6 glass-soft p-6 rounded-2xl border border-white/10"
    >
      {error ? (
        <div className="mb-4 rounded-xl border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-slate-100">
            Vendor name
          </label>
          <input
            className="mt-2 w-full input-glass"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Acme Cloud"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-100">
            Summary / Description
          </label>
          <textarea
            className="mt-2 w-full input-glass min-h-[110px]"
            value={summary}
            onChange={(e) => setSummary(e.target.value)}
            placeholder="Short description…"
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-100">
              Category
            </label>
            <input
              className="mt-2 w-full input-glass"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              placeholder="Cloud"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-100">
              Tier
            </label>
            <select
              className="mt-2 w-full input-glass"
              value={tier}
              onChange={(e) => setTier(e.target.value as TierValue)}
            >
              <option value="">—</option>
              <option value="LOW">Low</option>
              <option value="IMPORTANT">Important</option>
              <option value="CRITICAL">Critical</option>
            </select>
          </div>

          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-slate-100">
              Criticality
            </label>
            <select
              className="mt-2 w-full input-glass"
              value={criticality}
              onChange={(e) =>
                setCriticality(e.target.value as CriticalityValue)
              }
            >
              <option value="">—</option>
              <option value="LOW">Low</option>
              <option value="MEDIUM">Medium</option>
              <option value="HIGH">High</option>
              <option value="CRITICAL">Critical</option>
            </select>
          </div>
        </div>

        <div className="pt-2 flex items-center justify-end gap-3">
          <button
            type="button"
            className="btn-glass"
            onClick={() => router.push("/vendors")}
            disabled={submitting}
          >
            Cancel
          </button>

          <button
            type="submit"
            className={clsx(
              "btn-primary",
              submitting && "opacity-70 cursor-not-allowed"
            )}
            disabled={!canSubmit}
          >
            {submitting ? "Creating…" : "Create vendor"}
          </button>
        </div>
      </div>
    </form>
  );
}
