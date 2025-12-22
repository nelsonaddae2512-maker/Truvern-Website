# Phase325G-OrgGuardAndRouteProtection.ps1
# Adds Clerk-protected routes + org-required guard + /select-org page + server helper
# PowerShell 5.1 compatible, ASCII-only, safe paths (no wildcards)

$ErrorActionPreference = "Stop"

function Stamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Log([string]$m) {
  $line = "[{0}] {1}" -f (Stamp), $m
  Write-Host $line
  Add-Content -Path $script:LogFile -Value $line
}
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

# --- Ensure running from project root (not system32) ---
if ($PWD.Path -match "\\Windows\\System32\\?$") { throw "Refusing to run from system32." }

$root = $PWD.Path
if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) {
  throw "Run this from the truvern project root (package.json not found). Current: $root"
}

# --- Logging setup ---
$logsDir = Join-Path $root "logs"
Ensure-Dir $logsDir
$script:LogFile = Join-Path $logsDir "phase325g-org-guard.log"

Log "=== Phase 325G: Org Guard + Route Protection ==="

# --- Backups ---
$backupRoot = Join-Path $root ("backups\Phase325G-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Ensure-Dir $backupRoot
Log ("Backup folder: {0}" -f $backupRoot)

# Files we will write/patch
$middlewareFile = Join-Path $root "middleware.ts"
$selectOrgPage  = Join-Path $root "app\select-org\page.tsx"
$orgGuardFile   = Join-Path $root "lib\org-guard.ts"

Backup-File $middlewareFile $backupRoot
Backup-File $selectOrgPage  $backupRoot
Backup-File $orgGuardFile   $backupRoot

# -------------------------------------------------------------------
# 1) Write lib/org-guard.ts (server helper)
# -------------------------------------------------------------------
$orgGuardContent = @"
import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";

/**
 * Require a signed-in user AND an active organization context.
 * - If not signed in -> redirect to /sign-in
 * - If signed in but no org selected -> redirect to /select-org
 */
export function requireOrgContext() {
  const a: any = auth();
  const userId = a?.userId ?? null;
  const orgId = a?.orgId ?? null;

  if (!userId) redirect("/sign-in");
  if (!orgId) redirect("/select-org");

  return { userId, orgId, orgRole: a?.orgRole ?? null };
}

/**
 * Require org context + admin-ish role.
 * Clerk org roles often look like: "org:admin", "org:member"
 * Adjust if your instance uses different roles.
 */
export function requireOrgAdmin() {
  const ctx = requireOrgContext();
  const role = String(ctx.orgRole ?? "");

  if (role && role !== "org:admin") {
    // If you later add a nicer page, redirect there.
    redirect("/select-org");
  }

  return ctx;
}
"@

Write-Text $orgGuardFile $orgGuardContent
Log ("Wrote: {0}" -f $orgGuardFile)

# -------------------------------------------------------------------
# 2) Write /app/select-org/page.tsx
# -------------------------------------------------------------------
$selectOrgContent = @"
import Link from "next/link";
import { SignedIn, SignedOut, OrganizationSwitcher } from "@clerk/nextjs";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default function SelectOrgPage() {
  return (
    <main className="min-h-[70vh]">
      <div className="mx-auto max-w-2xl px-6 py-12">
        <div className="rounded-2xl border border-white/10 bg-slate-950/40 p-6 shadow-sm">
          <h1 className="text-2xl font-semibold text-slate-50">Select an organization</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Truvern is organization-scoped. Choose the org you want to operate in.
          </p>

          <div className="mt-6">
            <SignedIn>
              <div className="rounded-xl border border-white/10 bg-black/20 p-4">
                <OrganizationSwitcher
                  appearance={{
                    elements: {
                      rootBox: "w-full",
                      organizationSwitcherTrigger:
                        "w-full justify-between rounded-lg border border-white/10 bg-slate-900/40 px-3 py-2 text-slate-50 hover:bg-slate-900/60",
                    },
                  }}
                />
              </div>

              <div className="mt-6 flex flex-wrap gap-3">
                <Link
                  href="/vendors"
                  className="rounded-lg bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-white"
                >
                  Continue to Vendors
                </Link>
                <Link
                  href="/"
                  className="rounded-lg border border-white/10 bg-slate-900/30 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-slate-900/50"
                >
                  Back to Home
                </Link>
              </div>
            </SignedIn>

            <SignedOut>
              <div className="mt-6 rounded-xl border border-white/10 bg-black/20 p-4">
                <p className="text-sm text-slate-200/70">
                  You are signed out. Please sign in first.
                </p>
                <div className="mt-4">
                  <Link
                    href="/sign-in"
                    className="rounded-lg bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-white"
                  >
                    Go to Sign In
                  </Link>
                </div>
              </div>
            </SignedOut>
          </div>
        </div>
      </div>
    </main>
  );
}
"@

Write-Text $selectOrgPage $selectOrgContent
Log ("Wrote: {0}" -f $selectOrgPage)

# -------------------------------------------------------------------
# 3) Patch/Create middleware.ts
#    - Protect routes AND require org selection
# -------------------------------------------------------------------
$middlewareContent = @"
import { NextResponse } from "next/server";
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

/**
 * Protected app routes. Adjust as needed.
 * NOTE: keep public routes (/, /pricing, /trust-network) out of this list if desired.
 */
const isProtectedRoute = createRouteMatcher([
  "/vendors(.*)",
  "/board-report(.*)",
  "/issues(.*)",
  "/assessment(.*)",
  "/vendor-portal(.*)",
  "/settings(.*)",
  "/admin(.*)",
]);

export default clerkMiddleware((auth, req) => {
  if (!isProtectedRoute(req)) return;

  const a: any = auth();

  // Not signed in -> Clerk-managed redirect to sign-in
  if (!a?.userId) {
    // returnBackUrl preserves original destination
    return a.redirectToSignIn({ returnBackUrl: req.url });
  }

  // Signed in but no org context -> choose org
  if (!a?.orgId) {
    const url = new URL("/select-org", req.url);
    return NextResponse.redirect(url);
  }

  // Otherwise allow request through
  return;
});

export const config = {
  matcher: [
    // Run middleware on all routes except Next internals and static files
    "/((?!_next|.*\\..*).*)",
    "/(api|trpc)(.*)",
  ],
};
"@

Write-Text $middlewareFile $middlewareContent
Log ("Wrote: {0}" -f $middlewareFile)

# -------------------------------------------------------------------
# 4) Summary
# -------------------------------------------------------------------
Log "Done."
Log "Created/updated:"
Log (" - {0}" -f $middlewareFile)
Log (" - {0}" -f $selectOrgPage)
Log (" - {0}" -f $orgGuardFile)
Log "Next: run build to validate."
Log "=== Phase 325G complete ==="
