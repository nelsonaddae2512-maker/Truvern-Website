param([switch]$Deploy,[switch]$SkipInstall,[switch]$SkipBuild)
$ErrorActionPreference = "Stop"
function Note($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# --- create route.ts if missing ---
$apiDir = Join-Path $root 'app\api\reports\board'
$routePath = Join-Path $apiDir 'route.ts'
if(!(Test-Path $apiDir)){ New-Item -ItemType Directory -Path $apiDir -Force | Out-Null }
$route = @"
import { NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";
declare global { var __truvern_prisma__: PrismaClient | undefined; }
const prisma = global.__truvern_prisma__ ?? new PrismaClient();
if (!global.__truvern_prisma__) global.__truvern_prisma__ = prisma;
export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const org = url.searchParams.get("org");
    if (!org) return NextResponse.json({ ok:false, error:"Missing org" }, { status:400 });
    const record = await prisma.organization.findFirst({
      where: { OR: [{ id: org }, { name: org }] },
      select: { id:true, name:true, createdAt:true }
    });
    if (!record) return NextResponse.json({ ok:false, error:"Not found" }, { status:404 });
    return NextResponse.json({ ok:true, record, board:{ generatedAt: new Date().toISOString() }});
  } catch (e:any) { return NextResponse.json({ ok:false, error:String(e?.message??e) }, { status:500 }); }
}
"@
[System.IO.File]::WriteAllText($routePath,$route,[System.Text.UTF8Encoding]::new($false))
Note "Wrote $routePath" "Green"

# --- install ---
if(-not $SkipInstall){
  if(Get-Command pnpm -ErrorAction SilentlyContinue){ & pnpm install } else { & npm i -g pnpm; & pnpm install }
  if($LASTEXITCODE -ne 0){ throw "install failed ($LASTEXITCODE)" }
  Note "Install complete" "Green"
}else{ Note "Skipped install" "Yellow" }

# --- build ---
if(-not $SkipBuild){
  Note "Building Next.js..." "Cyan"
  & pnpm run build
  if($LASTEXITCODE -ne 0){ throw "build failed ($LASTEXITCODE)" }
  Note "Build complete" "Green"
}else{ Note "Skipped build" "Yellow" }

# --- deploy (fixed arg passing) ---
if($Deploy){
  if(Get-Command vercel -ErrorAction SilentlyContinue){
    Note "Pulling Vercel env (production)..." "Cyan"
    & vercel pull --yes --environment production | Out-Null
    if($LASTEXITCODE -ne 0){ throw "vercel pull failed ($LASTEXITCODE)" }

    $deployArgs = @("--prod","--yes")
    if(-not $SkipBuild){ $deployArgs += "--prebuilt" }  # add as a separate arg

    Note ("Deploying to Vercel ({0})..." -f ($deployArgs -join ' ')) "Cyan"
    & vercel deploy @deployArgs
    if($LASTEXITCODE -ne 0){ throw "vercel deploy failed ($LASTEXITCODE)" }
    Note "Deployment complete" "Green"
  } else {
    Note "Vercel CLI not found; skipping deploy." "Yellow"
  }
}else{ Note "Deploy flag not set; skipping deploy." "DarkGray" }

# hint
$last = Join-Path $root '.last-org-id.txt'
if(Test-Path $last){
  $org = (Get-Content $last | Select-Object -First 1).Trim()
  if($org){ Note ("Try:  curl https://truvern.com/api/reports/board?org={0}" -f $org) "DarkGray" }
}

Note "Phase62-API-Bridge.ps1 completed successfully." "Green"