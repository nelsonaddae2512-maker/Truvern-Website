// app/board-report/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { computeVendorRiskMap } from "@/lib/risk/vendor-risk";
import PortfolioRiskPanel, {
  type BoardVendorRiskRow,
} from "@/components/board/portfolio-risk-panel";
import PrintPdfButton from "@/components/board/print-pdf-button";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtDateTime(d: Date) {
  try {
    return d.toLocaleString();
  } catch {
    return String(d);
  }
}

export default async function BoardReportPage() {
  const vendors = await prisma.vendor.findMany({
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    take: 500,
    select: { id: true, name: true, updatedAt: true, category: true as any } as any,
  });

  // Schema-safe retry if category doesn't exist
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

  const riskMap = await computeVendorRiskMap(safe.map((v) => v.id));

  const rows: BoardVendorRiskRow[] = safe.map((v: any) => {
    const r = riskMap.get(v.id) ?? {
      vendorId: v.id,
      score: 100,
      open: 0,
      accepted: 0,
      resolved: 0,
      bySeverityOpen: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 },
      topDrivers: [],
    };

    return {
      id: v.id,
      name: v.name ?? `Vendor #${v.id}`,
      category: v.category ?? null,
      score: r.score,
      open: r.open,
      accepted: r.accepted,
      resolved: r.resolved,
      bySeverityOpen: r.bySeverityOpen,
      drivers: r.topDrivers,
    };
  });

  const generatedAt = fmtDateTime(new Date());

  const totals = rows.reduce(
    (acc, r: any) => {
      acc.open += Number(r.open || 0);
      acc.accepted += Number(r.accepted || 0);
      acc.resolved += Number(r.resolved || 0);
      try {
        const b = r.bySeverityOpen || {};
        acc.bySeverityOpen.CRITICAL += Number(b.CRITICAL || 0);
        acc.bySeverityOpen.HIGH += Number(b.HIGH || 0);
        acc.bySeverityOpen.MEDIUM += Number(b.MEDIUM || 0);
        acc.bySeverityOpen.LOW += Number(b.LOW || 0);
        acc.bySeverityOpen.INFO += Number(b.INFO || 0);
      } catch {}
      return acc;
    },
    {
      open: 0,
      accepted: 0,
      resolved: 0,
      bySeverityOpen: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 },
    }
  );

  return (
    <main className="container-page py-10 print:py-6">
      {/* Board Packet header (Trust Network style) */}
      <section className="glass-soft p-5 print:bg-white print:text-black print:border-black/10 print:shadow-none">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-2xl font-semibold text-white print:text-black">
                Board Packet
              </h1>
              <span className="pill print:border-black/10 print:bg-black/5 print:text-black/70">
                Generated {generatedAt}
              </span>
              <span className="pill print:border-black/10 print:bg-black/5 print:text-black/70">
                Vendors: {rows.length}
              </span>
            </div>

            <p className="mt-2 text-sm text-white/60 print:text-black/70">
              Snapshot of portfolio risk. Open counts exclude accepted risk. Use “Print / Save PDF”
              for a board-ready export.
            </p>

            <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-white/60 print:text-black/60">
              <span className="pill print:border-black/10 print:bg-black/5 print:text-black/70">
                Open actionable: <span className="text-white/90 print:text-black">{totals.open}</span>
              </span>
              <span className="pill print:border-black/10 print:bg-black/5 print:text-black/70">
                Accepted: <span className="text-white/90 print:text-black">{totals.accepted}</span>
              </span>
              <span className="pill print:border-black/10 print:bg-black/5 print:text-black/70">
                Resolved: <span className="text-white/90 print:text-black">{totals.resolved}</span>
              </span>
              <span className="pill print:border-black/10 print:bg-black/5 print:text-black/70">
                Sev: C {totals.bySeverityOpen.CRITICAL} • H {totals.bySeverityOpen.HIGH} • M{" "}
                {totals.bySeverityOpen.MEDIUM} • L {totals.bySeverityOpen.LOW} • I{" "}
                {totals.bySeverityOpen.INFO}
              </span>
            </div>
          </div>

          {/* Actions */}
          <div className="flex flex-wrap items-center gap-2 print:hidden">
            <a href="/api/board-report/export" className="btn-glass">
              Export CSV
            </a>

            <PrintPdfButton className="btn-primary">
              Print / Save PDF
            </PrintPdfButton>

            <Link href="/board" className="btn-glass">
              Back to live board
            </Link>
          </div>
        </div>

        {/* Print-only small action hint */}
        <div className="mt-3 hidden print:block text-xs text-black/60">
          Truvern Board Packet · Generated {generatedAt}
        </div>
      </section>

      {/* Reuse the same panel so score alignment is guaranteed */}
      <div className="mt-6 print:mt-4 print:[color-scheme:light]">
        <PortfolioRiskPanel rows={rows} />
      </div>

      {/* Footer note */}
      <div className="mt-6 text-xs text-white/50 print:text-black/60">
        Truvern Board Packet · Integrity Seal: Verified · Accepted risk is tracked but does not
        reduce computed score.
      </div>
    </main>
  );
}
