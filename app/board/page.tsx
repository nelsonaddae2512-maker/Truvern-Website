// app/board/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import OrgRequired from "@/components/org-required";
import { computeVendorRiskMap } from "@/lib/risk/vendor-risk";
import PortfolioRiskPanel, {
  type BoardVendorRiskRow,
} from "@/components/board/portfolio-risk-panel";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  if (Number.isNaN(dt.getTime())) return "—";
  return dt.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default async function BoardPage() {
  // ✅ Phase 2A: org-aware soft gate (no middleware, no redirect loops)
  const org = await requireDbOrganization();

  if ((org as any)._needsOrgSelection) {
    return (
      <main className="container-page py-10">
        <section className="glass-soft p-6">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-3xl font-semibold text-white">Board</h1>
                <span className="pill">Portfolio</span>
              </div>
              <p className="mt-2 text-sm text-white/60">
                Portfolio snapshot across vendors. Open counts exclude accepted risk.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <Link href="/vendors" className="btn-glass">
                Vendors
              </Link>
              <Link href="/issues" className="btn-glass">
                Issues
              </Link>
              <Link href="/board-report" className="btn-primary">
                Board Report
              </Link>
            </div>
          </div>

          <div className="mt-6 max-w-2xl">
            <OrgRequired
              title="Select or create an organization to view the Board"
              subtitle="Board reporting is scoped to an organization. Choose one from the top-right menu or create a new org to continue."
            />
          </div>
        </section>
      </main>
    );
  }

  const vendors = await prisma.vendor.findMany({
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    take: 500,
    select: {
      id: true,
      name: true,
      updatedAt: true,
      category: true as any,
    } as any,
  });

  // If Vendor.category doesn't exist in schema, retry without it (no guessing-crashes)
  let safe: any[] = [];
  try {
    safe = vendors as any[];
  } catch {
    safe = await prisma.vendor.findMany({
      orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      take: 500,
      select: { id: true, name: true, updatedAt: true } as any,
    });
  }

  const vendorIds = safe.map((v) => Number(v.id)).filter((n) => Number.isFinite(n));
  const riskMap = await computeVendorRiskMap(vendorIds);

  const rows: BoardVendorRiskRow[] = safe.map((v) => {
    const r = riskMap.get(Number(v.id));
    return {
      vendorId: Number(v.id),
      name: String(v.name ?? "Vendor"),
      updatedAt: v.updatedAt ?? null,
      category: (v as any).category ?? null,
      score: r?.score ?? 100,
      open: r?.open ?? 0, // ✅ already actionable-open only
      accepted: r?.accepted ?? 0,
      resolved: r?.resolved ?? 0,
      bySeverityOpen: r?.bySeverityOpen ?? {
        CRITICAL: 0,
        HIGH: 0,
        MEDIUM: 0,
        LOW: 0,
        INFO: 0,
      },
      topDrivers: r?.topDrivers ?? [],
    };
  });

  // ✅ Phase 327B Step 2: portfolio totals must reflect actionable open only
  const totals = rows.reduce(
    (acc, r) => {
      acc.open += r.open;
      acc.accepted += r.accepted;
      acc.resolved += r.resolved;
      acc.bySeverityOpen.CRITICAL += r.bySeverityOpen.CRITICAL ?? 0;
      acc.bySeverityOpen.HIGH += r.bySeverityOpen.HIGH ?? 0;
      acc.bySeverityOpen.MEDIUM += r.bySeverityOpen.MEDIUM ?? 0;
      acc.bySeverityOpen.LOW += r.bySeverityOpen.LOW ?? 0;
      acc.bySeverityOpen.INFO += r.bySeverityOpen.INFO ?? 0;
      return acc;
    },
    {
      open: 0,
      accepted: 0,
      resolved: 0,
      bySeverityOpen: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 },
    }
  );

  const lastUpdated = safe[0]?.updatedAt ? fmtDate(safe[0].updatedAt) : "—";

  return (
    <main className="container-page py-10">
      {/* Header (Trust Network style) */}
      <section className="glass-soft p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-3xl font-semibold text-white">Board</h1>
              <span className="pill">Open actionable: {totals.open}</span>
              <span className="pill">Accepted: {totals.accepted}</span>
              <span className="pill">Resolved: {totals.resolved}</span>
            </div>

            <p className="mt-2 text-sm text-white/60">
              Portfolio snapshot across vendors. Open counts exclude accepted risk.
            </p>

            <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-white/50">
              <span className="pill">
                Org: <span className="text-white/80">{(org as any).name ?? "—"}</span>
              </span>
              <span className="pill">Vendors: {rows.length}</span>
              <span className="pill">Last updated: {lastUpdated}</span>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Link href="/vendors" className="btn-glass">
              Vendors
            </Link>
            <Link href="/issues" className="btn-glass">
              Issues
            </Link>
            <Link href="/board-report" className="btn-primary">
              Board Report
            </Link>
          </div>
        </div>

        {/* Executive summary row (glass inset) */}
        <div className="mt-4 glass-inset p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="text-sm text-white/80">
              <span className="font-medium text-white">Open actionable risk</span>{" "}
              <span className="text-white/50">(accepted excluded)</span>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <span className="pill">
                Total open: <span className="text-white/90 tabular-nums">{totals.open}</span>
              </span>
              <span className="pill">
                Accepted: <span className="text-white/90 tabular-nums">{totals.accepted}</span>
              </span>
            </div>
          </div>

          <div className="mt-3 text-sm text-white/70">
            Severity totals (open actionable):{" "}
            <span className="ml-2">
              C{" "}
              <span className="font-medium text-white tabular-nums">{totals.bySeverityOpen.CRITICAL}</span>{" "}
              <span className="text-white/30">•</span> H{" "}
              <span className="font-medium text-white tabular-nums">{totals.bySeverityOpen.HIGH}</span>{" "}
              <span className="text-white/30">•</span> M{" "}
              <span className="font-medium text-white tabular-nums">{totals.bySeverityOpen.MEDIUM}</span>{" "}
              <span className="text-white/30">•</span> L{" "}
              <span className="font-medium text-white tabular-nums">{totals.bySeverityOpen.LOW}</span>{" "}
              <span className="text-white/30">•</span> I{" "}
              <span className="font-medium text-white tabular-nums">{totals.bySeverityOpen.INFO}</span>
            </span>
          </div>
        </div>
      </section>

      {/* Panel */}
      <div className="mt-6">
        <PortfolioRiskPanel rows={rows} />
      </div>
    </main>
  );
}
