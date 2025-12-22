import ActivityFeedPanel from "@/components/activity-feed-panel";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export default function ActivityPage() {
  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-slate-50">Activity</h1>
        <p className="mt-1 text-sm text-slate-200/70">
          Org-wide audit trail across vendors, evidence, issues, and board exports.
        </p>
      </div>

      <ActivityFeedPanel scope="org" />
    </main>
  );
}