import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET() {
  try {
    const org = await prisma.organization.findFirst({
      include: {
        vendors: {
          include: {
            assessments: { include: { answers: true } },
            evidence: true,
            issues: true,
          },
        },
      },
    });

    if (!org) return new NextResponse("No organization found", { status: 404 });

    const lines = [];
    lines.push("Vendor,Slug,Score,Issues,Evidence,Assessments");

    for (const v of org.vendors) {
      const answers = v.assessments.flatMap(a => a.answers);
      const score = answers.length
        ? Math.round(
            (answers.filter(a => a.response === "yes").length /
              answers.length) * 100
          )
        : 0;

      lines.push([
        `"${v.name}"`,
        v.slug,
        score,
        v.issues.length,
        v.evidence.length,
        v.assessments.length
      ].join(","));
    }

    return new NextResponse(lines.join("\n"), {
      headers: {
        "Content-Type": "text/csv",
        "Content-Disposition": "attachment; filename=board.csv"
      }
    });

  } catch (err) {
    console.error(err);
    return new NextResponse("CSV generation failed", { status: 500 });
  }
}
