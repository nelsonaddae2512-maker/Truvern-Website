import Link from "next/link";
import prisma from "@/lib/prisma";

type ParamsPromise = Promise<{ id: string }>;

export default async function VendorEvidenceRequestPage({ params }: { params: ParamsPromise }) {
  const { id } = await params;
  const requestId = Number(id);

  if (!Number.isFinite(requestId)) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">Invalid request id.</p>
      </main>
    );
  }

  const reqItem = await prisma.evidenceRequest.findUnique({
    where: { id: requestId },
    include: { vendor: { select: { id: true, name: true } } },
  });

  if (!reqItem) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">Evidence request not found.</p>
      </main>
    );
  }

  return (
    <main className="max-w-5xl mx-auto px-4 py-10">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-xs tracking-[0.25em] text-emerald-200/80">EVIDENCE SUBMISSION</div>
          <h1 className="mt-2 text-3xl font-semibold text-slate-50">{reqItem.label}</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Vendor: <span className="font-semibold text-slate-100">{reqItem.vendor?.name ?? "—"}</span>
          </p>
        </div>

        <Link
          href="/vendor-portal"
          className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
        >
          Back to portal ↗
        </Link>
      </div>

      <div className="mt-8 rounded-2xl border border-white/10 bg-slate-950/40 p-5">
        <p className="text-sm text-slate-200/70">
          {reqItem.description ?? "No additional instructions."}
        </p>

        <form
          className="mt-6 space-y-3"
          action={async (formData) => {
            "use server";
            const title = String(formData.get("title") ?? "").trim() || reqItem.label;
            const notes = String(formData.get("notes") ?? "").trim() || null;

            // Call API submit (keeps auth logic centralized)
            await fetch(`${process.env.NEXT_PUBLIC_APP_URL ?? ""}/api/evidence-requests/${reqItem.id}/submit`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ title, notes, kind: reqItem.kind }),
            }).catch(() => {});
          }}
        >
          <label className="block space-y-1">
            <div className="text-xs text-slate-200/60">Evidence title</div>
            <input
              name="title"
              defaultValue={reqItem.label}
              className="w-full rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 outline-none"
            />
          </label>

          <label className="block space-y-1">
            <div className="text-xs text-slate-200/60">Notes (optional)</div>
            <textarea
              name="notes"
              rows={4}
              className="w-full rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 outline-none"
              placeholder="Add clarifying notes, scope, links, or details…"
            />
          </label>

          <div className="flex items-center gap-2">
            <button className="rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400">
              Submit evidence ↗
            </button>

            <span className="text-xs text-slate-200/50">
              This is a “real workflow” submission now; file upload wiring comes next.
            </span>
          </div>
        </form>
      </div>
    </main>
  );
}
