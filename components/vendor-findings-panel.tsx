// components/vendor-findings-panel.tsx
"use client";

import IssueInboxTable from "@/components/issue-inbox-table";

export default function VendorFindingsPanel({ vendorId }: { vendorId: number }) {
  return (
    <div className="mt-4">
      <IssueInboxTable vendorId={vendorId} />
    </div>
  );
}
