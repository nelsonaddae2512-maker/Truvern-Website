# ==============================================
# Phase184 - Evidence Upload API + UI (Vercel Blob)
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$scriptsDir  = "$projectRoot\scripts"
$logDir      = "$scriptsDir\logs"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase184-evidence-upload-$timestamp.log"

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date), $Message)
}

Write-Log "===== Phase184: Evidence Upload API + UI (Vercel Blob) START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Ensure @vercel/blob is installed
# ------------------------------------------------------------------
$packageJsonPath = "$projectRoot\package.json"
if (-not (Test-Path $packageJsonPath)) {
    Write-Log "ERROR: package.json not found at $packageJsonPath" "Red"
    exit 1
}

$packageJsonText = Get-Content $packageJsonPath -Raw
if ($packageJsonText -notmatch '"@vercel/blob"') {
    Write-Log "Installing @vercel/blob via npm..." "Yellow"
    npm install @vercel/blob --save | Out-Null
    Write-Log "@vercel/blob installed (or already satisfied)." "Green"
} else {
    Write-Log "@vercel/blob already present in package.json." "Green"
}

# ------------------------------------------------------------------
# Create API route: app/api/evidence/upload/route.ts
# ------------------------------------------------------------------
$apiDir = "$projectRoot\app\api\evidence\upload"
if (-not (Test-Path $apiDir)) {
    Write-Log "Creating API directory: $apiDir" "Green"
    New-Item -Path $apiDir -ItemType Directory -Force | Out-Null
}

$apiRoutePath = "$apiDir\route.ts"
Write-Log "Writing evidence upload API route: $apiRoutePath" "Green"

@'
import { NextRequest, NextResponse } from "next/server";
import { put } from "@vercel/blob";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();

    const vendorIdRaw = formData.get("vendorId");
    const titleRaw = formData.get("title");
    const descriptionRaw = formData.get("description");
    const file = formData.get("file");

    if (!vendorIdRaw) {
      return NextResponse.json(
        { error: "Missing vendorId" },
        { status: 400 }
      );
    }

    const vendorId = Number(vendorIdRaw);
    if (!Number.isInteger(vendorId)) {
      return NextResponse.json(
        { error: "Invalid vendorId" },
        { status: 400 }
      );
    }

    if (!(file instanceof File)) {
      return NextResponse.json(
        { error: "No file uploaded" },
        { status: 400 }
      );
    }

    const title =
      typeof titleRaw === "string" && titleRaw.trim().length > 0
        ? titleRaw.trim()
        : `Evidence for vendor ${vendorId}`;

    const description =
      typeof descriptionRaw === "string" ? descriptionRaw.trim() : "";

    // Store file in Vercel Blob
    const blob = await put(
      `evidence/vendor-${vendorId}/${Date.now()}-${file.name}`,
      file,
      {
        access: "public",
      }
    );

    // Persist record in database
    const evidence = await prisma.evidence.create({
      data: {
        vendorId,
        title,
        description,
        fileUrl: blob.url,
        fileName: file.name,
      },
    });

    return NextResponse.json({ ok: true, evidence });
  } catch (error) {
    console.error("Evidence upload error:", error);
    return NextResponse.json(
      { error: "Failed to upload evidence" },
      { status: 500 }
    );
  }
}
'@ | Set-Content -Path $apiRoutePath -Encoding UTF8

Write-Log "Evidence upload API route created." "Green"

# ------------------------------------------------------------------
# Create upload UI page: app/vendors/[id]/evidence/upload/page.tsx
# ------------------------------------------------------------------
$uploadPageDir = "$projectRoot\app\vendors\[id]\evidence\upload"
if (-not (Test-Path $uploadPageDir)) {
    Write-Log "Creating upload page directory: $uploadPageDir" "Green"
    New-Item -Path $uploadPageDir -ItemType Directory -Force | Out-Null
}

$uploadPagePath = "$uploadPageDir\page.tsx"
Write-Log "Writing evidence upload page: $uploadPagePath" "Green"

@'
"use client";

import React, { useState } from "react";
import { useParams, useRouter } from "next/navigation";

export default function EvidenceUploadPage() {
  const params = useParams();
  const router = useRouter();
  const vendorId = Number(params?.id);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!vendorId || Number.isNaN(vendorId)) {
      setError("Missing or invalid vendor id.");
      return;
    }

    if (!file) {
      setError("Please choose a file to upload.");
      return;
    }

    setIsUploading(true);
    try {
      const formData = new FormData();
      formData.append("vendorId", String(vendorId));
      formData.append("title", title);
      formData.append("description", description);
      formData.append("file", file);

      const res = await fetch("/api/evidence/upload", {
        method: "POST",
        body: formData,
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error || "Upload failed");
      }

      setSuccess("Evidence uploaded successfully.");
      // After a short delay, navigate back to the vendor evidence list
      setTimeout(() => {
        router.push(`/vendors/${vendorId}/evidence`);
      }, 1000);
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Upload failed.");
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto py-10 px-4">
      <h1 className="text-2xl font-semibold mb-4">Upload evidence</h1>
      <p className="text-sm text-slate-400 mb-6">
        Attach SOC2 reports, ISO certificates, penetration tests, insurance,
        or other proof for this vendor.
      </p>

      <form
        onSubmit={handleSubmit}
        className="space-y-4 border border-slate-800 rounded-xl p-6 bg-slate-950/40"
      >
        <div>
          <label className="block text-sm font-medium mb-1">
            Title
          </label>
          <input
            type="text"
            className="w-full rounded-md bg-slate-900 border border-slate-700 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-truvern-accent"
            placeholder="SOC 2 Type II (2025)"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">
            Description
          </label>
          <textarea
            className="w-full rounded-md bg-slate-900 border border-slate-700 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-truvern-accent min-h-[80px]"
            placeholder="Scope, period, key notes, etc."
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">
            Evidence file
          </label>
          <input
            type="file"
            className="block w-full text-sm text-slate-300 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-truvern-accent/10 file:text-truvern-accent hover:file:bg-truvern-accent/20"
            onChange={(e) => {
              const f = e.target.files?.[0] ?? null;
              setFile(f);
            }}
          />
          {file && (
            <p className="mt-1 text-xs text-slate-400">
              Selected: <span className="font-medium">{file.name}</span>{" "}
              ({Math.round(file.size / 1024)} KB)
            </p>
          )}
        </div>

        {error && (
          <p className="text-sm text-red-400 bg-red-950/40 border border-red-900 rounded-md px-3 py-2">
            {error}
          </p>
        )}

        {success && (
          <p className="text-sm text-emerald-400 bg-emerald-950/40 border border-emerald-900 rounded-md px-3 py-2">
            {success}
          </p>
        )}

        <div className="flex items-center justify-between pt-2">
          <button
            type="button"
            className="text-sm text-slate-400 hover:text-slate-200"
            onClick={() => router.back()}
          >
            ← Back
          </button>

          <button
            type="submit"
            disabled={isUploading}
            className="btn-primary px-4 py-2 text-sm disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {isUploading ? "Uploading…" : "Upload evidence"}
          </button>
        </div>
      </form>
    </div>
  );
}
'@ | Set-Content -Path $uploadPagePath -Encoding UTF8

Write-Log "Evidence upload page created." "Green"

Write-Log "===== Phase184: Evidence Upload API + UI COMPLETE =====" "Yellow"
