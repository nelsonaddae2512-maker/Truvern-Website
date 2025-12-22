import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import VendorRiskPanel from "@/components/vendors/vendor-risk-panel";
import VendorActionability328A from "@/components/vendors/vendor-actionability-328a";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function parseVendorId(raw: unknown): number {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const m = s.match(/\d+/);
  return m ? Number(m[0]) : NaN;
}

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

function sevRank(sev: string) {
  const s = (sev || "").toUpperCase();
  if (s === "CRITICAL") return 4;
  if (s === "HIGH") return 3;
  if (s === "MEDIUM") return 2;
  if (s === "LOW") return 1;
  return 2;
}

type IssueLite = {
  id: number;
  title?: string | null;
  status: string;
  severity: string;
  createdAt?: string | Date | null;
};

async function safeFindVendor(orgId: number, vendorId: number) {
  // Try rich select first (counts + optional metadata)
  try {
    const v = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: orgId } as any,
      select: {
        id: true,
        name: true,
        updatedAt: true,
        tier: true as any,
        criticality: true as any,
        category: true as any,
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
    return v as any;
  } catch {
    // Fallback: minimal fields only
    const v = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: orgId } as any,
      select: { id: true, name: true, updatedAt: true } as any,
    });
    return v as any;
  }
}

async function safeFindIssues(vendorId: number): Promise<IssueLite[]> {
  try {
    const rows = await prisma.issue.findMany({
      where: { vendorId } as any,
      select: { id: true, title: true, status: true, severity: true, createdAt: true } as any,
      take: 5000,
    });
    return rows as any;
  } catch {
    try {
      const rows = await prisma.issue.findMany({
        where: { vendorId } as any,
        select: { id: true, status: true, severity: true } as any,
        take: 5000,
      });
      return rows as any;
    } catch {
      return [];
    }
  }
}

export default async function VendorDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const org = await requireDbOrganization();

  if ((org as any)?._needsOrgSelection) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
          <h1 className="text-2xl font-semibold text-white">Select an organization</h1>
          <p className="mt-2 text-white/70">
            You&apos;re signed in, but no organization is selected yet. Choose an organization to continue.
          </p>
          <div className="mt-4 flex gap-3 text-sm">
            <Link className="rounded-lg bg-white/10 px-3 py-2 text-white hover:bg-white/15" href="/select-org">
              Select organization
            </Link>
            <Link className="rounded-lg bg-white/10 px-3 py-2 text-white hover:bg-white/15" href="/vendors">
              Back to vendors
            </Link>
          </div>
        </div>
      </main>
    );
  }

  const dbOrgId = (org as any).id as number;
  const { id } = await params;
  const vendorId = parseVendorId(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Invalid vendor id</h1>
        <div className="mt-4">
          <Link className="text-sky-300 hover:underline" href="/vendors">
            Back to vendors
          </Link>
        </div>
      </main>
    );
  }

  const vendor = await safeFindVendor(dbOrgId, vendorId);

  if (!vendor) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Vendor not found</h1>
        <p className="mt-2 text-white/60">This vendor either doesn&apos;t exist or isn&apos;t in your organization.</p>
        <div className="mt-4">
          <Link className="text-sky-300 hover:underline" href="/vendors">
            Back to vendors
          </Link>
        </div>
      </main>
    );
  }

  const issues = await safeFindIssues(vendorId);

  const breakdown = { critical: 0, high: 0, medium: 0, low: 0 };
  let totalPts = 0;
  let recentPts = 0;

  const RECENT_DAYS = 14;
  const recentCutoff = new Date(Date.now() - RECENT_DAYS * 24 * 60 * 60 * 1000);

  const openIssues = issues.filter((it) => isOpenIssueStatus(it.status));

  for (const it of openIssues) {
    const pts = severityPoints(it.severity);
    totalPts += pts;

    const key = sevKey(it.severity);
    (breakdown as any)[key] = ((breakdown as any)[key] || 0) + 1;

    try {
      const d = it.createdAt ? new Date(it.createdAt as any) : null;
      if (d && d >= recentCutoff) recentPts += pts;
    } catch {}
  }

  const score = Math.max(0, Math.min(100, totalPts * 5));
  const olderPts = Math.max(0, totalPts - recentPts);
  const trend: "up" | "down" | "flat" =
    totalPts === 0 ? "flat" : recentPts > olderPts ? "up" : recentPts < olderPts ? "down" : "flat";

  const topOpenIssues = openIssues
    .slice()
    .sort((a, b) => {
      const rs = sevRank(b.severity) - sevRank(a.severity);
      if (rs !== 0) return rs;
      return (b.id || 0) - (a.id || 0);
    })
    .slice(0, 6)
    .map((it) => ({
      id: it.id,
      title: (it as any).title ?? `Issue #${it.id}`,
      severity: it.severity,
      status: it.status,
    }));

  const counts = {
    assessments: vendor?._count?.assessments ?? 0,
    openIssues: openIssues.length,
    evidence: vendor?._count?.evidence ?? 0,
    evidenceRequests: vendor?._count?.evidenceRequests ?? 0,
  };

  // ---- Phase 328A additions (safe, non-breaking) ----

  // Derive critical open count from already-fetched issues (no extra DB call)
  const criticalOpenCount = openIssues.filter((it) => (it.severity || "").toUpperCase() === "CRITICAL").length;

  // Accepted critical issues count (safe query with fallback)
  let acceptedCriticalCount = 0;
  try {
    acceptedCriticalCount = await prisma.issue.count({
      where: { vendorId, severity: "CRITICAL", status: "ACCEPTED_RISK" } as any,
    });
  } catch {
    acceptedCriticalCount = 0;
  }

  // Outstanding evidence requests (safe if model/table doesn’t exist)
  let openRequests: any[] = [];
  try {
    openRequests = await (prisma as any).evidenceRequest.findMany({
      where: { vendorId, status: { in: ["REQUESTED", "PENDING"] } } as any,
      orderBy: { createdAt: "desc" } as any,
      take: 5,
    });
  } catch {
    openRequests = [];
  }

  return (
    <main className="container-page py-10">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link className="text-sm text-sky-300 hover:underline" href="/vendors">
            ← Back
          </Link>
          <div className="text-sm text-white/40">/</div>
          <div className="text-sm text-white/70">Vendor</div>
        </div>

        <Link
          className={clsx("rounded-lg bg-white/10 px-3 py-2 text-sm text-white hover:bg-white/15")}
          href={`/vendors/${vendorId}`}
        >
          Refresh
        </Link>
      </div>

      <VendorRiskPanel
        vendorName={vendor.name}
        score={score}
        trend={trend}
        breakdown={breakdown}
        counts={counts}
        topOpenIssues={topOpenIssues}
      />

      {/* Phase 328A Actionability Layer */}
      <section className="mt-6">
        <VendorActionability328A
          vendorId={vendorId}
          vendor={vendor as any}
          acceptedCriticalCount={acceptedCriticalCount}
          openRequests={openRequests}
          criticalOpenCount={criticalOpenCount}
        />
      </section>

      {/* Vendor record (collapsible) */}
      <details className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-5">
        <summary className="cursor-pointer select-none text-sm font-semibold text-white">
          Vendor record <span className="ml-2 text-xs font-normal text-white/50">metadata</span>
        </summary>

        <div className="mt-3 grid grid-cols-1 gap-3 text-sm md:grid-cols-3">
          <div className="rounded-xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs text-white/50">Vendor ID</div>
            <div className="mt-1 text-white tabular-nums">{vendor.id}</div>
          </div>
          <div className="rounded-xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs text-white/50">Last updated</div>
            <div className="mt-1 text-white tabular-nums">{new Date(vendor.updatedAt as any).toLocaleString()}</div>
          </div>
          <div className="rounded-xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs text-white/50">Organization</div>
            <div className="mt-1 text-white">{(org as any).name ?? "Current org"}</div>
          </div>
        </div>
      </details>
    </main>
  );
}
