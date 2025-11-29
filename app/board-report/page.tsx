// app/board-report/page.tsx
import { prisma } from "@/lib/prisma";
import Link from "next/link";

export const dynamic = "force-dynamic";

function formatDate(value: Date | string | null) {
  if (!value) return "—";
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString();
}

export default async function BoardReportPage() {
  // Pull vendors with related data
  const vendors = await prisma.vendor.findMany({
    include: {
      assessments: true,
      evidence: true,
    },
    orderBy: { name: "asc" },
  });

  const totalVendors = vendors.length;
  const vendorsWithScore = vendors.filter((v) => v.riskScore != null);
  const totalAssessments = vendors.reduce(
    (sum, v) => sum + v.assessments.length,
    0,
  );
  const totalEvidence = vendors.reduce(
    (sum, v) => sum + v.evidence.length,
    0,
  );

  const highRisk = vendorsWithScore.filter(
    (v) => (v.riskScore ?? 0) > 70,
  ).length;
  const mediumRisk = vendorsWithScore.filter(
    (v) => (v.riskScore ?? 0) > 40 && (v.riskScore ?? 0) <= 70,
  ).length;
  const lowRisk = vendorsWithScore.filter(
    (v) => (v.riskScore ?? 0) <= 40,
  ).length;

  const avgScore =
    vendorsWithScore.length > 0
      ? Math.round(
          vendorsWithScore.reduce(
            (sum, v) => sum + (v.riskScore ?? 0),
            0,
          ) / vendorsWithScore.length,
        )
      : null;

  return (
    <main className="max-w-6xl mx-auto px-4 py-10 space-y-8">
      {/* Header */}
      <section className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">
            Board Report
          </h1>
          <p className="text-sm text-muted-foreground">
            High-level view of third-party risk across your Truvern vendor
            network, using live data from Neon via Prisma.
          </p>
        </div>
      </section>

      {/* KPI strip */}
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-4">
        <div className="border rounded-lg px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-muted-foreground">
            Vendors
          </div>
          <div className="mt-1 text-xl font-semibold">{totalVendors}</div>
          <p className="mt-1 text-xs text-muted-foreground">
            Total third-parties in scope.
          </p>
        </div>

        <div className="border rounded-lg px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-muted-foreground">
            Assessments
          </div>
          <div className="mt-1 text-xl font-semibold">
            {totalAssessments}
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            Recorded vendor assessments.
          </p>
        </div>

        <div className="border rounded-lg px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-muted-foreground">
            Evidence items
          </div>
          <div className="mt-1 text-xl font-semibold">
            {totalEvidence}
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            Linked SOC reports, ISO certs, and other proof.
          </p>
        </div>

        <div className="border rounded-lg px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-muted-foreground">
            Avg. risk score
          </div>
          <div className="mt-1 text-xl font-semibold">
            {avgScore ?? "—"}
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            Based on vendors with a score.
          </p>
        </div>
      </section>

      {/* Risk distribution */}
      <section className="border rounded-lg px-4 py-4 space-y-3">
        <h2 className="text-lg font-medium">Risk distribution</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div>
            <div className="text-xs uppercase tracking-wide text-muted-foreground">
              High risk (&gt; 70)
            </div>
            <div className="mt-1 text-xl font-semibold">{highRisk}</div>
          </div>
          <div>
            <div className="text-xs uppercase tracking-wide text-muted-foreground">
              Medium risk (41–70)
            </div>
            <div className="mt-1 text-xl font-semibold">
              {mediumRisk}
            </div>
          </div>
          <div>
            <div className="text-xs uppercase tracking-wide text-muted-foreground">
              Low risk (≤ 40)
            </div>
            <div className="mt-1 text-xl font-semibold">{lowRisk}</div>
          </div>
        </div>
        <p className="text-xs text-muted-foreground">
          These categories are derived from each vendor&apos;s{" "}
          <span className="font-medium">riskScore</span>. You can refine
          the scoring model later as your TPRM framework matures.
        </p>
      </section>

      {/* Vendor table */}
      <section className="border rounded-lg px-4 py-4 space-y-3">
        <h2 className="text-lg font-medium">Vendors in scope</h2>
        <p className="text-sm text-muted-foreground">
          Snapshot of each vendor with current risk score, number of
          assessments, and evidence items. Click a vendor to open its
          detailed profile.
        </p>

        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="border-b bg-muted/50">
              <tr className="text-left">
                <th className="py-2 pr-4 font-medium">Vendor</th>
                <th className="py-2 pr-4 font-medium">Risk score</th>
                <th className="py-2 pr-4 font-medium">Risk level</th>
                <th className="py-2 pr-4 font-medium">Assessments</th>
                <th className="py-2 pr-4 font-medium">Evidence</th>
                <th className="py-2 pr-4 font-medium">Created</th>
              </tr>
            </thead>
            <tbody>
              {vendors.map((vendor) => {
                const score = vendor.riskScore;
                const level =
                  score == null
                    ? "Pending"
                    : score > 70
                    ? "High"
                    : score > 40
                    ? "Medium"
                    : "Low";

                return (
                  <tr key={vendor.id} className="border-b last:border-0">
                    <td className="py-2 pr-4">
                      <Link
                        href={`/vendors/${vendor.id}`}
                        className="hover:underline font-medium"
                      >
                        {vendor.name}
                      </Link>
                    </td>
                    <td className="py-2 pr-4">
                      {score == null ? "—" : score}
                    </td>
                    <td className="py-2 pr-4">{level}</td>
                    <td className="py-2 pr-4">
                      {vendor.assessments.length}
                    </td>
                    <td className="py-2 pr-4">
                      {vendor.evidence.length}
                    </td>
                    <td className="py-2 pr-4">
                      {formatDate(vendor.createdAt)}
                    </td>
                  </tr>
                );
              })}

              {vendors.length === 0 && (
                <tr>
                  <td
                    colSpan={6}
                    className="py-6 text-center text-muted-foreground"
                  >
                    No vendors found yet. Add vendors from the{" "}
                    <Link
                      href="/vendors"
                      className="underline underline-offset-2"
                    >
                      Vendors
                    </Link>{" "}
                    page to populate this report.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
