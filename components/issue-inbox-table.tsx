// components/issue-inbox-table.tsx
"use client";

import Link from "next/link";

type IssueRow = {
  id: number;
  title: string;
  severity: string;
  status: string;
  vendor?: {
    id: number;
    name: string;
  } | null;
  assessment?: {
    id: number;
    title?: string | null;
  } | null;
  createdAt: string | Date;
};

type Props = {
  issues: IssueRow[];
};

function formatDate(value: string | Date) {
  const d = typeof value === "string" ? new Date(value) : value;
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function severityTone(sev: string) {
  switch (sev) {
    case "CRITICAL":
      return "text-rose-300";
    case "HIGH":
      return "text-amber-300";
    case "MEDIUM":
      return "text-cyan-300";
    default:
      return "text-slate-300";
  }
}

function statusTone(status: string) {
  switch (status) {
    case "OPEN":
      return "text-amber-300";
    case "IN_REVIEW":
      return "text-cyan-300";
    case "RESOLVED":
      return "text-emerald-300";
    case "ACCEPTED_RISK":
      return "text-violet-300";
    default:
      return "text-slate-300";
  }
}

export default function IssueInboxTable({ issues }: Props) {
  if (!issues || issues.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-700 bg-slate-950/60 px-4 py-6 text-sm text-slate-400">
        No issues found.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-950/80">
      <table className="w-full text-sm">
        <thead className="bg-slate-900/60 text-[11px] uppercase tracking-wider text-slate-400">
          <tr>
            <th className="px-4 py-3 text-left">Issue</th>
            <th className="px-4 py-3 text-left">Vendor</th>
            <th className="px-4 py-3 text-left">Severity</th>
            <th className="px-4 py-3 text-left">Status</th>
            <th className="px-4 py-3 text-left">Created</th>
          </tr>
        </thead>

        <tbody>
          {issues.map((issue) => (
            <tr
              key={issue.id}
              className="group border-t border-slate-800 hover:bg-slate-900/70"
            >
              {/* Issue title → clickable */}
              <td className="px-4 py-3">
                <Link
                  href={`/issues/${issue.id}`}
                  className="font-medium text-slate-100 hover:text-emerald-300"
                >
                  {issue.title}
                </Link>
                {issue.assessment?.title && (
                  <div className="text-[11px] text-slate-500">
                    {issue.assessment.title}
                  </div>
                )}
              </td>

              {/* Vendor */}
              <td className="px-4 py-3">
                {issue.vendor ? (
                  <Link
                    href={`/vendors/${issue.vendor.id}`}
                    className="text-slate-300 hover:text-emerald-300"
                  >
                    {issue.vendor.name}
                  </Link>
                ) : (
                  <span className="text-slate-500">—</span>
                )}
              </td>

              {/* Severity */}
              <td className="px-4 py-3">
                <span className={`font-semibold ${severityTone(issue.severity)}`}>
                  {issue.severity}
                </span>
              </td>

              {/* Status */}
              <td className="px-4 py-3">
                <span className={`font-semibold ${statusTone(issue.status)}`}>
                  {issue.status}
                </span>
              </td>

              {/* Created */}
              <td className="px-4 py-3 text-slate-400">
                {formatDate(issue.createdAt)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
