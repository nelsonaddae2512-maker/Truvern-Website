// app/ops/health/master-seal-badge/route.ts
// Tiny SVG badge (like shields.io) for master seal status

import fs from "fs/promises";
import path from "path";

type SealHealth = {
  status?: string;
  verified?: boolean;
};

export const dynamic = "force-dynamic";

function buildBadge(label: string, message: string, color: string): string {
  const labelWidth = 70;
  const valueWidth = 70;
  const totalWidth = labelWidth + valueWidth;

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="20" role="img" aria-label="${label}: ${message}">
  <linearGradient id="smooth" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <mask id="round">
    <rect width="${totalWidth}" height="20" rx="3" fill="#fff"/>
  </mask>
  <g mask="url(#round)">
    <rect width="${labelWidth}" height="20" fill="#555"/>
    <rect x="${labelWidth}" width="${valueWidth}" height="20" fill="${color}"/>
    <rect width="${totalWidth}" height="20" fill="url(#smooth)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11">
    <text x="${labelWidth / 2}" y="14">${label}</text>
    <text x="${labelWidth + valueWidth / 2}" y="14">${message}</text>
  </g>
</svg>`;
}

export async function GET() {
  let status: "healthy" | "pass" | "fail" | "unknown" = "unknown";

  try {
    const opsDir = path.join(process.cwd(), "public", "ops", "health");
    const sealPath = path.join(opsDir, "master-seal.json");
    const raw = await fs.readFile(sealPath, "utf8");
    const seal = JSON.parse(raw) as SealHealth;

    if (seal.status === "pass" && seal.verified) {
      status = "healthy";
    } else if (seal.status === "pass") {
      status = "pass";
    } else if (seal.status === "fail") {
      status = "fail";
    }
  } catch {
    status = "unknown";
  }

  let color = "#9f9f9f";
  let message = "unknown";

  if (status === "healthy") {
    color = "#2cbe4e"; // green
    message = "healthy";
  } else if (status === "pass") {
    color = "#dfb317"; // yellow
    message = "pass";
  } else if (status === "fail") {
    color = "#e05d44"; // red
    message = "fail";
  }

  const svg = buildBadge("truvern", message, color);

  return new Response(svg, {
    status: 200,
    headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "no-store",
    },
  });
}
