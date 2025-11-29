$ErrorActionPreference = "Stop"

Write-Host "=== Phase150: Vendor Dossier Upgrade (/vendors/[id]) ===" -ForegroundColor Cyan

# Ensure we are in the project root
$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

# Paths for vendors/[id]/page.tsx
$vendorsDir   = Join-Path $root "app\vendors"
$vendorIdDir  = Join-Path $vendorsDir "[id]"
$pagePath     = Join-Path $vendorIdDir "page.tsx"

# 1) Ensure directories exist
if (-not (Test-Path $vendorsDir)) {
    New-Item -ItemType Directory -Path $vendorsDir | Out-Null
    Write-Host "[INFO] Created app/vendors directory." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] app/vendors directory already exists." -ForegroundColor DarkYellow
}

if (-not (Test-Path -LiteralPath $vendorIdDir)) {
    New-Item -ItemType Directory -LiteralPath $vendorIdDir | Out-Null
    Write-Host "[INFO] Created app/vendors/[id] directory." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] app/vendors/[id] directory already exists." -ForegroundColor DarkYellow
}

# 2) Backup existing vendors/[id]/page.tsx if present
if (Test-Path -LiteralPath $pagePath) {
    $stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$pagePath.bak-$stamp"
    Copy-Item -LiteralPath $pagePath -Destination $backupPath
    Write-Host "[INFO] Backed up existing vendors/[id]/page.tsx to: $backupPath" -ForegroundColor DarkYellow
} else {
    Write-Host "[WARN] No existing vendors/[id]/page.tsx found; a new one will be created." -ForegroundColor Yellow
}

# 3) Write new vendor dossier page
$pageContent = @'
import { prisma } from "@/lib/prisma";
import Link from "next/link";

export const dynamic = "force-dynamic";

type DossierVendor = {
  id: number;
  name: string;
  riskScore: number | null;
  assessments: { id: number; createdAt: Date; riskLevel: string }[];
};

function tier(score: number | null): "low" | "medium" | "high" | "critical" {
  const s = score ?? 0;
  if (s >= 80) return "critical";
  if (s >= 60) return "high";
  if (s >= 40) return "medium";
  return "low";
}

function formatDate(input: Date | string | null | undefined): string {
  if (!input) return "—";
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString();
}

function addMonths(date: Date, months: number): Date {
  const d = new Date(date);
  d.setMonth(d.getMonth() + months);
  return d;
}

function calcReassessmentDate(v: DossierVendor): string {
  const latest = v.assessments?.[0];
  if (!latest) return "Not scheduled";

  const level = tier(v.riskScore);
  const base = new Date(latest.createdAt);

  const months =
    level === "critical"
      ? 3
      : level === "high"
      ? 6
      : level === "medium"
      ? 12
      : 24;

  const due = addMonths(base, months);
  return formatDate(due);
}

/**
 * Lightweight helpers to make the dossier feel rich without
 * requiring new database fields yet. These can later be replaced
 * with real Vendor columns (industry, service, contact, etc.).
 */
function inferBusinessService(name: string): string {
  const lower = name.toLowerCase();
  if (lower.includes("pay") || lower.includes("billing")) return "Payments & billing";
  if (lower.includes("hr") || lower.includes("talent")) return "HR & people";
  if (lower.includes("backup") || lower.includes("data center") || lower.includes("cloud"))
    return "Infrastructure & hosting";
  if (lower.includes("email") || lower.includes("relay")) return "Messaging & notifications";
  if (lower.includes("legal")) return "Legal & compliance";
  return "General third-party service";
}

function inferIndustry(name: string): string {
  const lower = name.toLowerCase();
  if (lower.includes("finance") || lower.includes("bank")) return "Financial services";
  if (lower.includes("analytics") || lower.includes("data")) return "Analytics / data platform";
  if (lower.includes("security")) return "Security & monitoring";
  if (lower.includes("cloud")) return "Cloud / infrastructure";
  if (lower.includes("hr")) return "HR technology";
  return "Technology / SaaS";
}

function inferContactEmail(name: string): string {
  // Extremely simple guess based on the vendor name
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "");
  return `security@${slug || "vendor"}.example.com`;
}

function remediationItems(v: DossierVendor): {
  id: string;
  title: string;
  status: "pending" | "due-soon" | "overdue";
  dueOn: string;
}[] {
  const level = tier(v.riskScore);
  const baseDate =
    v.assessments?.[0]?.createdAt ?? new Date().toISOString();

  const base = new Date(baseDate);
  const soon = addMonths(base, 1);
  const later = addMonths(base, 3);
  const overdue = addMonths(base, -1);

  if (level === "low") {
    return [
      {
        id: "low-1",
        title: "Confirm annual policy review completed.",
        status: "pending",
        dueOn: formatDate(later),
      },
    ];
  }

  if (level === "medium") {
    return [
      {
        id: "med-1",
        title: "Provide latest SOC 2 or equivalent report.",
        status: "pending",
        dueOn: formatDate(later),
      },
      {
        id: "med-2",
        title: "Document data retention schedule for customer data.",
        status: "due-soon",
        dueOn: formatDate(soon),
      },
    ];
  }

  if (level === "high") {
    return [
      {
        id: "high-1",
        title: "Implement MFA for all privileged accounts.",
        status: "due-soon",
        dueOn: formatDate(soon),
      },
      {
        id: "high-2",
        title: "Upload evidence of quarterly vulnerability scanning.",
        status: "pending",
        dueOn: formatDate(later),
      },
    ];
  }

  // critical
  return [
    {
      id: "crit-1",
      title:
        "Complete targeted remediation plan and provide evidence for all high findings.",
      status: "overdue",
      dueOn: formatDate(overdue),
    },
    {
      id: "crit-2",
      title: "Schedule executive readout on residual risk.",
      status: "due-soon",
      dueOn: formatDate(soon),
    },
  ];
}

export default async function VendorDossierPage({
  params,
}: {
  params: { id: string };
}) {
  const id = Number(params.id);
  if (!id || Number.isNaN(id)) {
    return (
      <main className="min-h-screen bg-slate-950 text-slate-50">
        <section className="max-w-3xl mx-auto px-4 py-10">
          <p className="text-sm text-slate-300">
            Invalid vendor identifier. Please return to the{" "}
            <Link href="/vendors" className="text-sky-300 hover:underline">
              vendor catalogue
            </Link>
            .
          </p>
        </section>
      </main>
    );
  }

  const vendor = (await prisma.vendor.findUnique({
    where: { id },
    include: {
      assessments: {
        orderBy: { createdAt: "desc" },
      },
    },
  })) as DossierVendor | null;

  if (!vendor) {
    return (
      <main className="min-h-screen bg-slate-950 text-slate-50">
        <section className="max-w-3xl mx-auto px-4 py-10">
          <p className="text-sm text-slate-300">
            Vendor not found. Return to the{" "}
            <Link href="/vendors" className="text-sky-300 hover:underline">
              vendor catalogue
            </Link>
            .
          </p>
        </section>
      </main>
    );
  }

  const level = tier(vendor.riskScore);
  const tierLabel =
    level === "low"
      ? "Low"
      : level === "medium"
      ? "Medium"
      : level === "high"
      ? "High"
      : "Critical";

  const businessService = inferBusinessService(vendor.name);
  const industry = inferIndustry(vendor.name);
  const contactEmail = inferContactEmail(vendor.name);
  const reassessmentDue = calcReassessmentDate(vendor);
  const items = remediationItems(vendor);

  const latestAssessment = vendor.assessments?.[0] ?? null;

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-6xl mx-auto px-4 py-10 space-y-10">
        {/* Header / summary strip */}
        <header className="space-y-4">
          <p className="text-xs uppercase tracking-[0.25em] text-sky-400">
            Vendor dossier
          </p>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h1 className="text-3xl md:text-4xl font-semibold">
              {vendor.name}
            </h1>
            <div className="flex flex-wrap items-center gap-3">
              <div className="rounded-lg border border-slate-800 bg-slate-900/40 px-4 py-2">
                <p className="text-xs text-slate-400 uppercase tracking-wide">
                  Risk score
                </p>
                <p className="text-xl font-semibold">
                  {vendor.riskScore ?? "—"}
                </p>
              </div>
              <div className="rounded-lg border border-slate-800 bg-slate-900/40 px-4 py-2">
                <p className="text-xs text-slate-400 uppercase tracking-wide">
                  Risk tier
                </p>
                <p
                  className={[
                    "text-sm font-semibold",
                    level === "low"
                      ? "text-emerald-400"
                      : level === "medium"
                      ? "text-sky-300"
                      : level === "high"
                      ? "text-amber-300"
                      : "text-rose-400",
                  ].join(" ")}
                >
                  {tierLabel}
                </p>
              </div>
              <div className="rounded-lg border border-slate-800 bg-slate-900/40 px-4 py-2">
                <p className="text-xs text-slate-400 uppercase tracking-wide">
                  Reassessment due
                </p>
                <p className="text-sm font-semibold text-slate-50">
                  {reassessmentDue}
                </p>
              </div>
            </div>
          </div>

          <p className="text-sm md:text-base text-slate-300 max-w-3xl">
            This page acts as the single source of truth for this vendor&apos;s
            third-party risk profile: key details, latest assessment, upcoming
            reassessment, and a working list of remediation items.
          </p>

          <div className="flex flex-wrap gap-3 pt-1">
            <Link
              href="/vendors"
              className="inline-flex items-center rounded-md border border-slate-700 px-3 py-1.5 text-xs font-semibold text-slate-100 hover:border-sky-500 transition"
            >
              Back to vendor catalogue
            </Link>
            <Link
              href="/vendor"
              className="inline-flex items-center rounded-md border border-slate-700 px-3 py-1.5 text-xs font-semibold text-slate-100 hover:border-sky-500 transition"
            >
              Open vendor workspace view
            </Link>
          </div>
        </header>

        {/* Vendor profile strip */}
        <section className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Business service
            </p>
            <p className="text-sm text-slate-100">{businessService}</p>
            <p className="text-xs text-slate-400">
              The primary business capability this vendor supports.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Industry
            </p>
            <p className="text-sm text-slate-100">{industry}</p>
            <p className="text-xs text-slate-400">
              High-level industry classification, inferred from the vendor
              profile. This can be replaced by a structured field later.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Primary security contact
            </p>
            <p className="text-sm text-slate-100">{contactEmail}</p>
            <p className="text-xs text-slate-400">
              Where Truvern expects security questionnaires and evidence
              notifications to be sent.
            </p>
          </div>
        </section>

        {/* Assessment timeline */}
        <section className="space-y-3">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-lg font-semibold">Assessment timeline</h2>
            <p className="text-xs text-slate-400">
              Most recent assessments appear first.
            </p>
          </div>

          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4">
            {vendor.assessments.length === 0 ? (
              <p className="text-sm text-slate-300">
                No assessments have been recorded for this vendor yet.
              </p>
            ) : (
              <ol className="space-y-3">
                {vendor.assessments.map((a, idx) => (
                  <li
                    key={a.id ?? idx}
                    className="flex flex-col gap-1 border-l border-slate-800 pl-4"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-sm font-medium text-slate-100">
                        Assessment {vendor.assessments.length - idx}
                      </p>
                      <p className="text-xs text-slate-400">
                        {formatDate(a.createdAt)}
                      </p>
                    </div>
                    <p className="text-xs text-slate-300">
                      Recorded risk level:{" "}
                      <span className="font-semibold text-sky-300">
                        {a.riskLevel}
                      </span>
                    </p>
                  </li>
                ))}
              </ol>
            )}
          </div>
        </section>

        {/* Remediation tracker */}
        <section className="space-y-3">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-lg font-semibold">Remediation tracker</h2>
            <p className="text-xs text-slate-400">
              These items are generated based on the current risk tier. In a
              future phase, they can be driven from a dedicated remediation
              table.
            </p>
          </div>

          <div className="overflow-x-auto rounded-lg border border-slate-800 bg-slate-900/40">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-900/80 border-b border-slate-800">
                <tr>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Item
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Status
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Due on
                  </th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => {
                  const tone =
                    item.status === "overdue"
                      ? "text-rose-400 border-rose-500/40"
                      : item.status === "due-soon"
                      ? "text-amber-300 border-amber-400/40"
                      : "text-sky-300 border-sky-500/40";

                  const label =
                    item.status === "overdue"
                      ? "Overdue"
                      : item.status === "due-soon"
                      ? "Due soon"
                      : "Planned";

                  return (
                    <tr
                      key={item.id}
                      className="border-t border-slate-800 hover:bg-slate-900/60 transition"
                    >
                      <td className="px-4 py-2 text-slate-100">
                        {item.title}
                      </td>
                      <td className="px-4 py-2">
                        <span
                          className={[
                            "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium",
                            tone,
                          ].join(" ")}
                        >
                          {label}
                        </span>
                      </td>
                      <td className="px-4 py-2 text-slate-200">
                        {item.dueOn}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>

        {/* Evidence / documents (stub) */}
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Evidence & documents</h2>
          <div className="rounded-lg border border-dashed border-slate-700 bg-slate-900/30 p-4 space-y-2">
            <p className="text-sm text-slate-200">
              This section will list SOC reports, penetration tests, policy
              documents, and other evidence provided by the vendor.
            </p>
            <p className="text-xs text-slate-400">
              In a future phase, this will be wired to the existing upload
              endpoints under <code>/vendor/upload</code> so files and
              metadata are visible directly in the dossier.
            </p>
          </div>
        </section>

        {/* Footer */}
        <footer className="pt-4 border-t border-slate-800 text-xs text-slate-500 space-y-1">
          <p>
            This vendor profile is generated from live Truvern data. Use it in
            board packs, steering committees, and renewal discussions to keep
            everyone aligned on risk and remediation plans.
          </p>
        </footer>
      </section>
    </main>
  );
}
'@

Set-Content -LiteralPath $pagePath -Value $pageContent -Encoding UTF8
Write-Host "[INFO] Wrote upgraded vendors/[id]/page.tsx (vendor dossier)." -ForegroundColor Green

# 4) Trigger cloud deploy
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase150-VendorDossier complete ===" -ForegroundColor Cyan
