export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import type { NextRequest } from "next/server";

/** Render a simple SVG badge */
function svgBadge(label: string, value: string, color = "#10b981"){
  const pad = 8;
  const font = 12;
  // Fixed width to keep it simple and cacheable
  const w = 140, h = 24;
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${label}: ${value}">
  <title>${label}: ${value}</title>
  <rect rx="4" width="${w}" height="${h}" fill="#111827"/>
  <rect x="${w/2}" rx="0" width="${w/2}" height="${h}" fill="${color}" opacity="0.15"/>
  <text x="${pad}" y="16" fill="#e5e7eb" font-family="ui-sans-serif,system-ui,Segoe UI,Roboto,Helvetica,Arial" font-size="${font}">${label}</text>
  <text x="${w/2 + pad}" y="16" fill="${color}" font-weight="700" font-family="ui-sans-serif,system-ui,Segoe UI,Roboto,Helvetica,Arial" font-size="${font}">${value}</text>
</svg>`;
}

export async function GET(req: NextRequest){
  try{
    const { searchParams } = new URL(req.url);
    const slug = (searchParams.get("slug") || "").trim().toLowerCase();

    // If no slug is provided, return a neutral badge that always builds.
    if(!slug){
      const svg = svgBadge("Trust", "—", "#6b7280"); // gray
      return new Response(svg, { status: 200, headers: { "Content-Type": "image/svg+xml", "Cache-Control": "no-store" } });
    }

    // Lazy import prisma only at request time; never at module top-level.
    let prisma: any = null;
    try { prisma = (await import("@/lib/prisma")).prisma ?? null; } catch {}

    // If prisma unavailable, still return an OK badge (keeps build happy)
    if(!prisma){
      const svg = svgBadge("Trust", "N/A", "#f59e0b"); // amber
      return new Response(svg, { status: 200, headers: { "Content-Type": "image/svg+xml", "Cache-Control": "no-store" } });
    }

    // Try to derive a score + level; all failures fall back to a neutral badge
    let score = 0, level = "Low", color = "#ef4444"; // red
    try{
      const vendor = await prisma.vendor.findFirst({ where: { slug }, select: { id:true, trustScore:true, trustLevel:true } });
      if(vendor){
        // Prefer stored trust; otherwise compute from answers (softly)
        if (typeof vendor.trustScore === "number") score = vendor.trustScore;
        if (typeof vendor.trustLevel === "string") level = vendor.trustLevel;

        if(!vendor.trustLevel || vendor.trustScore == null){
          const answers = await prisma.answer.findMany({
            where: { vendorId: vendor.id },
            select: { evidenceStatus: true }
          });
          const total = answers.length;
          const approved = answers.filter(a => a.evidenceStatus === "approved").length;
          score = total > 0 ? Math.round((approved/total) * 100) : 0;
          level = score >= 80 ? "High" : score >= 50 ? "Medium" : "Low";
        }
      } else {
        // unknown slug
        const svg = svgBadge("Trust", "Unknown", "#9ca3af");
        return new Response(svg, { status: 200, headers: { "Content-Type": "image/svg+xml", "Cache-Control": "no-store" } });
      }
    }catch{
      // swallow and continue with defaults
    }

    // Color by level
    if(level === "High") color = "#10b981";      // emerald
    else if(level === "Medium") color = "#f59e0b"; // amber

    const svg = svgBadge("Trust", `${level} (${score}%)`, color);
    return new Response(svg, { status: 200, headers: { "Content-Type": "image/svg+xml", "Cache-Control": "no-store" } });
  }catch{
    // Never break collect-page-data
    const svg = svgBadge("Trust", "Error", "#ef4444");
    return new Response(svg, { status: 200, headers: { "Content-Type": "image/svg+xml", "Cache-Control": "no-store" } });
  }
}