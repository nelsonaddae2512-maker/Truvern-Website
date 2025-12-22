import Link from "next/link";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { requireDbOrganization } from "@/lib/org-db";
import RiskPopover from "@/components/risk/risk-popover";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

type VendorRow = {
  id: number;
  name: string;
  updatedAt: Date | string;
  _count?: {
    assessments?: number;
    issues?: number;
    evidence?: number;
    evidenceRequests?: number;
  };
};

type IssueLite = {
  vendorId: number | null;
  status: string;
  severity: string;
  createdAt?: string | Date | null;
};

function isOpenIssueStatus(status: string) {
  const s = (status || "").toUpperCase();
  return !["RESOLVED", "CLOSED", "DONE"].includes(s);
}

function severityPoints(sev: string) {
  switch ((sev || "").toUpperCase()) {
    case "CRITICAL":
      return 10;
    case "HIGH":
      return 7;
    case "MEDIUM":
      return 4;
    case "LOW":
      return 1;
    default:
      return 2;
  }
}

function sevKey(sev: string) {
  const s = (sev || "").toUpperCase();
  if (s === "CRITICAL") return "critical";
  if (s === "HIGH") return "high";
  if (s === "MEDIUM") return "medium";
  if (s === "LOW") return "low";
  return "medium";
}

function scoreToLevel(score: number) {
  if (score >= 75) return { label: "Critical", tone: "red" as const };
  if (score >= 50) return { label: "High", tone: "orange" as const };
  if (score >= 25) return { label: "Moderate", tone: "amber" as const };
  return { label: "Low", tone: "green" as const };
}

function RiskBadge({ score }: { score: number }) {
  const lvl = scoreToLevel(score);
  const tone =
    lvl.tone === "red"
      ? "border-red-400/30 bg-red-500/15 text-red-200"
      : lvl.tone === "orange"
      ? "border-orange-400/30 bg-orange-500/15 text-orange-200"
      : lvl.tone === "amber"
      ? "border-amber-400/30 bg-amber-500/15 text-amber-200"
      : "border-emerald-400/30 bg-emerald-500/15 text-emerald-200";

  return (
    <span
      className={clsx("inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-medium", tone)}
      title={`Risk score ${score}/100`}
    >
      <span className="h-2 w-2 rounded-full bg-current opacity-80" />
      {lvl.label}
      <span className="text-white/40">·</span>
      <span className="tabular-nums">{score}</span>
    </span>
  );
}

function TrendArrow({ trend }: { trend: "up" | "down" | "flat" }) {
  const t = trend === "up" ? "text-red-200" : trend === "down" ? "text-emerald-200" : "text-white/60";
  const ch = trend === "up" ? "↑" : trend === "down" ? "↓" : "→";
  const label = trend === "up" ? "Rising risk" : trend === "down" ? "Improving risk" : "Stable risk";
  return (
    <span className={clsx("text-xs font-semibold", t)} title={label}>
      {ch}
    </span>
  );
}

function SevChips({
  b,
}: {
  b: { critical: number; high: number; medium: number; low: number };
}) {
  const items = [
    ["C", b.critical, "border-red-400/20 bg-red-500/10 text-red-200"] as const,
    ["H", b.high, "border-orange-400/20 bg-orange-500/10 text-orange-200"] as const,
    ["M", b.medium, "border-amber-400/20 bg-amber-500/10 text-amber-200"] as const,
    ["L", b.low, "border-emerald-400/20 bg-emerald-500/10 text-emerald-200"] as const,
  ];
  return (
    <div className="min-h-[22px] flex flex-wrap items-center gap-1.5">
      {items.map(([k, v, cls]) =>
        v ? (
          <span
            key={k}
            className={clsx(
              "inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium tabular-nums",
              cls
            )}
            title={`${k}: ${v}`}
          >
            {k} <span className="text-white/30">·</span> {v}
          </span>
        ) : null
      )}
    </div>
  );
}

async function fetchVendorsSafe(orgId: number): Promise<VendorRow[]> {
  try {
    const rows = await prisma.vendor.findMany({
      where: { organizationId: orgId } as any,
      orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      take: 300,
      select: {
        id: true,
        name: true,
        updatedAt: true,
        _count: {
          select: {
            assessments: true,
            issues: true,
            evidence: true,
            evidenceRequests: true,
          },
        },
      } as any,
    });
    return rows as any;
  } catch {
    const rows = await prisma.vendor.findMany({
      where: { organizationId: orgId } as any,
      orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      take: 300,
      select: { id: true, name: true, updatedAt: true } as any,
    });
    return rows as any;
  }
}

function GateCard({
  title,
  body,
  primaryHref,
  primaryLabel,
  secondaryHref,
  secondaryLabel,
}: {
  title: string;
  body: string;
  primaryHref: string;
  primaryLabel: string;
  secondaryHref?: string;
  secondaryLabel?: string;
}) {
  return (
    <main className="container-page py-10">
      <div className="glass-soft p-6">
        <h1 className="text-2xl font-semibold text-white">{title}</h1>
        <p className="mt-2 text-white/70">{body}</p>
        <div className="mt-4 flex flex-wrap gap-3 text-sm">
          <Link className="btn-primary" href={primaryHref}>
            {primaryLabel}
          </Link>
          {secondaryHref && secondaryLabel && (
            <Link className="btn-glass" href={secondaryHref}>
              {secondaryLabel}
            </Link>
          )}
        </div>
      </div>
    </main>
  );
}

async function fetchIssuesSafe(vendorIds: number[]): Promise<IssueLite[]> {
  // Try with createdAt first (for trend). If schema differs, fallback without it.
  try {
    const rows = await prisma.issue.findMany({
      where: { vendorId: { in: vendorIds } } as any,
      select: { vendorId: true, status: true, severity: true, createdAt: true } as any,
      take: 5000,
    });
    return rows as any;
  } catch {
    try {
      const rows = await prisma.issue.findMany({
        where: { vendorId: { in: vendorIds } } as any,
        select: { vendorId: true, status: true, severity: true } as any,
        take: 5000,
      });
      return rows as any;
    } catch {
      return [];
    }
  }
}

export default async function VendorsPage() {
  const { userId } = await auth();

  if (!userId) {
    return (
      <GateCard
        title="Vendors"
        body="Please sign in to view vendors."
        primaryHref="/sign-in"
        primaryLabel="Sign in"
        secondaryHref="/"
        secondaryLabel="Home"
      />
    );
  }

  const org = await requireDbOrganization();

  if ((org as any)?._needsOrgSelection) {
    return (
      <GateCard
        title="Select an organization"
        body="You're signed in, but no organization is selected yet. Choose an organization (or create one) to continue."
        primaryHref="/select-org"
        primaryLabel="Select organization"
        secondaryHref="/vendors"
        secondaryLabel="Retry vendors"
      />
    );
  }

  const dbOrgId = (org as any).id as number;

  const vendors = await fetchVendorsSafe(dbOrgId);
  const vendorIds = vendors.map((v) => v.id);

  const issues = await fetchIssuesSafe(vendorIds);

  const riskPtsByVendorId = new Map<number, number>();
  const openByVendorId = new Map<number, number>();
  const breakdownByVendorId = new Map<number, { critical: number; high: number; medium: number; low: number }>();
  const recentPtsByVendorId = new Map<number, number>();

  const RECENT_DAYS = 14;
  const recentCutoff = new Date(Date.now() - RECENT_DAYS * 24 * 60 * 60 * 1000);

  for (const it of issues) {
    const vid = it.vendorId;
    if (!vid) continue;
    if (!isOpenIssueStatus(it.status)) continue;

    openByVendorId.set(vid, (openByVendorId.get(vid) || 0) + 1);

    const pts = severityPoints(it.severity);
    riskPtsByVendorId.set(vid, (riskPtsByVendorId.get(vid) || 0) + pts);

    const key = sevKey(it.severity);
    const b = breakdownByVendorId.get(vid) || { critical: 0, high: 0, medium: 0, low: 0 };
    (b as any)[key] = ((b as any)[key] || 0) + 1;
    breakdownByVendorId.set(vid, b);

    // recent bucket for trend (best-effort)
    try {
      const d = it.createdAt ? new Date(it.createdAt as any) : null;
      if (d && d >= recentCutoff) {
        recentPtsByVendorId.set(vid, (recentPtsByVendorId.get(vid) || 0) + pts);
      }
    } catch {}
  }

  const riskScore = (vendorId: number) => {
    const pts = riskPtsByVendorId.get(vendorId) || 0;
    return Math.max(0, Math.min(100, pts * 5));
  };

  const openIssuesCount = (vendorId: number) => openByVendorId.get(vendorId) || 0;

  const breakdownForVendor = (vendorId: number) =>
    breakdownByVendorId.get(vendorId) || { critical: 0, high: 0, medium: 0, low: 0 };

  const trendForVendor = (vendorId: number): "up" | "down" | "flat" => {
    const totalPts = riskPtsByVendorId.get(vendorId) || 0;
    const recentPts = recentPtsByVendorId.get(vendorId) || 0;
    const olderPts = Math.max(0, totalPts - recentPts);

    if (totalPts === 0) return "flat";
    if (recentPts > olderPts) return "up";
    if (recentPts < olderPts) return "down";
    return "flat";
  };

  return (
    <main className="container-page py-10">
      {/* Trust Network-style portfolio header */}
      <section className="glass-soft p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-semibold text-white">Vendors</h1>
              <span className="pill">{vendors.length} total</span>
            </div>
            <p className="mt-1 text-sm text-white/60">
              Your third-party portfolio and risk posture.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Link href="/vendors/new" className="btn-primary">
              + New vendor
            </Link>
            <Link href="/board" className="btn-glass">
              Board view
            </Link>
          </div>
        </div>

        {/* (UI only) search control for future client filtering */}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <input className="input-glass max-w-md" placeholder="Search vendors (coming next)..." />
          <span className="pill">Sort: Recently updated</span>
        </div>
      </section>

      {/* List */}
      <div className="mt-4 glass overflow-hidden">
        <div className="hidden md:grid grid-cols-[2fr,1.4fr,1fr,1fr,1fr,auto] gap-3 px-5 py-3 text-xs text-white/50 border-b border-white/10">
          <div>Vendor</div>
          <div>Risk</div>
          <div className="text-right">Assessments</div>
          <div className="text-right">Open issues</div>
          <div className="text-right">Evidence</div>
          <div />
        </div>

        <div className="divide-y divide-white/10">
          {vendors.map((v) => {
            const assessments = v._count?.assessments ?? 0;
            const evidence = v._count?.evidence ?? 0;
            const openIssues = openIssuesCount(v.id);

            const score = riskScore(v.id);
            const trend = trendForVendor(v.id);
            const b = breakdownForVendor(v.id);
            const lvl = scoreToLevel(score);

            return (
              <Link key={v.id} href={`/vendors/${v.id}`} className="block hover:bg-white/5">
                <div className="grid grid-cols-1 md:grid-cols-[2fr,1.4fr,1fr,1fr,1fr,auto] gap-3 px-5 py-4 items-center">
                  <div className="min-w-0">
                    <div className="truncate text-white font-medium">{v.name}</div>
                    <div className="mt-1 text-xs text-white/50">
                      Updated {new Date(v.updatedAt as any).toLocaleString()}
                    </div>
                  </div>

                  <div className="flex flex-col items-start gap-2">
                    <div className="flex items-center gap-2">
                      <RiskBadge score={score} />
                      <TrendArrow trend={trend} />
                      <RiskPopover score={score} label={lvl.label} breakdown={b} trend={trend} />
                    </div>
                    <SevChips b={b} />
                  </div>

                  <div className="text-white/70 text-sm md:text-right tabular-nums">{assessments}</div>
                  <div className="text-white/70 text-sm md:text-right tabular-nums">{openIssues}</div>
                  <div className="text-white/70 text-sm md:text-right tabular-nums">{evidence}</div>

                  <div className="text-white/50 text-sm justify-self-end">View →</div>
                </div>
              </Link>
            );
          })}

          {vendors.length === 0 && (
            <div className="px-5 py-10 text-white/60 text-sm">No vendors yet. Create your first vendor.</div>
          )}
        </div>
      </div>
    </main>
  );
}
