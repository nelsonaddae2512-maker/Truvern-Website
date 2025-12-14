// app/assessment/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

function fmt(d: Date | string | null | undefined) {
  if (!d) return "—";
  const date = typeof d === "string" ? new Date(d) : d;
  return date.toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function statusTone(status: string | null | undefined) {
  const s = (status ?? "").toUpperCase();
  if (s === "COMPLETED")
    return "bg-emerald-500/10 text-emerald-200 border-emerald-500/30";
  if (s === "SUBMITTED")
    return "bg-sky-500/10 text-sky-200 border-sky-500/30";
  if (s === "IN_PROGRESS")
    return "bg-amber-500/10 text-amber-200 border-amber-500/30";
  if (s === "ARCHIVED")
    return "bg-slate-500/10 text-slate-200 border-slate-500/30";
  return "bg-slate-800 text-slate-200 border-slate-700";
}

function bandTone(score: number | null | undefined) {
  if (score == null) return "bg-slate-800 text-slate-200 border-slate-700";
  if (score >= 85)
    return "bg-emerald-500/10 text-emerald-200 border-emerald-500/30";
  if (score >= 70) return "bg-cyan-500/10 text-cyan-200 border-cyan-500/30";
  if (score >= 50)
    return "bg-amber-500/10 text-amber-200 border-amber-500/30";
  return "bg-rose-500/10 text-rose-200 border-rose-500/30";
}

export default async function AssessmentHomePage() {
  const { userId } = auth();
  const user = userId ? await currentUser() : null;

  if (!userId) {
    return (
      <main className="mx-auto max-w-6xl px-4 py-10">
        <div className="rounded-3xl border border-white/10 bg-slate-950/40 p-6">
          <div className="text-xs tracking-[0.25em] text-emerald-200/80">
            ASSESSMENTS
          </div>
          <h1 className="mt-2 text-3xl font-semibold text-slate-50">
            Assessment Runs
          </h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Please sign in to view assessment runs.
          </p>
          <div className="mt-6">
            <Link
              href="/"
              className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
            >
              Back home
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // ✅ Role detection (enterprise split)
  // Vendor user = has publicMetadata.vendorId
  const vendorIdRaw = (user?.publicMetadata as any)?.vendorId;
  const vendorId =
    typeof vendorIdRaw === "number"
      ? vendorIdRaw
      : typeof vendorIdRaw === "string"
      ? Number(vendorIdRaw)
      : undefined;

  const isVendorUser = Number.isFinite(vendorId as any);

  const where = isVendorUser ? { vendorId: vendorId as number } : {};

  const runs = await prisma.assessment.findMany({
    where,
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    take: 200,
    include: {
      vendor: { select: { id: true, name: true, riskScore: true } },
      template: { select: { id: true, name: true } }, // ✅ no `title`
    },
  });

  const heading = isVendorUser ? "Your Assessment Runs" : "Assessment Runs";
  const subcopy = isVendorUser
    ? "Runs assigned to your vendor account."
    : "Portfolio-wide assessment sessions across vendors.";

  const primaryCtaHref = isVendorUser ? "/vendor-portal" : "/assessment/templates";
  const primaryCtaLabel = isVendorUser ? "Go to Vendor Portal" : "Template Manager";

  return (
    <main className="mx-auto max-w-6xl px-4 py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-xs tracking-[0.25em] text-emerald-200/80">
            {isVendorUser ? "VENDOR PORTAL" : "ASSESSMENTS"}
          </div>
          <h1 className="mt-2 text-3xl font-semibold text-slate-50">
            {heading}
          </h1>
          <p className="mt-2 max-w-2xl text-sm text-slate-200/70">{subcopy}</p>
        </div>

        <div className="flex items-center gap-2">
          <Link
            href={primaryCtaHref}
            className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
          >
            {primaryCtaLabel}
          </Link>

          {!isVendorUser && (
            <Link
              href="/vendors"
              className="hidden rounded-full border border-emerald-500/25 bg-emerald-500/10 px-4 py-2 text-sm font-medium text-emerald-100 hover:bg-emerald-500/15 md:inline-flex"
            >
              Vendor Portfolio
            </Link>
          )}
        </div>
      </div>

      <div className="mt-8 overflow-hidden rounded-2xl border border-white/10 bg-slate-950/40">
        <div className="grid grid-cols-12 gap-2 border-b border-white/10 px-5 py-3 text-xs text-slate-200/60">
          <div className="col-span-5">Run</div>
          <div className="col-span-3">Vendor</div>
          <div className="col-span-2">Status</div>
          <div className="col-span-2 text-right">Updated</div>
        </div>

        {runs.length === 0 ? (
          <div className="px-5 py-10 text-sm text-slate-200/70">
            No assessment runs yet.
          </div>
        ) : (
          <div className="divide-y divide-white/5">
            {runs.map((r) => {
              const templateName =
                r.template?.name ?? (r.templateId ? `Template #${r.templateId}` : "—");
              const title = r.title ?? templateName ?? `Run #${r.id}`;

              return (
                <Link
                  key={r.id}
                  href={`/assessment/runs/${r.id}${isVendorUser ? "" : ""}`}
                  className="block px-5 py-4 hover:bg-white/5"
                >
                  <div className="grid grid-cols-12 items-center gap-2">
                    <div className="col-span-5">
                      <div className="text-sm font-medium text-slate-50">
                        {title}
                      </div>
                      <div className="mt-1 text-xs text-slate-200/60">
                        Template: {templateName} • Run #{r.id}
                      </div>
                    </div>

                    <div className="col-span-3 text-sm text-slate-200/80">
                      {r.vendor?.name ?? (r.vendorId ? `Vendor #${r.vendorId}` : "—")}
                      {r.vendor?.riskScore != null && (
                        <span
                          className={`ml-2 inline-flex items-center rounded-full border px-2 py-0.5 text-[10px] ${bandTone(
                            r.vendor.riskScore
                          )}`}
                          title="Vendor health / risk"
                        >
                          {r.vendor.riskScore}
                        </span>
                      )}
                    </div>

                    <div className="col-span-2">
                      <span
                        className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs ${statusTone(
                          r.status as any
                        )}`}
                      >
                        {r.status ?? "—"}
                      </span>
                    </div>

                    <div className="col-span-2 text-right text-xs text-slate-200/60">
                      {fmt(r.updatedAt as any)}
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </div>

      {/* Vendor-safe note */}
      {isVendorUser && (
        <div className="mt-6 rounded-2xl border border-emerald-500/20 bg-emerald-500/5 px-4 py-3 text-sm text-emerald-100">
          Only runs assigned to your vendor account are shown here.
        </div>
      )}
    </main>
  );
}
