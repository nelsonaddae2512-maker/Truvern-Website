// app/trust/[id]/page.tsx
import { notFound } from "next/navigation";
import prisma from "@/lib/prisma";

type CIA = {
  confidentiality: number;
  integrity: number;
  availability: number;
  overallLabel: string;
};

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function computeCIA(riskScore: number | null): CIA {
  if (riskScore == null) {
    return {
      confidentiality: 0,
      integrity: 0,
      availability: 0,
      overallLabel: "Unknown",
    };
  }

  const base = clamp(riskScore, 0, 100);

  const confidentiality = clamp(base, 0, 100);
  const integrity = clamp(Math.round(base * 0.9), 0, 100);
  const availability = clamp(Math.round(base * 0.95), 0, 100);

  let overallLabel = "Moderate";
  if (base >= 80) overallLabel = "Strong";
  else if (base < 50) overallLabel = "Weak";

  return { confidentiality, integrity, availability, overallLabel };
}

function riskPillClasses(label: string) {
  if (label === "Strong")
    return "bg-emerald-500/10 text-emerald-300 border-emerald-500/40";
  if (label === "Moderate")
    return "bg-amber-500/10 text-amber-300 border-amber-500/40";
  if (label === "Weak")
    return "bg-rose-500/10 text-rose-300 border-rose-500/40";
  return "bg-slate-700/40 text-slate-300 border-slate-600/60";
}

function formatDate(value: Date | null) {
  if (!value) return "—";
  return value.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export const dynamic = "force-dynamic";

export default async function TrustProfilePage({
  params,
}: {
  // in your setup, params is a Promise
  params: Promise<{ id: string }>;
}) {
  const resolved = await params;
  const id = Number(resolved.id);
  if (!id || Number.isNaN(id)) {
    return notFound();
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id },
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
      assessments: {
        select: {
          createdAt: true,
          updatedAt: true,
          completedAt: true,
        },
        orderBy: { createdAt: "desc" },
        take: 1,
      },
    },
  });

  if (!vendor) {
    return notFound();
  }

  const lastAssessment = vendor.assessments[0];
  const lastAssessedDate =
    lastAssessment?.completedAt ??
    lastAssessment?.updatedAt ??
    lastAssessment?.createdAt ??
    null;

  const cia = computeCIA(vendor.riskScore ?? null);

  // Similar vendors in same bucket
  const bucket = cia.overallLabel;
  let minScore = 0;
  let maxScore = 100;
  if (bucket === "Strong") {
    minScore = 80;
    maxScore = 100;
  } else if (bucket === "Moderate") {
    minScore = 50;
    maxScore = 79;
  } else if (bucket === "Weak") {
    minScore = 0;
    maxScore = 49;
  }

  const similarVendors = await prisma.vendor.findMany({
    where: {
      id: { not: vendor.id },
      riskScore: {
        gte: minScore,
        lte: maxScore,
      },
    },
    orderBy: { riskScore: "desc" },
    take: 3,
  });

  const createdAtLabel = formatDate(vendor.createdAt);
  const lastAssessedLabel = formatDate(lastAssessedDate);

  const tier = (vendor as any).tier as
    | "CRITICAL"
    | "HIGH"
    | "MEDIUM"
    | "LOW"
    | undefined;
  const tierLabel =
    tier === "CRITICAL"
      ? "Critical"
      : tier === "HIGH"
      ? "High"
      : tier === "MEDIUM"
      ? "Medium"
      : tier === "LOW"
      ? "Low"
      : "Unspecified";

  const summary =
    (vendor as any).summary ??
    `This public Trust Profile is provided by ${vendor.name} and reflects their security posture at a high level. Detailed assessment results and internal evidence remain private to the organization and are only visible inside the Truvern workspace.`;

  return (
    <div className="px-4 py-8 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl space-y-8">
        {/* Header */}
        <section className="rounded-3xl border border-slate-800 bg-slate-950/80 p-6 shadow-lg shadow-slate-950/50">
          <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-emerald-400">
            Truvern Trust Profile
          </p>
          <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h1 className="text-3xl font-semibold text-slate-50 sm:text-4xl">
                {vendor.name}
              </h1>
              <p className="mt-2 text-sm text-slate-400">
                Created {createdAtLabel}
                {typeof vendor.riskScore === "number" && (
                  <>
                    {" · "}
                    Risk score {vendor.riskScore}
                  </>
                )}
                {" · "}
                Tier {tierLabel}
              </p>
            </div>
            <div className="flex items-center gap-2">
              <span
                className={`inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-wide ${riskPillClasses(
                  cia.overallLabel
                )}`}
              >
                Overall: {cia.overallLabel}
              </span>
            </div>
          </div>

          <div className="mt-5 rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
            <h2 className="text-sm font-semibold text-slate-100">Overview</h2>
            <p className="mt-2 text-sm text-slate-300">{summary}</p>
          </div>
        </section>

        {/* Snapshot + CIA */}
        <section className="space-y-4 rounded-3xl border border-slate-800 bg-slate-950/80 p-6 shadow-lg shadow-slate-950/50">
          <h2 className="text-sm font-semibold text-slate-100">
            Security Snapshot
          </h2>

          <div className="grid gap-4 sm:grid-cols-3">
            <div className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
              <p className="text-xs font-medium text-slate-400">
                Assessments completed
              </p>
              <p className="mt-2 text-2xl font-semibold text-slate-50">
                {vendor._count.assessments}
              </p>
              <p className="mt-2 text-xs text-slate-500">
                Includes security questionnaires and internal reviews captured
                in Truvern.
              </p>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
              <p className="text-xs font-medium text-slate-400">
                Evidence items
              </p>
              <p className="mt-2 text-2xl font-semibold text-slate-50">
                {vendor._count.evidence}
              </p>
              <p className="mt-2 text-xs text-slate-500">
                Certifications, reports, policies, and artefacts linked to this
                vendor.
              </p>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
              <p className="text-xs font-medium text-slate-400">
                Last assessed
              </p>
              <p className="mt-2 text-xl font-semibold text-slate-50">
                {lastAssessedLabel}
              </p>
              <p className="mt-2 text-xs text-slate-500">
                Date of the most recent assessment recorded in Truvern.
              </p>
            </div>
          </div>

          <div className="mt-4 flex items-center justify-between gap-3">
            <div>
              <p className="text-xs font-semibold text-slate-300">
                CIA rollup (Confidentiality, Integrity, Availability)
              </p>
              <p className="mt-1 text-xs text-slate-500">
                Current assessments and evidence indicate the relative strength
                of confidentiality, integrity, and availability controls.
              </p>
            </div>
            <span
              className={`inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-wide ${riskPillClasses(
                cia.overallLabel
              )}`}
            >
              Overall: {cia.overallLabel}
            </span>
          </div>

          <div className="mt-3 space-y-3">
            <CIAProgressRow
              label="Confidentiality"
              value={cia.confidentiality}
            />
            <CIAProgressRow label="Integrity" value={cia.integrity} />
            <CIAProgressRow
              label="Availability"
              value={cia.availability}
            />
          </div>
        </section>

        {/* Similar vendors */}
        {similarVendors.length > 0 && (
          <section className="rounded-3xl border border-slate-800 bg-slate-950/80 p-6 shadow-lg shadow-slate-950/50">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-sm font-semibold text-slate-100">
                  Similar vendors
                </h2>
                <p className="mt-1 text-xs text-slate-500">
                  Vendors with a comparable overall risk profile. Use this to
                  benchmark {vendor.name} against peers.
                </p>
              </div>
            </div>

            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              {similarVendors.map((v) => {
                const riskScore = v.riskScore ?? null;
                const peerCIA = computeCIA(riskScore);

                return (
                  <div
                    key={v.id}
                    className="flex flex-col rounded-2xl border border-slate-800 bg-slate-950/80 p-3 text-xs"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <p className="line-clamp-2 font-semibold text-slate-50">
                        {v.name}
                      </p>
                      <span
                        className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${riskPillClasses(
                          peerCIA.overallLabel
                        )}`}
                      >
                        {peerCIA.overallLabel}
                      </span>
                    </div>
                    <p className="mt-1 text-[11px] text-slate-400">
                      Risk score:{" "}
                      {typeof v.riskScore === "number"
                        ? `${v.riskScore} / 100`
                        : "Unknown"}
                    </p>
                    <p className="mt-1 text-[11px] text-slate-500">
                      Joined: {formatDate(v.createdAt)}
                    </p>
                    <a
                      href={`/trust/${v.id}`}
                      className="mt-2 inline-flex items-center justify-center rounded-full border border-slate-700/80 bg-slate-900/80 px-3 py-1 text-[11px] font-medium text-slate-50 hover:border-emerald-500/60 hover:text-emerald-200"
                    >
                      View profile
                    </a>
                  </div>
                );
              })}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}

function CIAProgressRow({ label, value }: { label: string; value: number }) {
  return (
    <div className="space-y-1">
      <div className="flex items-center justify-between text-xs">
        <span className="font-medium text-slate-200">{label}</span>
        <span className="text-slate-400">{value}%</span>
      </div>
      <div className="h-2 rounded-full bg-slate-800">
        <div
          className="h-2 rounded-full bg-emerald-500"
          style={{ width: `${clamp(value, 0, 100)}%` }}
        />
      </div>
    </div>
  );
}
