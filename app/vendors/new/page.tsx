// app/vendors/new/page.tsx
import Link from "next/link";
import NewVendorForm from "@/components/new-vendor-form";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export default function NewVendorPage() {
  return (
    <main className="container-page py-10 max-w-3xl">
      <div className="mb-6">
        <Link href="/vendors" className="btn-glass">
          ← Back to vendors
        </Link>
      </div>

      <h1 className="text-2xl font-semibold text-slate-50">New Vendor</h1>
      <p className="mt-1 text-sm text-slate-200/70">
        Add a third-party vendor to your trust network.
      </p>

      <NewVendorForm />
    </main>
  );
}
