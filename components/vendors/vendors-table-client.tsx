// components/vendors/vendors-table-client.tsx
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

type VendorRow = {
  id: number;
  name: string;
  updatedAt: Date | string;
  category?: string | null;
  _count?: {
    assessments?: number;
    issues?: number;
    evidence?: number;
    evidenceRequests?: number;
  };
};

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  if (Number.isNaN(dt.getTime())) return "—";
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "2-digit", day: "2-digit" });
}

/**
 * Lightweight risk heuristic (schema-independent):
 * - HIGH if any issues
 * - MEDIUM if open evidence requests but no evidence
 * - LOW otherwise
 */
function computeRisk(v: VendorRow) {
  const issues = v._count?.issues ?? 0;
  const reqs = v._count?.evidenceRequests ?? 0;
  const evidence = v._count?.evidence ?? 0;

  if (issues > 0) return { label: "High", tone: "bg-rose-500/10 text-rose-200 border-rose-500/30", score: 80 };
  if (reqs > 0 && evidence === 0) return { label: "Medium", tone: "bg-amber-500/10 text-amber-200 border-amber-500/30", score: 55 };
  return { label: "Low", tone: "bg-emerald-500/10 text-emerald-200 border-emerald-500/30", score: 25 };
}

export default function VendorsTableClient({ vendors }: { vendors: VendorRow[] }) {
  const [q, setQ] = useState("");
  const [category, setCategory] = useState<string>("all");
  const [sort, setSort] = useState<"updated" | "name" | "risk">("updated");

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const v of vendors || []) {
      const c = (v.category ?? "").trim();
      if (c) set.add(c);
    }
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [vendors]);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();

    let rows = (vendors || []).filter((v) => {
      if (category !== "all") {
        const c = (v.category ?? "").trim();
        if (c !== category) return false;
      }
      if (!needle) return true;
      const hay = `${v.name ?? ""} ${(v.category ?? "")}`.toLowerCase();
      return hay.includes(needle);
    });

    rows = rows.sort((a, b) => {
      if (sort === "name") return String(a.name).localeCompare(String(b.name));
      if (sort === "risk") return computeRisk(b).score - computeRisk(a).score;

      // updated desc
      const ad = new Date(a.updatedAt as any).getTime();
      const bd = new Date(b.updatedAt as any).getTime();
      if (Number.isFinite(ad) && Number.isFinite(bd) && ad !== bd) return bd - ad;
      return (b.id ?? 0) - (a.id ?? 0);
    });

    return rows;
  }, [vendors, q, category, sort]);

  return (
    <div>
      {/* Controls */}
      <div className="p-4">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-1 flex-col gap-2 sm:flex-row sm:items-center">
            <div className="relative flex-1">
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="Search vendors…"
                className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 outline-none focus:border-sky-500/50"
              />
            </div>

            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-100 outline-none focus:border-sky-500/50"
            >
              <option value="all">All categories</option>
              {categories.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>

            <select
              value={sort}
              onChange={(e) => setSort(e.target.value as any)}
              className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-100 outline-none focus:border-sky-500/50"
            >
              <option value="updated">Sort: Updated</option>
              <option value="name">Sort: Name</option>
              <option value="risk">Sort: Risk</option>
            </select>
          </div>

          <div className="text-xs text-slate-400">
            Showing <span className="text-slate-200">{filtered.length}</span> of{" "}
            <span className="text-slate-200">{vendors?.length ?? 0}</span>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead className="text-left text-xs uppercase tracking-wide text-slate-400">
            <tr className="border-t border-white/10">
              <th className="px-4 py-3">Vendor</th>
              <th className="px-4 py-3">Category</th>
              <th className="px-4 py-3">Risk</th>
              <th className="px-4 py-3">Signals</th>
              <th className="px-4 py-3 text-right">Updated</th>
            </tr>
          </thead>

          <tbody className="text-sm">
            {filtered.map((v) => {
              const risk = computeRisk(v);
              const assessments = v._count?.assessments ?? 0;
              const issues = v._count?.issues ?? 0;
              const evidence = v._count?.evidence ?? 0;
              const reqs = v._count?.evidenceRequests ?? 0;

              return (
                <tr key={v.id} className="border-t border-white/10 hover:bg-white/[0.03]">
                  <td className="px-4 py-3">
                    <Link
                      href={`/vendors/${v.id}`}
                      className="font-medium text-slate-100 hover:underline"
                    >
                      {v.name}
                    </Link>
                    <div className="mt-1 text-xs text-slate-500">ID: {v.id}</div>
                  </td>

                  <td className="px-4 py-3 text-slate-200">{v.category ?? "—"}</td>

                  <td className="px-4 py-3">
                    <span
                      className={clsx(
                        "inline-flex items-center gap-2 rounded-full border px-2.5 py-1 text-xs",
                        risk.tone
                      )}
                      title="Heuristic risk (build mode)"
                    >
                      <span className="font-semibold">{risk.label}</span>
                      <span className="text-slate-300/80">•</span>
                      <span className="tabular-nums text-slate-200">{risk.score}</span>
                    </span>
                  </td>

                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      <span className="rounded-full border border-white/10 bg-white/5 px-2 py-1 text-xs text-slate-200">
                        Assessments: <span className="tabular-nums text-white">{assessments}</span>
                      </span>
                      <span className="rounded-full border border-white/10 bg-white/5 px-2 py-1 text-xs text-slate-200">
                        Evidence: <span className="tabular-nums text-white">{evidence}</span>
                      </span>
                      <span
                        className={clsx(
                          "rounded-full border px-2 py-1 text-xs",
                          issues > 0
                            ? "border-rose-500/30 bg-rose-500/10 text-rose-200"
                            : "border-white/10 bg-white/5 text-slate-200"
                        )}
                      >
                        Findings: <span className="tabular-nums text-white">{issues}</span>
                      </span>
                      <span
                        className={clsx(
                          "rounded-full border px-2 py-1 text-xs",
                          reqs > 0
                            ? "border-amber-500/30 bg-amber-500/10 text-amber-200"
                            : "border-white/10 bg-white/5 text-slate-200"
                        )}
                      >
                        Requests: <span className="tabular-nums text-white">{reqs}</span>
                      </span>
                    </div>
                  </td>

                  <td className="px-4 py-3 text-right text-slate-300">{fmtDate(v.updatedAt)}</td>
                </tr>
              );
            })}

            {filtered.length === 0 && (
              <tr className="border-t border-white/10">
                <td colSpan={5} className="px-4 py-10 text-center text-slate-400">
                  No vendors match your filters.
                  <div className="mt-2 text-xs text-slate-500">
                    Try clearing search/category, or create a new vendor.
                  </div>
                  <div className="mt-4">
                    <Link href="/vendors/new" className="btn-primary">
                      + New Vendor
                    </Link>
                  </div>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
