// components/evidence-request-status-badge.tsx
import React from "react";

type Status = "OPEN" | "SUBMITTED" | "REJECTED" | "APPROVED" | string;

function tone(status: Status) {
  switch (status) {
    case "OPEN":
      return "bg-sky-500/10 text-sky-200 border-sky-500/30";
    case "SUBMITTED":
      return "bg-amber-500/10 text-amber-200 border-amber-500/30";
    case "REJECTED":
      return "bg-rose-500/10 text-rose-200 border-rose-500/30";
    case "APPROVED":
      return "bg-emerald-500/10 text-emerald-200 border-emerald-500/30";
    default:
      return "bg-slate-500/10 text-slate-200 border-slate-500/30";
  }
}

export default function EvidenceRequestStatusBadge({ status }: { status: Status }) {
  return (
    <span
      className={[
        "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold tracking-wide",
        tone(status),
      ].join(" ")}
    >
      {String(status).toUpperCase()}
    </span>
  );
}
