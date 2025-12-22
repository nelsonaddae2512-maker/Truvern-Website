"use client";

import { useOrganizationList } from "@clerk/nextjs";
import { useRouter } from "next/navigation";

export default function OrgMenu() {
  const router = useRouter();
  const { organizationList, setActive } = useOrganizationList();

  if (!organizationList) return null;

  return (
    <div className="flex items-center gap-2">
      {organizationList.map((org) => (
        <button
          key={org.organization.id}
          className="rounded-xl border border-slate-800 bg-slate-900/40 px-3 py-2 text-sm text-slate-100 hover:bg-slate-900/70"
          onClick={async () => {
            await setActive({ organization: org.organization.id });
            router.refresh(); // IMPORTANT
          }}
        >
          {org.organization.name}
        </button>
      ))}
    </div>
  );
}
