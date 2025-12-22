import Link from "next/link";

type EvidenceRequestRow = {
  id: number | string;
  title?: string | null;
  name?: string | null;
  status?: string | null;
  createdAt?: Date | string | null;
};

type Props = {
  vendorId: number;
  vendor: {
    tier?: string | null;
    criticality?: string | null;
    category?: string | null;
  };
  acceptedCriticalCount: number;
  openRequests: EvidenceRequestRow[];
  criticalOpenCount: number;
};

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fmtDate(v: any) {
  try {
    const d = v instanceof Date ? v : new Date(v);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString();
  } catch {
    return "";
  }
}

function Pill({ children }: { children: React.ReactNode }) {
  return <span className="pill">{children}</span>;
}

function toneFromCriticality(crit?: string | null) {
  const s = String(crit || "").toUpperCase();
  if (s.includes("CRIT")) return "border-rose-400/25 bg-rose-500/10 text-rose-200";
  if (s.includes("HIGH")) return "border-amber-400/25 bg-amber-500/10 text-amber-200";
  if (s.includes("MED")) return "border-sky-400/25 bg-sky-500/10 text-sky-200";
  if (s.includes("LOW")) return "border-emerald-400/25 bg-emerald-500/10 text-emerald-200";
  return "border-white/10 bg-white/5 text-white/80";
}

function ActionHint({ children }: { children: React.ReactNode }) {
  return <span className="hidden md:inline text-xs text-white/40">{children}</span>;
}

export default function VendorActionability328A({
  vendorId,
  vendor,
  acceptedCriticalCount,
  openRequests,
  criticalOpenCount,
}: Props) {
  // Next Best Action (simple, deterministic)
  let nextAction: { label: string; href: string; tone?: "primary" | "neutral" } | null = null;

  if (openRequests?.length > 0) {
    nextAction = {
      label: "Follow up on evidence",
      href: `/evidence/requests?vendor=${vendorId}`,
      tone: "primary",
    };
  } else if (criticalOpenCount > 0) {
    nextAction = {
      label: "Review critical issues",
      href: `/issues?vendor=${vendorId}&severity=CRITICAL`,
      tone: "primary",
    };
  } else {
    nextAction = { label: "Re-run assessment", href: `/assessments/new?vendor=${vendorId}`, tone: "neutral" };
  }

  const hasRequests = (openRequests?.length ?? 0) > 0;

  return (
    <div className="space-y-3">
      {/* Compact header row: pills + next action */}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2">
          {vendor?.tier ? <Pill>Tier: {vendor.tier}</Pill> : null}
          {vendor?.criticality ? (
            <span className={clsx("rounded-full border px-2.5 py-1 text-[11px] font-medium", toneFromCriticality(vendor.criticality))}>
              Criticality: {vendor.criticality}
            </span>
          ) : null}
          {vendor?.category ? <Pill>{vendor.category}</Pill> : null}
          <Pill>Requests: {openRequests?.length ?? 0}</Pill>
        </div>

        {nextAction ? (
          <div className="flex items-center gap-2">
            <Link href={nextAction.href} className={nextAction.tone === "primary" ? "btn-primary" : "btn-glass"}>
              {nextAction.label}
            </Link>
            <ActionHint>Next best action</ActionHint>
          </div>
        ) : null}
      </div>

      {/* Accepted risk collapsible (only if > 0) */}
      {acceptedCriticalCount > 0 ? (
        <details className="glass-inset p-3" open={false}>
          <summary className="cursor-pointer select-none text-sm font-semibold text-white">
            Accepted risk <span className="pill ml-2">{acceptedCriticalCount}</span>
            <span className="ml-2 text-xs font-normal text-white/50">click to expand</span>
          </summary>

          <div className="mt-2 text-sm text-white/70">
            {acceptedCriticalCount} critical issue{acceptedCriticalCount > 1 ? "s have" : " has"} been formally accepted by the organization.
          </div>

          <div className="mt-2">
            <Link href={`/issues?vendor=${vendorId}&status=ACCEPTED_RISK`} className="text-xs text-sky-300 hover:underline underline-offset-2">
              View accepted risks →
            </Link>
          </div>
        </details>
      ) : null}

      {/* Compact grid: Requests + Trend (2-col desktop, 1-col mobile) */}
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        {/* Outstanding Evidence Requests */}
        <div className="glass p-3">
          <details open={hasRequests}>
            <summary className="cursor-pointer select-none text-sm font-semibold text-white">
              Outstanding Evidence Requests{" "}
              <span className="pill ml-2">{openRequests?.length ?? 0}</span>
            </summary>

            {!hasRequests ? (
              <p className="mt-2 text-sm text-white/50">No outstanding requests 🎉</p>
            ) : (
              <ul className="mt-3 space-y-2">
                {openRequests.slice(0, 4).map((r: any) => {
                  const title = r?.title ?? r?.name ?? "Evidence request";
                  const created = fmtDate(r?.createdAt);
                  const status = (r?.status ?? "").toString().replaceAll("_", " ");

                  return (
                    <li key={String(r.id)} className="glass-inset p-2">
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="truncate text-sm font-medium text-white">{title}</p>
                          <p className="mt-0.5 text-xs text-white/50">
                            {status ? <span className="mr-2">{status}</span> : null}
                            {created ? <span>Requested {created}</span> : null}
                          </p>
                        </div>

                        <Link href={`/evidence/requests/${r.id}`} className="btn-glass py-1.5 px-2.5 text-xs">
                          View
                        </Link>
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}

            <div className="mt-3 flex items-center justify-between">
              <Link href={`/evidence/requests?vendor=${vendorId}`} className="text-xs text-sky-300 hover:underline underline-offset-2">
                View all →
              </Link>

              {hasRequests ? (
                <span className="pill">Follow-up recommended</span>
              ) : (
                <span className="pill">Clear</span>
              )}
            </div>
          </details>
        </div>

        {/* Risk Trend placeholder (compact) */}
        <div className="glass p-3">
          <div className="flex items-center justify-between">
            <p className="text-sm font-semibold text-white">Risk trend</p>
            <span className="pill">Phase 328B</span>
          </div>

          <p className="mt-2 text-sm text-white/60">
            {criticalOpenCount > 0
              ? "Risk score is elevated due to unresolved high-severity issues."
              : "Risk score appears stable. No critical open issues detected."}
          </p>

          <div className="mt-3 glass-inset p-3">
            <div className="flex items-center justify-between gap-2 text-xs text-white/60">
              <span>Critical open</span>
              <span className="pill">{criticalOpenCount}</span>
            </div>
            <div className="mt-2 text-[11px] text-white/40">
              Tip: keep this collapsed until charts land.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
