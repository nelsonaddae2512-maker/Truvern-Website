"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

type Item = {
  title: string;
  fileUrl: string;
  kind: string;
};

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function cleanItems(items: Item[]) {
  return (Array.isArray(items) ? items : [])
    .map((x) => ({
      title: typeof x?.title === "string" ? x.title.trim() : "",
      fileUrl: typeof x?.fileUrl === "string" ? x.fileUrl.trim() : "",
      kind: typeof x?.kind === "string" ? x.kind : "OTHER",
    }))
    .filter((x) => x.title && x.fileUrl);
}

export default function VendorEvidenceRequestSubmitClient(props: {
  requestId: number;
  status: string;
  defaultSelectedIds?: number[]; // kept to match your existing prop shape
  initialItems?: Item[];
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const [items, setItems] = useState<Item[]>(
    Array.isArray(props.initialItems) && props.initialItems.length
      ? props.initialItems
      : [{ title: "", fileUrl: "", kind: "OTHER" }]
  );

  const [error, setError] = useState<string>("");
  const [okMsg, setOkMsg] = useState<string>("");

  const canSubmit = useMemo(() => cleanItems(items).length > 0, [items]);

  function updateItem(i: number, patch: Partial<Item>) {
    setItems((prev) => prev.map((it, idx) => (idx === i ? { ...it, ...patch } : it)));
  }

  function addRow() {
    setItems((prev) => [...prev, { title: "", fileUrl: "", kind: "OTHER" }]);
  }

  function removeRow(i: number) {
    setItems((prev) => prev.filter((_, idx) => idx !== i));
  }

  async function submit() {
    setError("");
    setOkMsg("");

    const payloadItems = cleanItems(items);
    if (!payloadItems.length) {
      setError("Add at least one item with Title and File URL.");
      return;
    }

    try {
      const res = await fetch(`/api/vendor/evidence-requests/${props.requestId}/submit`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ items: payloadItems }),
      });

      const data = await res.json().catch(() => ({} as any));
      if (!res.ok || !data?.ok) {
        setError(data?.error || `Submit failed (${res.status}).`);
        return;
      }

      setOkMsg("Submitted successfully.");

      // Do the "done" action INSIDE the client component (no server->client function props).
      startTransition(() => {
        router.refresh();
      });
    } catch (e: any) {
      setError(e?.message || "Submit failed.");
    }
  }

  return (
    <section className="glass-soft rounded-2xl p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-white">Submit evidence</h2>
          <p className="mt-1 text-sm text-white/70">
            Provide one or more links/files that satisfy this evidence request.
          </p>
        </div>

        <button type="button" className="btn-glass" onClick={addRow} disabled={isPending}>
          + Add item
        </button>
      </div>

      <div className="mt-4 space-y-3">
        {items.map((it, idx) => (
          <div key={idx} className="rounded-xl border border-white/10 bg-white/5 p-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <div className="md:col-span-1">
                <label className="text-xs text-white/60">Title</label>
                <input
                  className="input-glass mt-1 w-full"
                  value={it.title}
                  onChange={(e) => updateItem(idx, { title: e.target.value })}
                  placeholder="SOC 2 Type II Report"
                />
              </div>

              <div className="md:col-span-1">
                <label className="text-xs text-white/60">File URL</label>
                <input
                  className="input-glass mt-1 w-full"
                  value={it.fileUrl}
                  onChange={(e) => updateItem(idx, { fileUrl: e.target.value })}
                  placeholder="https://..."
                />
              </div>

              <div className="md:col-span-1">
                <label className="text-xs text-white/60">Kind</label>
                <select
                  className="input-glass mt-1 w-full"
                  value={it.kind}
                  onChange={(e) => updateItem(idx, { kind: e.target.value })}
                >
                  <option value="OTHER">OTHER</option>
                  <option value="SOC2">SOC2</option>
                  <option value="ISO27001">ISO27001</option>
                  <option value="POLICY">POLICY</option>
                  <option value="PENTEST">PENTEST</option>
                </select>
              </div>
            </div>

            <div className="mt-3 flex justify-end">
              <button
                type="button"
                className={clsx("btn-glass", items.length <= 1 && "opacity-50 cursor-not-allowed")}
                onClick={() => removeRow(idx)}
                disabled={isPending || items.length <= 1}
              >
                Remove
              </button>
            </div>
          </div>
        ))}
      </div>

      {error ? <div className="mt-4 text-sm text-red-300">{error}</div> : null}
      {okMsg ? <div className="mt-4 text-sm text-emerald-300">{okMsg}</div> : null}

      <div className="mt-5 flex items-center justify-end gap-3">
        <button
          type="button"
          className={clsx("btn-primary", (!canSubmit || isPending) && "opacity-60 cursor-not-allowed")}
          onClick={submit}
          disabled={!canSubmit || isPending}
        >
          {isPending ? "Submitting..." : "Submit"}
        </button>
      </div>
    </section>
  );
}
