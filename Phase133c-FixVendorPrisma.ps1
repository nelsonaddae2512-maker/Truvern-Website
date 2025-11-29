$ErrorActionPreference = "Stop"

Write-Host "=== Phase133c: Fix vendor pages Prisma import ===" -ForegroundColor Cyan

$root = $PSScriptRoot

$vendorsListFile   = Join-Path $root "app\vendors\page.tsx"
$vendorDetailFile  = Join-Path $root "app\vendors\[id]\page.tsx"

Write-Host "[INFO] Writing vendors list page with correct Prisma import..." -ForegroundColor Cyan

@"
import { prisma } from "@/lib/prisma";
import Link from "next/link";

export default async function VendorsPage() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { createdAt: "desc" },
  });

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-10 space-y-6">
        <header className="space-y-2">
          <h1 className="text-3xl font-semibold">Vendor directory</h1>
          <p className="text-sm text-slate-300">
            This view pulls directly from your Vendor table. Click a row to see
            the vendor profile and recent assessments.
          </p>
        </header>

        {vendors.length === 0 && (
          <p className="text-sm text-slate-400">
            No vendors found in the database yet. Seed a few vendors, then reload.
          </p>
        )}

        {vendors.length > 0 && (
          <div className="overflow-x-auto rounded-lg border border-slate-800 bg-slate-900/40">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-900/60">
                <tr className="text-left text-slate-300">
                  <th className="px-4 py-2">Name</th>
                  <th className="px-4 py-2">Risk score</th>
                  <th className="px-4 py-2">Created</th>
                </tr>
              </thead>
              <tbody>
                {vendors.map((v) => (
                  <tr
                    key={v.id}
                    className="border-t border-slate-800 hover:bg-slate-900 cursor-pointer"
                  >
                    <td className="px-4 py-2">
                      <Link
                        href={`/vendors/\${v.id}`}
                        className="text-sky-400 hover:underline"
                      >
                        {v.name}
                      </Link>
                    </td>
                    <td className="px-4 py-2 text-sky-300">{v.riskScore}</td>
                    <td className="px-4 py-2 text-slate-400">
                      {new Date(v.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
"@ | Set-Content -Path $vendorsListFile -Encoding UTF8

Write-Host "[OK] vendors/page.tsx updated." -ForegroundColor Green

Write-Host "[INFO] Writing vendor detail page with correct Prisma import..." -ForegroundColor Cyan

@"
import { prisma } from "@/lib/prisma";

type PageProps = {
  params: { id: string };
};

export default async function VendorDetailPage({ params }: PageProps) {
  const id = Number(params.id);

  if (Number.isNaN(id)) {
    return (
      <main className="p-6 text-red-400">
        Invalid vendor id.
      </main>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id },
    include: {
      assessments: {
        orderBy: { createdAt: "desc" },
        take: 10,
      },
    },
  });

  if (!vendor) {
    return (
      <main className="p-6 text-red-400">
        Vendor not found.
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-10 space-y-6">
        <header className="space-y-2">
          <p className="text-xs uppercase tracking-[0.2em] text-sky-400">
            Vendor profile
          </p>
          <h1 className="text-3xl font-semibold">{vendor.name}</h1>
          <p className="text-sm text-slate-300">
            Current risk score:{" "}
            <span className="text-sky-400 font-semibold">
              {vendor.riskScore}
            </span>
          </p>
        </header>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Recent assessments</h2>

          {vendor.assessments.length === 0 && (
            <p className="text-sm text-slate-400">
              No assessments recorded yet for this vendor.
            </p>
          )}

          <div className="space-y-3">
            {vendor.assessments.map((a) => (
              <div
                key={a.id}
                className="border border-slate-800 rounded-lg p-4 bg-slate-900/40"
              >
                <p className="font-medium">
                  Risk level:{" "}
                  <span className="text-sky-300">{a.riskLevel}</span>
                </p>
                <p className="text-xs text-slate-400">
                  {new Date(a.createdAt).toLocaleString()}
                </p>
              </div>
            ))}
          </div>
        </section>
      </section>
    </main>
  );
}
"@ | Set-Content -LiteralPath $vendorDetailFile -Encoding UTF8

Write-Host "[OK] vendors/[id]/page.tsx updated." -ForegroundColor Green

Write-Host "[STEP] Deploying with Vercel cloud build..." -ForegroundColor Cyan
vercel --prod --yes

if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Vercel deploy failed with exit code $LASTEXITCODE." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "=== Phase133c complete ===" -ForegroundColor Cyan
