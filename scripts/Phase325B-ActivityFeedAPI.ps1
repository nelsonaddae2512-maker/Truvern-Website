# scripts/Phase325B-ActivityFeedAPI.ps1
# Phase 325B — Activity Feed API (org/vendor scopes + cursor pagination)
[CmdletBinding()]
param(
  [string]$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
)

$ErrorActionPreference = "Stop"

function Assert-NotSystem32 {
  $cwd = (Get-Location).Path
  if ($cwd -match '\\WINDOWS\\system32$' -or $cwd -match '\\Windows\\System32$') {
    throw "Refusing to run from $cwd. Change directory to your project root first."
  }
}

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function New-LogFile([string]$Root) {
  $logs = Join-Path $Root "logs"
  Ensure-Dir $logs
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  Join-Path $logs "Phase325B-ActivityFeedAPI-$stamp.log"
}

function Write-Log([string]$Msg, [string]$Level="INFO") {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts][$Level] $Msg"
  Write-Host $line
  Add-Content -Path $script:LogFile -Value $line
}

function Write-TextFile([string]$Path, [string]$Content) {
  Ensure-Dir (Split-Path $Path -Parent)
  # TS/JS files are fine with UTF8 (BOM ok); using .NET for consistency
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  Write-Log "Wrote file: $Path"
}

try {
  Assert-NotSystem32
  if (-not (Test-Path $ProjectRoot)) { throw "ProjectRoot not found: $ProjectRoot" }
  Set-Location $ProjectRoot

  $script:LogFile = New-LogFile $ProjectRoot
  Write-Log "Phase 325B starting" "START"
  Write-Log "ProjectRoot: $ProjectRoot"

  $libPath = Join-Path $ProjectRoot "lib\activity-feed.ts"
  $apiPath = Join-Path $ProjectRoot "app\api\activity\route.ts"

  $libContent = @'
import prisma from "@/lib/prisma";

export type ActivityCursor = { createdAt: string; id: number };

export function encodeCursor(c: ActivityCursor) {
  return Buffer.from(JSON.stringify(c), "utf8").toString("base64");
}

export function decodeCursor(raw?: string | null): ActivityCursor | null {
  if (!raw) return null;
  try {
    const json = Buffer.from(raw, "base64").toString("utf8");
    const obj = JSON.parse(json);
    const id = Number(obj?.id);
    const createdAt = String(obj?.createdAt ?? "");
    if (!Number.isFinite(id) || !createdAt) return null;
    return { id, createdAt };
  } catch {
    return null;
  }
}

export async function fetchActivityEvents(opts: {
  organizationId: number;
  vendorId?: number | null;
  take: number;
  cursor?: ActivityCursor | null;
}) {
  const take = Math.max(1, Math.min(100, opts.take || 25));
  const cursor = opts.cursor ?? null;

  const where: any = { organizationId: opts.organizationId };
  if (opts.vendorId != null) where.vendorId = opts.vendorId;

  if (cursor) {
    where.AND = [
      {
        OR: [
          { createdAt: { lt: new Date(cursor.createdAt) } },
          {
            AND: [
              { createdAt: { equals: new Date(cursor.createdAt) } },
              { id: { lt: cursor.id } },
            ],
          },
        ],
      },
    ];
  }

  const rows = await prisma.activityEvent.findMany({
    where,
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take: take + 1,
    select: {
      id: true,
      organizationId: true,
      vendorId: true,
      type: true,
      title: true,
      description: true,
      metadata: true,
      createdAt: true,
      actorUserId: true,
      actorName: true,
      actorEmail: true,
      vendor: { select: { id: true, name: true, slug: true } },
    },
  });

  const hasMore = rows.length > take;
  const items = hasMore ? rows.slice(0, take) : rows;

  const nextCursor = hasMore
    ? encodeCursor({
        id: items[items.length - 1].id,
        createdAt: items[items.length - 1].createdAt.toISOString(),
      })
    : null;

  return {
    items: items.map((r) => ({ ...r, createdAt: r.createdAt.toISOString() })),
    nextCursor,
  };
}
'@

  $apiContent = @'
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";
import { decodeCursor, fetchActivityEvents } from "@/lib/activity-feed";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function json(data: any, init?: ResponseInit) {
  return new NextResponse(JSON.stringify(data, null, 2), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...(init?.headers ?? {}),
    },
  });
}

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

async function resolveOrgId(): Promise<number | null> {
  if (devBypassEnabled()) {
    const raw = process.env.TRUVERN_DEV_ORG_ID ?? "";
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  }

  const { userId } = auth();
  if (!userId) return null;

  const dbUser = await prisma.user.findFirst({
    where: { clerkId: userId },
    select: { id: true, organizationId: true },
  });

  if (dbUser?.organizationId) return dbUser.organizationId;

  if (dbUser?.id) {
    const mem = await prisma.orgMembership.findFirst({
      where: { userId: dbUser.id },
      select: { organizationId: true },
      orderBy: { createdAt: "asc" as any },
    });
    return mem?.organizationId ?? null;
  }

  return null;
}

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const scope = (url.searchParams.get("scope") || "org").toLowerCase();
    const takeRaw = url.searchParams.get("take");
    const take = Math.max(1, Math.min(100, Number(takeRaw ?? "25") || 25));

    const cursorRaw = url.searchParams.get("cursor");
    const cursor = decodeCursor(cursorRaw);

    const orgId = await resolveOrgId();
    if (!orgId) return json({ error: "Unauthorized" }, { status: 401 });

    let vendorId: number | null = null;

    if (scope === "vendor") {
      const vendorIdRaw = url.searchParams.get("vendorId");
      const n = Number(vendorIdRaw ?? "");
      if (!Number.isFinite(n)) {
        return json({ error: "Missing or invalid vendorId" }, { status: 400 });
      }
      vendorId = n;

      const v = await prisma.vendor.findFirst({
        where: { id: vendorId, organizationId: orgId },
        select: { id: true },
      });
      if (!v) return json({ error: "Vendor not found" }, { status: 404 });
    }

    let actorHint: any = null;
    if (!devBypassEnabled()) {
      try {
        const u = await currentUser();
        actorHint = u
          ? {
              clerkId: u.id,
              name: u.fullName ?? null,
              email: u.emailAddresses?.[0]?.emailAddress ?? null,
            }
          : null;
      } catch {}
    }

    const result = await fetchActivityEvents({
      organizationId: orgId,
      vendorId,
      take,
      cursor,
    });

    return json({
      scope: vendorId ? "vendor" : "org",
      organizationId: orgId,
      vendorId,
      take,
      cursor: cursorRaw ?? null,
      nextCursor: result.nextCursor,
      items: result.items,
      actorHint,
    });
  } catch (e: any) {
    console.error("GET /api/activity failed:", e);
    return json({ error: "Internal error" }, { status: 500 });
  }
}
'@

  Write-TextFile -Path $libPath -Content $libContent
  Write-TextFile -Path $apiPath -Content $apiContent

  Write-Log "Phase 325B complete ✅" "DONE"
  Write-Host ""
  Write-Host "✅ Phase 325B complete. Log: $script:LogFile"
  Write-Host "Try: http://localhost:3000/api/activity"
  Write-Host "Try vendor: /api/activity?scope=vendor&vendorId=1"
}
catch {
  if (-not $script:LogFile) { $script:LogFile = Join-Path $PWD "Phase325B-FAILED.log" }
  try { Add-Content -Path $script:LogFile -Value $_.Exception.Message } catch {}
  Write-Host ""
  Write-Host "❌ Phase 325B failed. See log: $script:LogFile"
  throw
}
