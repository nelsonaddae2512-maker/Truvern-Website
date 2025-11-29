# Phase148a-LayoutFix.ps1
$ErrorActionPreference='Stop'
if ((Get-Location).Path -match '\\Windows\\System32$') { Write-Host "cd into your project folder first." -ForegroundColor Red; exit 1 }

$root = $pwd.Path
$app  = Join-Path $root 'app'
$layout = Join-Path $app 'layout.tsx'
$backup = Join-Path $app ('layout.tsx.phase148a.bak')

if (!(Test-Path $app)) { New-Item -ItemType Directory -Force -Path $app | Out-Null }

if (Test-Path $layout) {
  Copy-Item $layout $backup -Force
  Write-Host "Backup -> $backup"
}

# Write a clean, valid Next.js App Router layout with ONE metadata export
@'
import "./globals.css";
import type { Metadata } from "next";
import Navbar from "./components/Navbar";
import Footer from "./components/Footer";

export const metadata: Metadata = {
  metadataBase: new URL("https://truvern.com"),
  title: { default: "Truvern", template: "%s | Truvern" },
  description: "Truvern - Vendor trust network and TPRM.",
  openGraph: {
    url: "https://truvern.com",
    siteName: "Truvern",
    type: "website",
    images: ["/opengraph-image.png"]
  },
  icons: { icon: "/favicon.ico" }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Navbar />
        {children}
        <Footer />
      </body>
    </html>
  );
}
'@ | Set-Content -Path $layout -Encoding UTF8

Write-Host "Wrote clean app/layout.tsx"

# Optional: quick cache clear and build
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

if (Get-Command pnpm -ErrorAction SilentlyContinue) {
  pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
  npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
  yarn build
} else {
  Write-Host "Build tool not found (pnpm/npm/yarn). Skipping build." -ForegroundColor Yellow
}
