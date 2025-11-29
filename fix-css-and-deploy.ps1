$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\MR.NELSON\Downloads\truvern'

# Ensure tools
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw 'npm not found on PATH' }

# Tailwind/PostCSS dev deps
npm pkg set devDependencies.tailwindcss="^3.4.13"
npm pkg set devDependencies.postcss="^8.4.47"
npm pkg set devDependencies.autoprefixer="^10.4.20"
npm pkg set devDependencies.@tailwindcss/typography="^0.5.13"
npm pkg set devDependencies.@tailwindcss/forms="^0.5.7"

# Next build scripts (normalized)
npm pkg set scripts.dev="next dev"
npm pkg set scripts.build="next build"
npm pkg set scripts.start="next start"

# postcss.config.js
@"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
}
"@ | Set-Content -Encoding UTF8 .\postcss.config.js

# tailwind.config.js
@"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}"
  ],
  theme: { extend: {} },
  plugins: [
    require("@tailwindcss/typography"),
    require("@tailwindcss/forms"),
  ]
}
"@ | Set-Content -Encoding UTF8 .\tailwind.config.js

# app/globals.css with Tailwind directives
$globals = Join-Path $PWD 'app\globals.css'
if (!(Test-Path (Split-Path $globals))) { New-Item -ItemType Directory -Force -Path (Split-Path $globals) | Out-Null }
@"
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body { height: 100%; }
body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Noto Sans", "Apple Color Emoji", "Segoe UI Emoji"; }
"@ | Set-Content -Encoding UTF8 $globals

# Ensure app/layout.tsx imports ./globals.css
$layout = Join-Path $PWD 'app\layout.tsx'
if (Test-Path $layout) {
  $txt = Get-Content $layout -Raw
  if ($txt -notmatch "import\s+['""]\.\/globals\.css['""]") {
    $txt = "import './globals.css';`r`n" + $txt
    Set-Content -Encoding UTF8 $layout $txt
  }
} else {
@"
import './globals.css';

export const metadata = { title: 'Truvern' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang='en'>
      <body>{children}</body>
    </html>
  );
}
"@ | Set-Content -Encoding UTF8 $layout
}

# Clean build artifacts and install deps
if (Test-Path '.next') { Remove-Item -Recurse -Force '.next' }
$env:CI = '1'; $env:HUSKY = '0'; $env:NEXT_TELEMETRY_DISABLED = '1'
npm install
npm run build

# Deploy + alias
$vercel = Join-Path $env:APPDATA 'npm\vercel.cmd'
if (!(Test-Path $vercel)) { npm install -g vercel }
if (!(Test-Path $vercel)) { throw 'vercel.cmd not found after install' }
if (-not $env:VERCEL_TOKEN -or $env:VERCEL_TOKEN.Trim() -eq '') { throw 'Set $env:VERCEL_TOKEN first' }

cmd.exe /d /c "`"$vercel`" deploy --yes --prod --scope nelson-addaes-projects --cwd ."

# Get latest .vercel.app URL and alias
$urls = & $vercel list truvern --scope nelson-addaes-projects | Select-String "https://.*\.vercel\.app"
$prodUrl = $urls.Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { throw 'Could not detect production URL after deploy' }
"PRODUCTION_URL=$prodUrl" | Out-File -FilePath '.\last-deploy.txt' -Encoding UTF8 -Force

cmd.exe /d /c "`"$vercel`" alias set `"$prodUrl`" truvern.com"

Write-Host ''
Write-Host ('truvern.com now points to: ' + $prodUrl)
Write-Host 'Done. Hard-refresh https://truvern.com (Ctrl+F5).'
