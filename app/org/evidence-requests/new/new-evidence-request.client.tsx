"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

type VendorPick = { id: number; name: string };

export default function NewEvidenceRequestClient(props: {
  orgId: number;
  vendorId: number | null;
  vendorName: string | null;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  // Vendor selection
  const [vendorId, setVendorId] = useState<number | null>(props.vendorId ?? null);
  const [vendorName, setVendorName] = useState<string>(props.vendorName ?? "");
  const [vendorQuery, setVendorQuery] = useState<string>(props.vendorName ?? "");
  const [vendorOpen, setVendorOpen] = useState(false);
  const [vendorLoading, setVendorLoading] = useState(false);
  const [vendorResults, setVendorResults] = useState<VendorPick[]>([]);

  const [label, setLabel] = useState<string>("SOC 2 Type II Report");
  const [description, setDescription] = useState<string>("Upload the latest SOC 2 report.");
  const [kind, setKind] = useState<string>("OTHER");
  const [dueAt, setDueAt] = useState<string>(""); // yyyy-mm-dd
  const [error, setError] = useState<string>("");

  const boxRef = useRef<HTMLDivElement | null>(null);

  const canSubmit = useMemo(() => {
    return Boolean(vendorId) && Boolean(label.trim()) && Boolean(dueAt.trim());
  }, [vendorId, label, dueAt]);

  async function loadVendors(q: string) {
    setVendorLoading(true);
    try {
      const res = await fetch(`/api/org/vendors/search?q=${encodeURIComponent(q)}`, { method: "GET" });
      const data = await res.json().catch(() => ({} as any));
      if (!res.ok || !data?.ok) {
        setVendorResults([]);
        return;
      }
      setVendorResults(Array.isArray(data.vendors) ? data.vendors : []);
    } finally {
      setVendorLoading(false);
    }
  }

  // Initial suggestions when no vendor preselected
  useEffect(() => {
    if (props.vendorId) return;
    loadVendors("");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Debounced search
  useEffect(() => {
    if (props.vendorId) return;
    const t = setTimeout(() => {
      loadVendors(vendorQuery.trim());
    }, 200);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [vendorQuery]);

  // Close dropdown on outside click
  useEffect(() => {
    function onDoc(e: MouseEvent) {
      const el = boxRef.current;
      if (!el) return;
      if (!el.contains(e.target as any)) setVendorOpen(false);
    }
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  function pickVendor(v: VendorPick) {
    setVendorId(v.id);
    setVendorName(v.name);
    setVendorQuery(v.name);
    setVendorOpen(false);
    setError("");
  }

  function clearVendor() {
    if (props.vendorId) return;
    setVendorId(null);
    setVendorName("");
    setVendorQuery("");
    setVendorResults([]);
    setVendorOpen(true);
    loadVendors("");
  }

  async function submit() {
    setError("");

    if (!canSubmit) {
      setError("Vendor, Label, and Due date are required.");
      return;
    }

    try {
      const res = await fetch("/api/org/evidence-requests/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          vendorId: vendorId!,
          label: label.trim(),
          description: description.trim(),
          kind,
          dueAt, // yyyy-mm-dd
        }),
      });

      const data = await res.json().catch(() => ({} as any));
      if (!res.ok || !data?.ok) {
        setError(data?.error || `Failed (${res.status})`);
        return;
      }

      startTransition(() => {
        router.push(`/org/evidence-requests/${data.id}`);
        router.refresh();
      });
    } catch (e: any) {
      setError(e?.message || "Failed to create request.");
    }
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Vendor (Search + Select) */}
        <div ref={boxRef}>
          <label className="text-xs text-white/60">Vendor</label>

          {props.vendorId ? (
            <div className="mt-1 input-glass w-full flex items-center justify-between">
              <span className="text-white/90">{props.vendorName || `Vendor #${props.vendorId}`}</span>
              <span className="text-white/40 text-xs">#{props.vendorId}</span>
            </div>
          ) : (
            <div className="relative">
              <div className="mt-1 flex items-center gap-2">
                <input
                  className="input-glass w-full"
                  placeholder="Search vendors (type a name)..."
                  value={vendorQuery}
                  onChange={(e) => {
                    setVendorQuery(e.target.value);
                    setVendorOpen(true);
                    setVendorId(null);
                    setVendorName("");
                  }}
                  onFocus={() => setVendorOpen(true)}
                />
                <button type="button" className="btn-glass" onClick={clearVendor} title="Clear selection">
                  Clear
                </button>
              </div>

              {vendorId ? (
                <div className="mt-2 text-xs text-white/50">
                  Selected: <span className="text-white/80 font-semibold">{vendorName}</span>{" "}
                  <span className="text-white/40">#{vendorId}</span>
                </div>
              ) : (
                <div className="mt-2 text-xs text-white/40">Pick a vendor from the list.</div>
              )}

              {vendorOpen ? (
                <div className="absolute z-20 mt-2 w-full rounded-2xl border border-white/10 bg-[#0b1020]/95 backdrop-blur p-2 shadow-xl">
                  <div className="px-2 py-1 text-xs text-white/50 flex items-center justify-between">
                    <span>{vendorLoading ? "Searching…" : "Vendors"}</span>
                    <button
                      type="button"
                      className="text-white/50 hover:text-white/80"
                      onClick={() => setVendorOpen(false)}
                    >
                      ✕
                    </button>
                  </div>

                  <div className="max-h-56 overflow-auto">
                    {(vendorResults?.length ?? 0) === 0 ? (
                      <div className="px-2 py-3 text-sm text-white/60">No matches.</div>
                    ) : (
                      vendorResults.map((v) => (
                        <button
                          key={v.id}
                          type="button"
                          className={clsx(
                            "w-full text-left rounded-xl px-3 py-2 hover:bg-white/5",
                            vendorId === v.id && "bg-white/5"
                          )}
                          onClick={() => pickVendor(v)}
                        >
                          <div className="text-sm text-white/90 font-semibold">{v.name}</div>
                          <div className="text-xs text-white/40">#{v.id}</div>
                        </button>
                      ))
                    )}
                  </div>
                </div>
              ) : null}
            </div>
          )}
        </div>

        {/* Due date */}
        <div>
          <label className="text-xs text-white/60">Due date</label>
          <input
            type="date"
            className="input-glass mt-1 w-full"
            value={dueAt}
            onChange={(e) => setDueAt(e.target.value)}
          />
          <p className="mt-1 text-xs text-white/40">
            We’ll show a countdown. Past due will display as{" "}
            <span className="text-red-300 font-semibold">CRITICAL</span>.
          </p>
        </div>

        {/* Label */}
        <div className="md:col-span-2">
          <label className="text-xs text-white/60">Label</label>
          <input
            className="input-glass mt-1 w-full"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="SOC 2 Type II Report"
          />
        </div>

        {/* Description */}
        <div className="md:col-span-2">
          <label className="text-xs text-white/60">Description</label>
          <textarea
            className="input-glass mt-1 w-full min-h-[90px]"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What should the vendor upload?"
          />
        </div>

        {/* Kind */}
        <div>
          <label className="text-xs text-white/60">Kind</label>
          <select className="input-glass mt-1 w-full" value={kind} onChange={(e) => setKind(e.target.value)}>
            <option value="OTHER">OTHER</option>
            <option value="SOC2">SOC2</option>
            <option value="ISO27001">ISO27001</option>
            <option value="POLICY">POLICY</option>
            <option value="PENTEST">PENTEST</option>
          </select>
        </div>
      </div>

      {error ? <div className="text-sm text-red-300">{error}</div> : null}

      <div className="flex justify-end gap-2">
        <button
          type="button"
          className={clsx("btn-primary", (!canSubmit || isPending) && "opacity-60 cursor-not-allowed")}
          onClick={submit}
          disabled={!canSubmit || isPending}
        >
          {isPending ? "Creating..." : "Create request"}
        </button>
      </div>
    </div>
  );
}
