// app/evidence/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import EvidenceRequestStatusBadge from "@/components/evidence-request-status-badge";
import RemindDueSoonButton from "@/components/evidence/remind-due-soon-button.client";
import EvidenceInboxActionsClient from "@/components/evidence/evidence-inbox-actions.client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "2-digit", day: "2-digit" });
}

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

type Row = {
  id: number;
  label: string;
  kind: string;
  dueAt: Date | null;
  updatedAt: Date;
  status: string;
  vendor: {
    id: number;
    name: string;
    contactName: string | null;
    contactEmail: string | null;
  } | null;
};

function kpiCard(label: string, value: number, hint?: string) {
  return (
    <div className="glass-soft rounded-2xl border border-white/10 p-4">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
      {hint ? <div className="mt-1 text-xs text-muted-foreground">{hint}</div> : null}
    </div>
  );
}

export default async function EvidenceHubPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const org = await requireDbOrganization();
  const sp = (await searchParams) || {};
  const view = typeof sp.view === "string" ? sp.view : "all";

  const rows: Row[] = (await prisma.evidenceRequest.findMany({
    where: { organizationId: org.id },
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      label: true,
      kind: true,
      dueAt: true,
      updatedAt: true,
      status: true,
      vendor: {
        select: { id: true, name: true, contactName: true, contactEmail: true },
      },
    },
    take: 500,
  })) as any;

  const now = new Date();
  const dueSoonEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  const openRows = rows.filter((r) => r.status === "OPEN");
  const overdue = openRows.filter((r) => r.dueAt && r.dueAt.getTime() < now.getTime());
  const dueSoon = openRows.filter(
    (r) => r.dueAt && r.dueAt.getTime() >= now.getTime() && r.dueAt.getTime() <= dueSoonEnd.getTime()
  );
  const missingEmail = openRows.filter((r) => !(r.vendor?.contactEmail && r.vendor.contactEmail.trim()));

  const filtered =
    view === "open"
      ? openRows
      : view === "overdue"
      ? overdue
      : view === "dueSoon"
      ? dueSoon
      : view === "missingEmail"
      ? missingEmail
      : rows;

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold">Evidence Inbox</h1>
          <p className="text-muted-foreground mt-1">
            Track vendor evidence requests, due dates, and review status.
          </p>
        </div>

        <div className="flex gap-2 items-center">
          {/* ✅ Bulk reminder button with summary */}
          <RemindDueSoonButton days={7} />
          <Link className="btn-glass" href="/vendors">
            Vendors
          </Link>
        </div>
      </div>

      {/* ✅ SLA / KPI strip */}
      <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Link href="/evidence?view=open" className="block">
          {kpiCard("Open", openRows.length, "Requests requiring action")}
        </Link>
        <Link href="/evidence?view=overdue" className="block">
          {kpiCard("Overdue", overdue.length, "Due date passed")}
        </Link>
        <Link href="/evidence?view=dueSoon" className="block">
          {kpiCard("Due soon (7d)", dueSoon.length, "Due within 7 days")}
        </Link>
        <Link href="/evidence?view=missingEmail" className="block">
          {kpiCard("Missing email", missingEmail.length, "Can’t send reminders")}
        </Link>
      </div>

      {/* Filter pills */}
      <div className="mt-4 flex flex-wrap gap-2">
        {[
          ["all", "All"],
          ["open", "Open"],
          ["overdue", "Overdue"],
          ["dueSoon", "Due soon"],
          ["missingEmail", "Missing email"],
        ].map(([k, label]) => (
          <Link
            key={k}
            href={`/evidence?view=${k}`}
            className={clsx(
              "btn-glass",
              view === k && "ring-1 ring-white/20"
            )}
          >
            {label}
          </Link>
        ))}
      </div>

      <div className="glass-soft mt-6 overflow-hidden rounded-2xl border border-white/10">
        <div className="grid grid-cols-[1.6fr_0.8fr_0.6fr_0.7fr_0.7fr_1fr] gap-3 px-5 py-3 text-xs font-semibold tracking-wide text-muted-foreground">
          <div>REQUEST</div>
          <div>VENDOR</div>
          <div>DUE</div>
          <div>UPDATED</div>
          <div>STATUS</div>
          <div className="text-right">ACTIONS</div>
        </div>

        <div className="divide-y divide-white/10">
          {filtered.map((r) => (
            <div
              key={r.id}
              className="grid grid-cols-[1.6fr_0.8fr_0.6fr_0.7fr_0.7fr_1fr] gap-3 px-5 py-4"
            >
              <div>
                <div className="font-semibold">{r.label}</div>
                <div className="text-xs text-muted-foreground">
                  #{r.id} • {String(r.kind || "").toUpperCase()}
                </div>
              </div>

              <div className="truncate">{r.vendor?.name ?? "—"}</div>

              <div className="text-sm">{fmtDate(r.dueAt)}</div>
              <div className="text-sm">{fmtDate(r.updatedAt)}</div>

              <div>
                <EvidenceRequestStatusBadge status={r.status as any} />
              </div>

              {/* ✅ Actions are handled in a client component so we can open modal */}
              <div className="flex justify-end">
                <EvidenceInboxActionsClient
                  requestId={r.id}
                  status={r.status}
                  vendorId={r.vendor?.id ?? null}
                  vendorName={r.vendor?.name ?? "Vendor"}
                  vendorContactName={r.vendor?.contactName ?? null}
                  vendorContactEmail={r.vendor?.contactEmail ?? null}
                />
              </div>
            </div>
          ))}

          {filtered.length === 0 ? (
            <div className="px-5 py-10 text-sm text-muted-foreground">No requests in this view.</div>
          ) : null}
        </div>
      </div>
    </main>
  );
}
