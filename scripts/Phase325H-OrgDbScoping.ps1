# Phase325H-OrgDbScoping.ps1
# Enforce org scoping in Prisma queries by mapping Clerk orgId -> DB Organization row
# PS 5.1 compatible, ASCII-only, no wildcards in Test-Path

$ErrorActionPreference = "Stop"

function Stamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Ensure-Dir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
function Read-Text([string]$p) { if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p) } return "" }
function Write-Text([string]$p, [string]$c) {
  $dir = Split-Path -Parent $p
  if ($dir) { Ensure-Dir $dir }
  [IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
}
function Backup-File([string]$p, [string]$backupRoot) {
  if (-not (Test-Path -LiteralPath $p)) { return }
  $rel = $p.Substring($PWD.Path.Length).TrimStart('\')
  $dest = Join-Path $backupRoot $rel
  Ensure-Dir (Split-Path -Parent $dest)
  Copy-Item -LiteralPath $p -Destination $dest -Force
}
function Log([string]$m) {
  $line = "[{0}] {1}" -f (Stamp), $m
  Write-Host $line
  Add-Content -Path $script:LogFile -Value $line
}

# Safety
if ($PWD.Path -match "\\Windows\\System32\\?$") { throw "Refusing to run from system32." }
$root = $PWD.Path
if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) {
  throw "Run from truvern project root (package.json not found). Current: $root"
}

# Logging
$logsDir = Join-Path $root "logs"
Ensure-Dir $logsDir
$script:LogFile = Join-Path $logsDir "phase325h-org-db-scoping.log"

Log "=== Phase 325H: Org DB scoping ==="

# Backups
$backupRoot = Join-Path $root ("backups\Phase325H-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Ensure-Dir $backupRoot
Log ("Backup folder: {0}" -f $backupRoot)

# Targets
$schemaFile  = Join-Path $root "prisma\schema.prisma"
$orgDbFile   = Join-Path $root "lib\org-db.ts"

# Candidate pages/APIs to scope (patch if present)
$targets = @(
  "app\vendors\page.tsx",
  "app\vendors\[id]\page.tsx",
  "app\vendors\[id]\findings\page.tsx",
  "app\issues\page.tsx",
  "app\board-report\page.tsx",
  "app\api\board-report\export\route.ts"
) | ForEach-Object { Join-Path $root $_ }

Backup-File $schemaFile $backupRoot
Backup-File $orgDbFile  $backupRoot
foreach ($t in $targets) { Backup-File $t $backupRoot }

# -------------------------------------------------------------------
# 1) Ensure Organization has clerkOrgId field (nullable unique)
# -------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $schemaFile)) {
  Log ("WARN: prisma schema not found at {0}. Skipping schema patch." -f $schemaFile)
} else {
  $schema = Read-Text $schemaFile

  $hasOrgModel = $schema -match "model\s+Organization\s*\{"
  if (-not $hasOrgModel) {
    Log "WARN: No model Organization found in schema.prisma. Skipping clerkOrgId field add."
  } else {
    $alreadyHas = $schema -match "clerkOrgId\s+String"
    if ($alreadyHas) {
      Log "OK: Organization already has clerkOrgId field."
    } else {
      Log "Patching schema.prisma: adding Organization.clerkOrgId String? @unique"

      # Insert right after opening brace of Organization model
      $patched = $schema -replace "(model\s+Organization\s*\{\s*\r?\n)", ('$1  clerkOrgId      String?   @unique' + "`r`n")

      if ($patched -eq $schema) {
        Log "WARN: Could not apply schema patch (pattern mismatch). Please add clerkOrgId manually."
      } else {
        Write-Text $schemaFile $patched
        Log "Wrote updated prisma/schema.prisma"
        Log "NOTE: Run: npx prisma migrate dev --name add_clerk_org_id"
      }
    }
  }
}

# -------------------------------------------------------------------
# 2) Write lib/org-db.ts (Clerk orgId -> DB org row)
# -------------------------------------------------------------------
$orgDbContent = @"
import prisma from "@/lib/prisma";
import { requireOrgContext } from "@/lib/org-guard";

/**
 * Resolve the database Organization row for the active Clerk org.
 * Assumes Organization has a nullable unique field: clerkOrgId String? @unique
 *
 * Behavior:
 * - If no Clerk org selected -> requireOrgContext() redirects to /select-org
 * - If DB org row missing -> throws with a clear message (no silent auto-provision)
 */
export async function requireDbOrganization() {
  const { orgId: clerkOrgId } = requireOrgContext();

  const org = await prisma.organization.findFirst({
    where: { clerkOrgId },
    select: { id: true, name: true, clerkOrgId: true },
  });

  if (!org) {
    // This is intentional: prevents accidental cross-tenant access and forces explicit provisioning.
    throw new Error(
      "No DB Organization row found for Clerk orgId=" +
        clerkOrgId +
        ". Create/provision an Organization with clerkOrgId set to this value."
    );
  }

  return org; // { id, name, clerkOrgId }
}
"@

Write-Text $orgDbFile $orgDbContent
Log ("Wrote: {0}" -f $orgDbFile)

# -------------------------------------------------------------------
# 3) Patch pages/APIs: scope by organizationId (best-effort)
# -------------------------------------------------------------------
function Ensure-Import([string]$content, [string]$importLine) {
  if ($content -match [Regex]::Escape($importLine)) { return $content }
  # Insert after first import line
  $lines = $content -split "`r?`n"
  if ($lines.Length -lt 1) { return $content }
  $inserted = $false
  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Length; $i++) {
    $out.Add($lines[$i])
    if (-not $inserted -and $lines[$i].Trim().StartsWith("import ")) {
      # after the last contiguous import block
      $j = $i + 1
      while ($j -lt $lines.Length -and $lines[$j].Trim().StartsWith("import ")) {
        $out.Add($lines[$j])
        $i = $j
        $j++
      }
      $out.Add($importLine)
      $inserted = $true
    }
  }
  if (-not $inserted) {
    return ($importLine + "`r`n" + $content)
  }
  return ($out -join "`r`n")
}

function Insert-OrgResolve([string]$content) {
  # If already present, do nothing
  if ($content -match "requireDbOrganization\(") { return $content }

  # Insert a simple org resolution near top-level of server component / route handler file
  # We put it after runtime/dynamic exports if present, otherwise after imports.
  $marker = "export const revalidate"
  if ($content -match [Regex]::Escape($marker)) {
    $idx = $content.IndexOf($marker)
    $lineEnd = $content.IndexOf("`n", $idx)
    if ($lineEnd -lt 0) { $lineEnd = $idx }
    $prefix = $content.Substring(0, $lineEnd + 1)
    $suffix = $content.Substring($lineEnd + 1)
    return $prefix + "`r`n" + "const __dbOrgPromise = requireDbOrganization();" + "`r`n" + $suffix
  }

  # Fallback: after imports
  $parts = $content -split "(\r?\n\r?\n)"
  if ($parts.Length -gt 1) {
    # after first blank line block (usually after imports)
    return $parts[0] + "`r`n`r`n" + "const __dbOrgPromise = requireDbOrganization();" + "`r`n" + ($parts[2..($parts.Length-1)] -join "")
  }

  return "const __dbOrgPromise = requireDbOrganization();`r`n" + $content
}

function Patch-WhereOrgId([string]$content, [string]$modelCall) {
  # Best-effort: add "where: { organizationId: org.id }" if the call has no where block.
  # Assumes the page uses prisma.<model>.findMany/findFirst/findUnique with an options object.

  # Ensure we have org resolved inside function scope:
  # In server components, we can do: const org = await __dbOrgPromise;
  if ($content -notmatch "await __dbOrgPromise") {
    # try to insert inside default export function body by adding line after first "{"
    $rx = "export\s+default\s+async\s+function[^{]*\{"
    $m = [Regex]::Match($content, $rx)
    if ($m.Success) {
      $pos = $m.Index + $m.Length
      $content = $content.Substring(0,$pos) + "`r`n  const org = await __dbOrgPromise;`r`n" + $content.Substring($pos)
    } else {
      # route handlers: look for "export async function GET" / "POST"
      $rx2 = "export\s+async\s+function\s+(GET|POST|PUT|DELETE)[^{]*\{"
      $m2 = [Regex]::Match($content, $rx2)
      if ($m2.Success) {
        $pos2 = $m2.Index + $m2.Length
        $content = $content.Substring(0,$pos2) + "`r`n  const org = await __dbOrgPromise;`r`n" + $content.Substring($pos2)
      }
    }
  }

  # Patch findMany({...}) calls missing where
  $pattern = [Regex]::Escape($modelCall) + "\s*\(\s*\{"
  if ($content -match $pattern) {
    # If there's already "organizationId" nearby, skip
    if ($content -match "organizationId\s*:") { return $content }

    # Insert where at first options object opening for that model call
    $content = [Regex]::Replace(
      $content,
      $pattern,
      ($modelCall + "({`r`n      where: { organizationId: org.id },"),
      1
    )
  }

  return $content
}

foreach ($file in $targets) {
  if (-not (Test-Path -LiteralPath $file)) {
    Log ("Skip (missing): {0}" -f $file)
    continue
  }

  $c = Read-Text $file
  $orig = $c

  # Add import
  $c = Ensure-Import $c 'import { requireDbOrganization } from "@/lib/org-db";'

  # Add org resolver promise (top-level)
  $c = Insert-OrgResolve $c

  # Apply best-effort org scoping based on common model calls in these files
  # NOTE: These patches are conservative; they only add where if no organizationId exists in file.
  if ($file -match "\\vendors\\page\.tsx$") {
    $c = Patch-WhereOrgId $c "prisma.vendor.findMany"
  }
  elseif ($file -match "\\issues\\page\.tsx$") {
    $c = Patch-WhereOrgId $c "prisma.issue.findMany"
  }
  elseif ($file -match "\\board-report\\page\.tsx$") {
    $c = Patch-WhereOrgId $c "prisma.vendor.findMany"
    $c = Patch-WhereOrgId $c "prisma.issue.findMany"
  }
  elseif ($file -match "\\api\\board-report\\export\\route\.ts$") {
    $c = Patch-WhereOrgId $c "prisma.vendor.findMany"
    $c = Patch-WhereOrgId $c "prisma.issue.findMany"
  }
  elseif ($file -match "\\vendors\\\[id\]\\page\.tsx$") {
    # vendor detail usually uses findUnique; if it already scopes by id only, we still need org check.
    # We won't rewrite findUnique; we rely on the injected `const org = await __dbOrgPromise;`
    # and a follow-up Phase to update where: { id, organizationId }.
  }
  elseif ($file -match "\\vendors\\\[id\]\\findings\\page\.tsx$") {
    # similar conservative approach
  }

  if ($c -ne $orig) {
    Write-Text $file $c
    Log ("Patched: {0}" -f $file)
  } else {
    Log ("No change: {0}" -f $file)
  }
}

Log "NOTE: If you added clerkOrgId to schema, run Prisma migrate:"
Log "  npx prisma migrate dev --name add_clerk_org_id"
Log "Then rebuild:"
Log "  npm run build"
Log "=== Phase 325H complete ==="
