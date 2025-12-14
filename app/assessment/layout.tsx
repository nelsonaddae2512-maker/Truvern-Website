import type { ReactNode } from "react";
import AssessmentBreadcrumbs from "@/components/assessment-breadcrumbs";
import AssessmentSubnav from "@/components/assessment-subnav";

export default function AssessmentLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <div className="mx-auto max-w-7xl px-6 py-6 space-y-6">
      {/* Breadcrumbs */}
      <AssessmentBreadcrumbs />

      {/* Heading + description */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-50 tracking-tight">
            Assessment
          </h1>
          <p className="mt-1 text-sm text-slate-400">
            Build templates, manage question banks, and run structured vendor assessments.
          </p>
        </div>
      </div>

      {/* Sub-nav tab strip */}
      <AssessmentSubnav />

      {/* Content frame */}
      <div className="rounded-3xl border border-white/5 bg-slate-950/80 p-4 sm:p-6">
        {children}
      </div>
    </div>
  );
}
