// app/issues/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { getCurrentOrgId } from "@/lib/current-org";
import IssueActions from "@/components/issue-actions";
import IssueCommentBox from "@/components/issue-comment-box";

function parseNumericId(raw: string): number | null {
  const m = String(raw || "").match(/\d+/);
  if (!m) return null;
  const n = Number(m[0]);
  return Number.isFinite(n) ? n : null;
}

function fmtDateTime(d: any) {
  try {
    return new Date(d).toLocaleString();
  } catch {
    return "";
  }
}

function eventSummary(type: string, payload: any) {
  const t = String(type || "").toUpperCase();

  if (t === "COMMENT") {
    const by = payload?.by ? String(payload.by) : "Someone";
    const comment = payload?.comment ? String(payload.comment) : "Left a comment.";
    return { title: "Comment", subtitle: by, body: comment };
  }

  if (t === "STATUS_CHANGE") {
    const from = payload?.from ? String(payload.from) : "—";
    const to = payload?.to ? String(payload.to) : "—";
    return { title: "Status changed", subtitle: `${from} → ${to}`, body: "" };
  }

  if (t === "CREATED") {
    const source = payload?.source ? String(payload.source) : "system";
    const control = payload?.control ? String(payload.control) : "";
    return {
      title: "Created",
      subtitle: source === "assessment" ? "From assessment" : `Source: ${source}`,
      body: control ? `Control: ${control}` : "",
    };
  }

  return { title: t || "EVENT", subtitle: "", body: "" };
}

function usedPayloadKeys(type: string) {
  const t = String(type || "").toUpperCase();
  if (t === "COMMENT") return new Set(["by", "comment"]);
  if (t === "STATUS_CHANGE") return new Set(["from", "to"]);
  if (t === "CREATED") return new Set(["source", "control"]);
  return new Set<string>();
}

function normalizeDetailValue(v: any): string {
  if (v == null) return "—";
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  try {
    return JSON.stringify(v);
  } catch {
    return String(v);
  }
}

function renderDetailRows(type: string, payload: any) {
  if (!payload || typeof payload !== "object") return null;

  const used = usedPayloadKeys(type);
  const entries = Object.entries(payload).filter(([k, v]) => {
    if (used.has(k)) return false;
    // hide empty
    if (v === undefined) return false;
    if (v === null) return false;
    if (typeof v === "string" && v.trim() === "") return false;
    return true;
  });

  // ✅ If payload contains nothing beyond what we already summarize, don't show Details.
  if (entries.length === 0) return null;

  return (
    <div className="mt-3 rounded-2xl border border-white/10 bg-black/20 p-4">
      <div className="text-xs font-medium text-slate-300">Details</div>
      <div className="mt-2 grid gap-2">
        {entries.map(([k, v]) => (
          <div
            key={k}
            className="flex flex-col gap-1 rounded-xl border border-white/10 bg-black/20 px-3 py-2"
          >
            <div className="text-[11px] uppercase tracking-wide text-slate-400">{k}</div>
            <div className="text-sm text-slate-200/80 break-words">
              {normalizeDetailValue(v)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default async function IssueDetailPage({
  params,
}: {
  params: Promise<{ id: string }> | { id: string };
}) {
  const orgId = await getCurrentOrgId();
  const resolvedParams = await Promise.resolve(params);

  const raw = resolvedParams?.id;
  const id = parseNumericId(raw);

  if (!id) {
    return (
      <main className="max-w-4xl mx-auto px-6 py-10">
        <h1 className="text-3xl font-semibold">Issue not found</h1>
        <p className="mt-2 text-slate-300/70">
          Invalid issue id: <span className="font-mono">{String(raw)}</span>
        </p>
        <Link href="/issues" className="inline-block mt-6 text-emerald-400 hover:underline">
          ← Back to Issues
        </Link>
      </main>
    );
  }

  if (!orgId) {
    return (
      <main className="max-w-4xl mx-auto px-6 py-10">
        <h1 className="text-3xl font-semibold">Issue not found</h1>
        <p className="mt-2 text-slate-300/70">No organization context found for this user.</p>
        <Link href="/issues" className="inline-block mt-6 text-emerald-400 hover:underline">
          ← Back to Issues
        </Link>
      </main>
    );
  }

  const issue = await prisma.issue.findFirst({
    where: { id, organizationId: orgId },
    include: {
      vendor: { select: { id: true, name: true, slug: true } },
      createdBy: { select: { id: true, email: true, name: true } },
      assignedTo: { select: { id: true, email: true, name: true } },
      events: { orderBy: { createdAt: "desc" } },
    },
  });

  if (!issue) {
    return (
      <main className="max-w-4xl mx-auto px-6 py-10">
        <h1 className="text-3xl font-semibold">Issue not found</h1>
        <p className="mt-2 text-slate-300/70">Issue #{id} wasn’t found in your organization scope.</p>
        <Link href="/issues" className="inline-block mt-6 text-emerald-400 hover:underline">
          ← Back to Issues
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-4xl mx-auto px-6 py-10">
      <div className="flex items-start justify-between gap-6">
        <div className="min-w-0">
          <div className="text-sm text-slate-300/70">
            #{issue.id} • {String(issue.status)} • {String(issue.severity)}
            {issue.dueAt ? ` • Due: ${new Date(issue.dueAt).toLocaleDateString()}` : ""}
          </div>
          <h1 className="mt-2 text-3xl font-semibold truncate">{issue.title}</h1>

          <div className="mt-3 text-slate-300/80">
            Vendor:{" "}
            {issue.vendor ? (
              <Link href={`/vendors/${issue.vendor.id}`} className="text-emerald-300 hover:underline">
                {issue.vendor.name}
              </Link>
            ) : (
              "—"
            )}
            {issue.vendor?.slug ? (
              <span className="ml-2 text-xs text-slate-400/80">({issue.vendor.slug})</span>
            ) : null}
          </div>

          {issue.description ? (
            <p className="mt-4 text-slate-200/80 whitespace-pre-line">{issue.description}</p>
          ) : null}
        </div>

        <div className="flex flex-col items-end gap-3">
          <IssueActions issueId={issue.id} currentStatus={String(issue.status)} />
          <Link
            href="/issues"
            className="rounded-xl px-3 py-2 text-sm ring-1 ring-white/10 hover:ring-white/20"
          >
            Back
          </Link>
        </div>
      </div>

      <div className="mt-8 grid gap-6">
        <div className="rounded-3xl border border-white/10 bg-white/5 p-6">
          <div className="text-sm font-medium text-slate-200">Ownership</div>
          <div className="mt-3 text-sm text-slate-300/80">
            <div>Created by: {issue.createdBy?.name || issue.createdBy?.email || "—"}</div>
            <div className="mt-1">Assigned to: {issue.assignedTo?.name || issue.assignedTo?.email || "—"}</div>
          </div>
        </div>

        <IssueCommentBox
          issueId={issue.id}
          byDefault={issue.assignedTo?.email || issue.createdBy?.email || ""}
        />

        <div className="rounded-3xl border border-white/10 bg-white/5 p-6">
          <div className="text-sm font-medium text-slate-200">Activity</div>

          <div className="mt-4 space-y-3">
            {issue.events.length === 0 ? (
              <div className="text-slate-300/70">No events yet.</div>
            ) : (
              issue.events.map((e) => {
                const payload = e.payload as any;
                const s = eventSummary(e.type, payload);

                return (
                  <div key={e.id} className="rounded-2xl border border-white/10 bg-black/20 p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <div className="text-sm text-slate-200">{s.title}</div>
                        {s.subtitle ? (
                          <div className="mt-1 text-xs text-slate-400">{s.subtitle}</div>
                        ) : null}
                        {s.body ? (
                          <div className="mt-2 text-sm text-slate-200/80">{s.body}</div>
                        ) : null}
                      </div>
                      <div className="text-xs text-slate-400">{fmtDateTime(e.createdAt)}</div>
                    </div>

                    {/* ✅ Only render details if they add info beyond the summary */}
                    {renderDetailRows(e.type, payload)}
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </main>
  );
}
