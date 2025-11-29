$ErrorActionPreference = "Stop"
function W($p,$s){ $d=Split-Path $p -Parent; if(-not (Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null}; [IO.File]::WriteAllText($p,$s,[Text.UTF8Encoding]::new($false)); }

# Locate app dir
$app = Join-Path (Get-Location) 'app'; if(-not(Test-Path $app)){ $app = Join-Path (Get-Location) 'apps\tprm\app' }
if(-not(Test-Path $app)){ throw "No Next.js app at .\app or .\apps\tprm\app" }

# Tailwind (safe if already installed)
pnpm add -D tailwindcss postcss autoprefixer | Out-Null
W (Join-Path (Get-Location) 'tailwind.config.js') "/** @type {import('tailwindcss').Config} */`nmodule.exports={content:['./app/**/*.{ts,tsx}','./components/**/*.{ts,tsx}'],theme:{extend:{}},plugins:[],};"
W (Join-Path (Get-Location) 'postcss.config.js') "module.exports={plugins:{tailwindcss:{},autoprefixer:{}}};"
W (Join-Path $app 'globals.css') "@tailwind base;`n@tailwind components;`n@tailwind utilities;`nhtml,body{background:#fff;color:#0b1220} .page{max-width:1100px;margin:0 auto;padding:24px}"

# Chrome + layout
W (Join-Path $app 'components\SiteChrome.tsx') @"
"use client";
import Link from "next/link";
export default function SiteChrome({children}:{children:React.ReactNode}) {
  return (<>
    <header className="border-b bg-white">
      <div className="page flex items-center justify-between h-16">
        <Link href="/" className="font-semibold text-lg">Truvern</Link>
        <nav className="hidden md:flex gap-6 text-sm text-zinc-700">
          <Link href="/">Home</Link><Link href="/trust-network">Trust Network</Link>
          <Link href="/vendors">Vendors</Link><Link href="/pricing">Pricing</Link>
          <Link href="/contact">Contact</Link>
        </nav>
        <div className="hidden md:flex gap-2">
          <Link href="/login" className="px-3 py-2">Login</Link>
          <Link href="/subscribe" className="px-3 py-2 rounded bg-blue-600 text-white">Get Started</Link>
        </div>
      </div>
    </header>
    <main className="page py-8">{children}</main>
    <footer className="border-t mt-12"><div className="page py-6 text-xs text-zinc-500">© {new Date().getFullYear()} Truvern</div></footer>
  </>);
}
"@

W (Join-Path $app 'layout.tsx') @"
import "./globals.css";
import type { Metadata } from "next";
import SiteChrome from "./components/SiteChrome";
export const metadata: Metadata = {
  title: "Truvern — Vendor Trust Network",
  description: "Assess, compare, and continuously monitor third-party vendors.",
};
export default function RootLayout({children}:{children:React.ReactNode}) {
  return (<html lang="en"><head><meta charSet="utf-8"/></head><body><SiteChrome>{children}</SiteChrome></body></html>);
}
"@

# Home (client) preserved
W (Join-Path $app 'home-safe\HomeClient.tsx') @"
"use client";
import React from "react";
type Vendor={id?:string|number;name?:string}; type Board={generatedAt?:string;vendors?:Vendor[]};
async function j<T>(u:string){try{const r=await fetch(u,{cache:'no-store'});return r.ok?await r.json():null}catch{return null}}
export default function HomeClient(){
  const [vendors,setV]=React.useState<Vendor[]>([]); const [board,setB]=React.useState<Board|null>(null); const [loading,setL]=React.useState(true);
  React.useEffect(()=>{let on=true;(async()=>{const v=await j<any>('/api/vendors'); const b=await j<Board>('/api/board'); if(!on)return;
    setV(Array.isArray(v?.vendors)?v.vendors:(Array.isArray(v)?v:[])??[]); setB(b??null); setL(false)})(); return()=>{on=false}},[]);
  const count=vendors.length;
  return (<div className="space-y-6">
    <section><h1 className="text-3xl font-bold">Trust your vendors.</h1><p className="text-zinc-600 mt-2">Move faster with confidence.</p></section>
    <section className="border rounded-xl p-4 flex items-center gap-4">
      <div className="font-medium">Vendors</div><div className="px-3 py-1 border rounded-full font-mono">{count}</div>
      <div className="text-zinc-500 text-sm">total</div>{board?.generatedAt&&<div className="ml-auto text-xs text-zinc-500">generated {new Date(board.generatedAt).toLocaleString()}</div>}
    </section>
    <div className="grid sm:grid-cols-2 gap-4">
      <a className="border rounded-lg p-4 hover:bg-zinc-50" href="/trust-network"><div className="font-semibold">Open Trust Network</div><div className="text-sm text-zinc-600">Browse and compare vendors</div></a>
      <a className="border rounded-lg p-4 hover:bg-zinc-50" href="/reports/board"><div className="font-semibold">Open Board Report</div><div className="text-sm text-zinc-600">Summary & CSV export</div></a>
    </div>
  </div>);
}
"@

W (Join-Path $app 'page.tsx') 'import HomeClient from "./home-safe/HomeClient"; export default function Page(){ return <HomeClient/> }'

# Build & deploy (FIXED: use "pnpm build")
pnpm install
pnpm build
$deployOut = vercel --prod --yes
$deployed  = ($deployOut | Select-String -Pattern "\S+\.vercel\.app" -AllMatches).Matches.Value | Select-Object -Last 1
if(-not $deployed){ $deployed = (vercel ls --prod | Select-String -Pattern "\S+\.vercel\.app" -AllMatches).Matches.Value | Select-Object -First 1 }
if(-not $deployed){ throw "Could not determine deployed URL." }
vercel alias set $deployed truvern.com     | Out-Null
vercel alias set $deployed www.truvern.com | Out-Null
$base="https://truvern.com"
"$base -> $( (Invoke-WebRequest $base -UseBasicParsing).StatusCode )"
