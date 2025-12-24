// app/org/evidence-requests/new/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import NewEvidenceRequestClient from "./new-evidence-request.client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function parseVendorId(searchParams: Record<string, string | string[] | undefined>) {
  const v = searchParams.vendorId;
  const s = Array.isArray(v) ? v[0] : v;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

export default async function NewEvidenceRequestPage({
  searchParams,
}: {
  searchParams: Record<string, string | string[] | undefined>;
}) {
  const org = await requireDbOrganization();

  const vendorId = parseVendorId(searchParams);

  const vendor =
    vendorId != null
      ? await prisma.vendor.findFirst({
          where: { id: vendorId, organizationId: org.id } as any,
          select: { id: true, name: true },
        })
      : null;

  return (
    <main className="container-page py-10">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-white">Request evidence</h1>
          <p className="mt-1 text-sm text-white/70">
            Create a new evidence request and set a due date for vendor follow-up.
          </p>
        </div>

        <Link className="btn-glass" href="/evidence">
          Back
        </Link>
      </div>

      <div className="mt-6 glass-soft rounded-2xl p-5">
        <NewEvidenceRequestClient
          orgId={org.id}
          vendorId={vendor?.id ?? null}
          vendorName={vendor?.name ?? null}
        />
      </div>
    </main>
  );
}
