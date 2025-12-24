// app/vendors/page.tsx (PATCH)
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import VendorsTableClient from "@/components/vendors/vendors-table-client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type VendorRow = {
  id: number;
  name: string;
  updatedAt: Date | string;
  category?: string | null;
  contactEmail?: string | null; // ✅ add
  _count?: {
    assessments?: number;
    issues?: number;
    evidence?: number;
    evidenceRequests?: number;
  };
};

export default async function VendorsPage() {
  const org = await requireDbOrganization();

  // Keep whatever “safe fetch” logic you had; main change is select/include contactEmail.
  const rows: VendorRow[] = (await prisma.vendor.findMany({
    where: { organizationId: org.id } as any,
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      name: true,
      updatedAt: true,
      category: true,
      contactEmail: true, // ✅ add
      _count: {
        select: {
          assessments: true,
          issues: true,
          evidence: true,
          evidenceRequests: true,
        },
      },
    },
    take: 500,
  })) as any;

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold">Vendors</h1>
          <p className="text-muted-foreground mt-1">Manage vendors and contacts.</p>
        </div>
        <div className="flex gap-2">
          <Link className="btn-primary" href="/vendors/new">
            New Vendor
          </Link>
        </div>
      </div>

      <div className="mt-6">
        <VendorsTableClient rows={rows as any} />
      </div>
    </main>
  );
}
