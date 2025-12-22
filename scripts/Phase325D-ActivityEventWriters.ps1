# scripts/Phase325D-ActivityEventWriters.ps1
# Phase 325D — Activity event writers (helper + patch reminders)
[CmdletBinding()]
param([string]$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern")

$ErrorActionPreference = "Stop"

function Assert-NotSystem32 {
  $cwd = (Get-Location).Path
  if ($cwd -match '\\WINDOWS\\system32$' -or $cwd -match '\\Windows\\System32$') {
    throw "Refusing to run from $cwd. Change directory to your project root first."
  }
}
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function New-LogFile([string]$Root) {
  $logs = Join-Path $Root "logs"; Ensure-Dir $logs
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  Join-Path $logs "Phase325D-ActivityEventWriters-$stamp.log"
}
function Write-Log([string]$Msg, [string]$Level="INFO") {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts][$Level] $Msg"
  Write-Host $line
  Add-Content -Path $script:LogFile -Value $line
}
function Write-File([string]$Path, [string]$Content) {
  Ensure-Dir (Split-Path $Path -Parent)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  Write-Log "Wrote file: $Path"
}

try {
  Assert-NotSystem32
  if (-not (Test-Path $ProjectRoot)) { throw "ProjectRoot not found: $ProjectRoot" }
  Set-Location $ProjectRoot
  $script:LogFile = New-LogFile $ProjectRoot
  Write-Log "Phase 325D starting" "START"

  $helperPath = Join-Path $ProjectRoot "lib\activity-log.ts"
  $helper = @'
import prisma from "@/lib/prisma";

type CreateEventInput = {
  organizationId: number;
  vendorId?: number | null;
  type: string;
  title: string;
  description?: string | null;
  metadata?: any;
  actor?: {
    userId?: number | null;
    name?: string | null;
    email?: string | null;
  } | null;
};

export async function logActivityEvent(input: CreateEventInput) {
  const orgId = Number(input.organizationId);
  if (!Number.isFinite(orgId) || orgId <= 0) return;

  const vendorId = input.vendorId == null ? null : Number(input.vendorId);

  const type = String(input.type || "").trim();
  const title = String(input.title || "").trim();
  if (!type || !title) return;

  try {
    await prisma.activityEvent.create({
      data: {
        organizationId: orgId,
        vendorId: vendorId && Number.isFinite(vendorId) ? vendorId : null,
        type,
        title,
        description: input.description ?? null,
        metadata: input.metadata ?? undefined,
        actorUserId: input.actor?.userId != null ? String(input.actor.userId) : null,
        actorName: input.actor?.name ?? null,
        actorEmail: input.actor?.email ?? null,
      },
    });
  } catch (e) {
    console.error("logActivityEvent failed:", e);
  }
}
'@

  Write-File -Path $helperPath -Content $helper

  Write-Log "Next: wire logActivityEvent into endpoints:" "INFO"
  Write-Log " - app/api/board-report/export/route.ts (log BOARD_REPORT_EXPORTED)" "INFO"
  Write-Log " - Issue update API route (log ISSUE_UPDATED / ISSUE_ACCEPTED_RISK)" "INFO"
  Write-Log " - Evidence create/upload API route (log EVIDENCE_UPLOADED)" "INFO"

  Write-Log "Phase 325D helper complete ✅" "DONE"
  Write-Host ""
  Write-Host "✅ Phase 325D helper created: lib/activity-log.ts"
  Write-Host "Now patch your evidence + issues + board export endpoints to call logActivityEvent()."
  Write-Host "Log: $script:LogFile"
}
catch {
  Write-Host ""
  Write-Host "❌ Phase 325D failed. See log: $script:LogFile"
  throw
}
