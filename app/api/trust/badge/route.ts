export const runtime = "nodejs";

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "edge";

export async function GET(req: NextRequest){
  const { searchParams } = new URL(req.url);
  const slug = searchParams.get("slug");
  const token = searchParams.get("t") || undefined;
  if(!slug) return new NextResponse("Bad Request", { status: 400 });
  const vendor = await prisma.vendor.findUnique({ where: { slug } });
  if(!vendor || !vendor.trustPublic || vendor.trustScore==null) return new NextResponse("Not found", { status: 404 });
  if(vendor.trustToken && token && token !== vendor.trustToken){ return new NextResponse("Forbidden", { status: 403 }); }
  const level = vendor.trustLevel || "Low";
  const color = level==="High" ? "#059669" : level==="Medium" ? "#D97706" : "#DC2626";
  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="190" height="28" role="img" aria-label="Trust:${level}">
  <rect width="190" height="28" fill="#111827" rx="6"/>
  <text x="12" y="18" fill="#ffffff" font-family="Inter, Arial" font-size="12">Trust</text>
  <rect x="60" y="5" width="120" height="18" fill="${color}" rx="4"/>
  <text x="70" y="18" fill="#ffffff" font-family="Inter, Arial" font-size="12">${level} • ${vendor.trustScore}</text>
</svg>`;
  return new NextResponse(svg, { headers: { "content-type":"image/svg+xml", "cache-control":"s-maxage=300, stale-while-revalidate=3600" }});
}
