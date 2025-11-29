$ErrorActionPreference = "Stop"

Write-Host "=== Phase152: Vendor Evidence Workspace ===" -ForegroundColor Cyan

# Always work from project root
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root
Write-Host "[INFO] Working in $root" -ForegroundColor DarkCyan

# ============================================================================
# 1. Ensure folder structure: app/vendor/upload
# ============================================================================

$vendorDir  = Join-Path $root "app\vendor"
$uploadDir  = Join-Path $vendorDir "upload"
$uploadPage = Join-Path $uploadDir "page.tsx"

if (-not (Test-Path $vendorDir)) {
    New-Item -ItemType Directory -Path $vendorDir | Out-Null
    Write-Host "[INFO] Created app/vendor"
} else {
    Write-Host "[INFO] app/vendor already exists"
}

if (-not (Test-Path $uploadDir)) {
    New-Item -ItemType Directory -Path $uploadDir | Out-Null
    Write-Host "[INFO] Created app/vendor/upload"
} else {
    Write-Host "[INFO] app/vendor/upload already exists"
}

if (Test-Path $uploadPage) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$uploadPage.bak-$stamp"
    Copy-Item $uploadPage $backupPath
    Write-Host "[INFO] Backed up existing page.tsx to $backupPath"
}

# ============================================================================
# 2. Write Next.js /vendor/upload workspace page (client component)
#    NOTE: Everything below is plain ASCII (no smart quotes / dashes)
# ============================================================================

$tsx = @'
"use client";

import { useSearchParams } from "next/navigation";
import { useState } from "react";
import Link from "next/link";

type Status = "idle" | "uploading" | "success" | "error";

export default function VendorEvidenceUploadPage() {
  const searchParams = useSearchParams();
  const vendorId = searchParams.get("vendorId") || "";

  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState<string>("");

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();

    const form = e.currentTarget;
    const data = new FormData(form);

    if (!vendorId) {
      setStatus("error");
      setMessage("Vendor ID is missing. Open this screen from a vendor dossier.");
      return;
    }

    data.set("vendorId", vendorId);

    setStatus("uploading");
    setMessage("");

    try {
      const res = await fetch("/api/evidence/upload", {
        method: "POST",
        body: data,
      });

      if (!res.ok) {
        throw new Error("Upload failed with status " + res.status);
      }

      setStatus("success");
      setMessage("Evidence uploaded. You can upload another file or return to the dossier.");
      form.reset();
    } catch (err: any) {
      console.error(err);
      setStatus("error");
      setMessage(err?.message || "Upload failed. Please try again.");
    }
  }

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-3xl mx-auto px-4 py-10 space-y-8">
        <header className="space-y-2">
          <p className="text-xs uppercase tracking-widest text-sky-400">
            Vendor evidence workspace
          </p>
          <h1 className="text-2xl md:text-3xl font-semibold">
            Upload evidence for this vendor
          </h1>
          <p className="text-sm text-slate-300 max-w-2xl">
            Use this page to upload SOC reports, penetration tests, policy documents,
            and other supporting evidence for the selected vendor.
          </p>
        </header>

        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5 space-y-5">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-xs text-slate-400 uppercase tracking-wide">
                Vendor context
              </p>
              <p className="text-sm text-slate-200">
                Vendor ID:{" "}
                <span className="font-mono text-sky-300">
                  {vendorId || "Not provided"}
                </span>
              </p>
              {!vendorId && (
                <p className="text-xs text-amber-300 mt-1">
                  Tip: open this screen from the "Upload evidence" button on a vendor dossier
                  so the vendor ID is passed automatically.
                </p>
              )}
            </div>
            <div className="flex flex-wrap gap-2">
              <Link
                href={vendorId ? `/vendors/${vendorId}` : "/vendors"}
                className="inline-flex items-center rounded-md border border-slate-700 px-3 py-1.5 text-xs font-semibold text-slate-100 hover:border-sky-500 transition"
              >
                Back to vendor dossier
              </Link>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4 border-t border-slate-800 pt-4">
            <div className="space-y-1">
              <label className="text-xs font-medium text-slate-300 uppercase tracking-wide">
                Evidence type
              </label>
              <select
                name="evidenceType"
                required
                defaultValue=""
                className="w-full rounded-md border border-slate-700 bg-slate-950/80 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-1 focus:ring-sky-500"
              >
                <option value="" disabled>
                  Select an evidence category
                </option>
                <option value="soc2">SOC 2 or independent assurance</option>
                <option value="pentest">Penetration test report</option>
                <option value="policy">Information security policy set</option>
                <option value="bcp-dr">Business continuity / DR plan</option>
                <option value="privacy">Data protection / privacy documentation</option>
                <option value="other">Other security evidence</option>
              </select>
              <p className="text-[11px] text-slate-400">
                This helps Truvern group evidence for board reporting and reassessment.
              </p>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-slate-300 uppercase tracking-wide">
                Short description
              </label>
              <input
                name="description"
                type="text"
                placeholder="Example: SOC 2 Type II, period ending Oct 2025"
                className="w-full rounded-md border border-slate-700 bg-slate-950/80 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
              />
            </div>

            <div className="space-y-2">
              <label className="text-xs font-medium text-slate-300 uppercase tracking-wide">
                Evidence file
              </label>
              <input
                name="file"
                type="file"
                required
                className="w-full rounded-md border border-slate-700 bg-slate-950/80 px-3 py-2 text-sm text-slate-100"
              />
              <p className="text-[11px] text-slate-400">
                Common formats: PDF, DOCX, XLSX, CSV, TXT.
              </p>
            </div>

            {status !== "idle" && (
              <div className="rounded-md border border-slate-700 bg-slate-900/80 px-3 py-2 text-xs">
                {status === "uploading" && (
                  <p className="text-sky-300">Uploading evidence. Please keep this tab open.</p>
                )}
                {status === "success" && (
                  <p className="text-emerald-300">{message}</p>
                )}
                {status === "error" && (
                  <p className="text-rose-300">{message}</p>
                )}
              </div>
            )}

            <div className="flex items-center justify-between gap-3">
              <button
                type="submit"
                disabled={status === "uploading"}
                className="inline-flex items-center rounded-md bg-sky-500 px-4 py-2 text-sm font-semibold text-slate-950 shadow-sm hover:bg-sky-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
              >
                {status === "uploading" ? "Uploading..." : "Upload evidence"}
              </button>
              <p className="text-[11px] text-slate-500">
                Files are sent to the API at /api/evidence/upload.
              </p>
            </div>
          </form>
        </div>

        <footer className="pt-2 border-t border-slate-800 text-[11px] text-slate-500">
          <p>
            Use this workspace to keep evidence current for assessments, board reporting,
            and renewal decisions.
          </p>
        </footer>
      </section>
    </main>
  );
}
'@

Set-Content -LiteralPath $uploadPage -Value $tsx -Encoding UTF8
Write-Host "[OK] Wrote app/vendor/upload/page.tsx" -ForegroundColor Green

# ============================================================================
# 3. Auto-run cloud build + deploy (Phase132g if available)
# ============================================================================

$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"

if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1 (cloud build + deploy)..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Phase132g-CloudDeploy.ps1 not found. Running 'vercel --prod --yes' directly..." -ForegroundColor Yellow
    vercel --prod --yes
}

Write-Host "=== Phase152: Vendor Evidence Workspace complete ===" -ForegroundColor Cyan
