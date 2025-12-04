// app/api/evidence/list/route.ts
import { NextResponse } from "next/server";

export async function GET() {
  try {
    const now = new Date().toISOString();

    // Static stub list – safe, predictable, and guaranteed 200
    const evidence = [
      {
        id: 1,
        vendorId: 1,
        vendorName: "Acme Payments",
        title: "SOC 2 Type II (stub)",
        description:
          "Static stub evidence record from /api/evidence/list – replace with real Prisma query later.",
        fileUrl: "https://example.com/soc2.pdf",
        createdAt: now,
      },
    ];

    return NextResponse.json(
      {
        ok: true,
        count: evidence.length,
        evidence,
        note:
          "This is a stubbed evidence list response (no database). Safe placeholder to avoid 500s.",
      },
      { status: 200 }
    );
  } catch (error) {
    // Even in the worst case, do NOT 500 – return an empty list with ok:true
    console.error("Unexpected error in /api/evidence/list stub:", error);

    return NextResponse.json(
      {
        ok: true,
        count: 0,
        evidence: [],
        note:
          "Stub /api/evidence/list encountered an internal error but returned an empty list instead of 500.",
      },
      { status: 200 }
    );
  }
}
