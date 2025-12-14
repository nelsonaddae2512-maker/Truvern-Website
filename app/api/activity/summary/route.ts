// app/api/activity/summary/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

const WINDOW_HOURS = 24;

export async function GET() {
  try {
    const now = new Date();
    const since = new Date(now.getTime() - WINDOW_HOURS * 60 * 60 * 1000);

    const [recentEvidenceCount, recentAssessmentCount] = await Promise.all([
      prisma.evidence.count({
        where: {
          uploadedAt: {
            gte: since,
          },
        },
      }),
      prisma.assessment.count({
        where: {
          createdAt: {
            gte: since,
          },
        },
      }),
    ]);

    const total = recentEvidenceCount + recentAssessmentCount;

    return NextResponse.json({
      hasRecent: total > 0,
      recentCount: total,
      windowHours: WINDOW_HOURS,
    });
  } catch (error) {
    console.error("Error in /api/activity/summary:", error);
    return NextResponse.json(
      { hasRecent: false, recentCount: 0, windowHours: WINDOW_HOURS },
      { status: 200 }
    );
  }
}
