import ActivityFeedPanel from "@/components/activity-feed-panel";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

export default async function VendorActivityPage({ params }: Props) {
  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold text-slate-50">Invalid vendor id</h1>
      </main>
    );
  }

  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-slate-50">Vendor activity</h1>
        <p className="mt-1 text-sm text-slate-200/70">
          Timeline of evidence uploads, issue status changes, and exports for this vendor.
        </p>
      </div>

      <ActivityFeedPanel scope="vendor" vendorId={vendorId} />
    </main>
  );
}