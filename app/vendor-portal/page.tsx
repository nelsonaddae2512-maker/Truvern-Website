// ...inside VendorPortalPage, after you compute vendor + tasks:

const evidenceRequests = await prisma.evidenceRequest.findMany({
  where: { vendorId: vendor.id, status: { in: ["OPEN", "REJECTED"] } as any },
  orderBy: [{ dueAt: "asc" as any }, { updatedAt: "desc" as any }],
  take: 20,
});

// ...then in JSX where the placeholder was:
<div className="border-t border-white/10 px-5 py-4">
  <div className="flex items-center justify-between">
    <div className="text-sm font-semibold text-slate-50">Evidence requests</div>
    <span className="text-xs text-slate-200/60">
      {evidenceRequests.length} open
    </span>
  </div>

  {evidenceRequests.length === 0 ? (
    <p className="mt-2 text-sm text-slate-200/70">No evidence requests right now.</p>
  ) : (
    <div className="mt-3 divide-y divide-white/5 rounded-xl border border-white/10 overflow-hidden">
      {evidenceRequests.map((r: any) => (
        <div key={r.id} className="flex flex-col gap-3 px-4 py-4 md:flex-row md:items-center md:justify-between">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <div className="truncate text-sm font-medium text-slate-50">
                {r.label}
              </div>
              <span className="inline-flex items-center rounded-full border border-amber-500/20 bg-amber-500/10 px-2.5 py-1 text-xs text-amber-200">
                Action required
              </span>
              {r.dueAt ? (
                <span className="text-xs text-slate-200/60">
                  Due {fmt(r.dueAt)}
                </span>
              ) : null}
            </div>
            {r.description ? (
              <p className="mt-1 text-sm text-slate-200/70">{r.description}</p>
            ) : (
              <p className="mt-1 text-sm text-slate-200/50">No additional instructions.</p>
            )}
          </div>

          <div className="flex items-center gap-2">
            <Link
              href={`/vendor-portal/evidence-requests/${r.id}`}
              className="inline-flex items-center justify-center rounded-full bg-emerald-500 px-4 py-2 text-xs font-semibold text-slate-950 hover:bg-emerald-400"
            >
              Upload evidence ↗
            </Link>
          </div>
        </div>
      ))}
    </div>
  )}
</div>
