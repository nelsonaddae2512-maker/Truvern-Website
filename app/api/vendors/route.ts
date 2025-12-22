// app/vendors/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function riskTone(score: number | null | undefined): string {
  if (score == null) return "bg-slate-800 text-slate-200 border-slate-700";
  if (score >= 85) return "bg-emerald-500/10 text-emerald-300 border-emerald-500/60";
  if (score >= 70) return "bg-sky-500/10 text-sky-200 border-sky-500/50";
  if (score >= 50) return "bg-amber-500/10 text-amber-200 border-amber-500/50";
  return "bg-rose-500/10 text-rose-200 border-rose-500/50";
}

export default async function VendorsPage() {
  const org = await requireDbOrganization();
  const organizationId = org.id;

  const vendors = await prisma.vendor.findMany({
    where: { organizationId, deletedAt: null },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      name: true,
      riskScore: true,
      createdAt: true,
      summary: true,
      slug: true,
      category: true,
      tier: true,
      criticality: true,
      status: true,
      updatedAt: true,
      _count: {
        select: { assessments: true, evidence: true },
      },
    },
  });

  return (
    <main className="container-page py-10">
      <div className="flex items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-slate-50">Vendors</h1>
          <p className="mt-1 text-sm text-slate-200/70">
            Your third-party inventory, risk, evidence, and assessments.
          </p>
        </div>

        <Link
          href="/vendors/new"
          className="rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-50 hover:bg-white/10"
        >
          New vendor
        </Link>
      </div>

      <div className="mt-6 overflow-hidden rounded-2xl border border-white/10 bg-slate-950/40">
        <div className="grid grid-cols-12 gap-3 border-b border-white/10 px-5 py-3 text-xs font-semibold text-slate-200/70">
          <div className="col-span-5">Vendor</div>
          <div className="col-span-2">Risk</div>
          <div className="col-span-2">Assessments</div>
          <div className="col-span-2">Evidence</div>
          <div className="col-span-1 text-right">Status</div>
        </div>

        {vendors.length === 0 ? (
          <div className="px-5 py-10 text-sm text-slate-200/70">No vendors yet.</div>
        ) : (
          <div className="divide-y divide-white/5">
            {vendors.map((v) => (
              <Link
                key={v.id}
                href={`/vendors/${v.id}`}
                className="grid grid-cols-12 gap-3 px-5 py-4 hover:bg-white/5"
              >
                <div className="col-span-5">
                  <div className="text-sm font-semibold text-slate-50">{v.name}</div>
                  <div className="mt-1 text-xs text-slate-200/60">
                    {v.category ?? "—"} • {v.tier ?? "—"} • {v.criticality ?? "—"}
                  </div>

                  {v.summary ? (
                    <div className="mt-2 line-clamp-2 text-xs text-slate-200/70">{v.summary}</div>
                  ) : null}
                </div>

                <div className="col-span-2">
                  <span
                    className={[
                      "inline-flex items-center rounded-full border px-2 py-1 text-xs font-semibold",
                      riskTone(v.riskScore),
                    ].join(" ")}
                  >
                    {v.riskScore ?? "—"}
                  </span>
                </div>

                <div className="col-span-2 text-sm text-slate-100">{v._count.assessments}</div>
                <div className="col-span-2 text-sm text-slate-100">{v._count.evidence}</div>

                <div className="col-span-1 text-right text-xs text-slate-200/70">{v.status ?? "—"}</div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
