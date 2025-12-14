// app/api/status/master-seal/route.ts
// Tiny JSON status for embedding in external systems

import { NextResponse } from "next/server";
import fs from "fs/promises";
import path from "path";

type SealHealth = {
  status?: string;
  verified?: boolean;
  checkedAt?: string;
  storedSeal?: string;
  currentSeal?: string;
  storedFileCount?: number;
};

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const opsDir = path.join(process.cwd(), "public", "ops", "health");
    const sealPath = path.join(opsDir, "master-seal.json");
    const raw = await fs.readFile(sealPath, "utf8");
    const seal = JSON.parse(raw) as SealHealth;

    const status =
      seal.status === "pass" && seal.verified
        ? "healthy"
        : seal.status === "pass"
        ? "pass"
        : "fail";

    return NextResponse.json(
      {
        ok: status === "healthy" || status === "pass",
        status,
        verified: !!seal.verified,
        checkedAt: seal.checkedAt ?? null,
        seal: {
          storedHash: seal.storedSeal ?? null,
          currentHash: seal.currentSeal ?? null,
          fileCount: seal.storedFileCount ?? null,
        },
      },
      {
        status: 200,
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        status: "unknown",
        error: "master seal not available",
      },
      {
        status: 503,
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  }
}
