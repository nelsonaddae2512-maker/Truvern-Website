// app/vendors/[id]/findings/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import VendorFindingsPanel from "@/components/vendor-findings-panel";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type SearchParamsPromise = Promise<Record<string, string | string[] | undefined>>;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function riskTone(score: number | null | undefined): string {
  if (score == null) return "bg-slate-800 text-slate-200 border-slate-700";
  if (score >= 85) return "bg-emerald-500/10 text-emerald-200 border-emerald-500/30";
  if (score >= 70) return "bg-sky-500/10 text-sky-200 border-sky-500/30";
  if (score >= 50) return "bg-amber-500/10 text-amber-200 border-amber-500/30";
  return "bg-rose-500/10 text-rose-200 border-rose-500/30";
}

function riskLabel(score: number | null | undefined): string {
  if (score == null) return "Not scored";
  if (score >= 85) return `Low risk (${score})`;
  if (score >= 70) return `Moderate (${score})`;
  if (score >= 50) return `Elevated (${score})`;
  return `High risk (${score})`;
}

function firstStr(v: string | string[] | undefined) {
  return Array.isArray(v) ? v[0] : v;
}

export default async function VendorFindingsPage({
  params,
  searchParams,
}: {
  params: ParamsPromise;
  searchParams?: SearchParamsPromise;
}) {
  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold tracking-tight text-slate-50">Invalid vendor id</h1>
        <p className="mt-2 text-sm text-slate-200/70">Return to your vendor list.</p>
        <Link href="/vendors" className="mt-6 inline-block text-emerald-300 hover:underline">
          ← Back to vendors
        </Link>
      </main>
    );
  }

  const sp = (await searchParams) ?? {};
  const exportFlag = firstStr(sp.export) === "1";

  // convenience: allow /vendors/[id]/findings?export=1 to download
  if (exportFlag) {
    // redirect to API download
    return (
      <main className="container-page py-12">
        <p className="text-sm text-slate-200/70">
          Exporting… If your download doesn’t start,{" "}
          <a
            className="text-emerald-300 underline"
            href={`/api/vendors/${vendorId}/issues/export.csv`}
          >
            click here
          </a>
          .
        </p>
      </main>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: {
      id: true,
      name: true,
      slug: true,
      riskScore: true,
      issues: { select: { status: true } },
    },
  });

  if (!vendor) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold tracking-tight text-slate-50">Vendor not found</h1>
        <p className="mt-2 text-sm text-slate-200/70">Return to your vendor list.</p>
        <Link href="/vendors" className="mt-6 inline-block text-emerald-300 hover:underline">
          ← Back to vendors
        </Link>
      </main>
    );
  }

  const statuses = vendor.issues.map((x) => String(x.status));
  const openCount = statuses.filter((s) => s === "OPEN" || s === "IN_REVIEW").length;
  const acceptedCount = statuses.filter((s) => s === "ACCEPTED_RISK").length;
  const resolvedCount = statuses.filter((s) => s === "RESOLVED").length;

  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <div className="flex flex-wrap items-center gap-2 text-xs text-slate-400">
          <Link href="/vendors" className="hover:text-slate-200">
            Vendors
          </Link>
          <span className="text-slate-500">/</span>
          <Link href={`/vendors/${vendor.id}`} className="hover:text-slate-200">
            {vendor.name}
          </Link>
          <span className="text-slate-500">/</span>
          <span className="text-slate-200">Findings</span>
        </div>

        <div className="mt-3 flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
          <div className="min-w-0">
            <h1 className="text-2xl md:text-3xl font-semibold tracking-tight text-slate-50">
              Findings — {vendor.name}
            </h1>
            <p className="mt-2 text-sm text-slate-200/70 max-w-2xl">
              Active findings exclude Accepted Risk and Resolved items. Use the tabs to review what’s
              blocking remediation vs. what’s tracked for audit visibility.
            </p>

            <div className="mt-3 flex flex-wrap gap-2 text-xs">
              <span
                className={clsx(
                  "inline-flex items-center rounded-full border px-3 py-1 font-semibold",
                  riskTone(vendor.riskScore)
                )}
                title="Vendor health / risk"
              >
                {riskLabel(vendor.riskScore)}
              </span>

              <span className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-slate-200/80">
                Open: <span className="ml-1 font-semibold text-slate-50">{openCount}</span>
              </span>

              <span className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-slate-200/80">
                Accepted: <span className="ml-1 font-semibold text-slate-50">{acceptedCount}</span>
              </span>

              <span className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-slate-200/80">
                Resolved: <span className="ml-1 font-semibold text-slate-50">{resolvedCount}</span>
              </span>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/vendors/${vendor.id}?tab=findings#findings`}
              className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              ← Back to Vendor
            </Link>

            <Link
              href="/issues"
              className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Global Issues ↗
            </Link>

            <a
              href={`/api/vendors/${vendor.id}/issues/export.csv`}
              className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Export CSV ↗
            </a>
          </div>
        </div>
      </div>

      <section className="rounded-3xl border border-white/10 bg-white/5 p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="text-sm font-semibold text-slate-50">Vendor inbox</div>
            <div className="mt-1 text-xs text-slate-200/60">
              Tip: use <span className="font-semibold text-slate-200">Show resolved</span> when you
              want to confirm closure history.
            </div>
          </div>

          <Link
            href={`/vendors/${vendor.id}?tab=findings#findings`}
            className="text-xs text-slate-200/60 hover:text-slate-100"
            title="Jump back to vendor overview"
          >
            Vendor overview ↗
          </Link>
        </div>

        <div className="mt-4">
          <VendorFindingsPanel vendorId={vendor.id} />
        </div>
      </section>
    </main>
  );
}
