// app/select-org/page.tsx
import SelectOrgClient from "@/components/select-org/select-org-client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export default function SelectOrgPage() {
  return (
    <main className="container-page py-10">
      <div className="mx-auto max-w-xl rounded-2xl border border-slate-800/70 bg-slate-950/40 p-6">
        <h1 className="text-2xl font-semibold text-white">
          Select an organization
        </h1>
        <p className="mt-2 text-sm text-slate-300">
          You’re signed in, but no organization is selected yet. Choose an
          organization (or create one) to continue.
        </p>

        <div className="mt-6">
          <SelectOrgClient />
        </div>

        <p className="mt-6 text-xs text-slate-400">
          Tip: If you just created an org, select it here to unlock Vendors,
          Issues, and Board views.
        </p>
      </div>
    </main>
  );
}
