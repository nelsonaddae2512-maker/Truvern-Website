// app/api/reports/portfolio/export/pdf/route.tsx
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import React from "react";
import {
  Document,
  Page,
  Text,
  View,
  StyleSheet,
  pdf,
} from "@react-pdf/renderer";

const styles = StyleSheet.create({
  page: {
    padding: 32,
    fontSize: 11,
    fontFamily: "Helvetica",
  },
  header: {
    marginBottom: 16,
  },
  title: {
    fontSize: 18,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 10,
    color: "#555",
  },
  sectionTitle: {
    marginTop: 12,
    marginBottom: 4,
    fontSize: 12,
    fontWeight: 700,
  },
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 2,
  },
  label: {
    fontSize: 10,
    color: "#333",
  },
  value: {
    fontSize: 10,
    fontWeight: 700,
  },
  small: {
    fontSize: 9,
    color: "#555",
  },
  listItem: {
    fontSize: 10,
    marginBottom: 2,
  },
});

function riskBucket(score: number | null): "Strong" | "Moderate" | "Weak" | "Unknown" {
  if (score == null) return "Unknown";
  if (score >= 80) return "Strong";
  if (score >= 50) return "Moderate";
  return "Weak";
}

export async function GET(_req: NextRequest) {
  try {
    const vendors = await prisma.vendor.findMany({
      orderBy: { createdAt: "asc" },
      include: {
        _count: {
          select: {
            assessments: true,
            evidence: true,
          },
        },
      },
    });

    const alerts = await prisma.vendorRiskAlert.findMany({
      where: { resolvedAt: null },
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
            riskScore: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    const totalVendors = vendors.length;
    const totalAssessments = vendors.reduce(
      (sum, v) => sum + v._count.assessments,
      0
    );
    const totalEvidence = vendors.reduce(
      (sum, v) => sum + v._count.evidence,
      0
    );

    const avgRisk =
      totalVendors > 0
        ? Math.round(
            vendors.reduce((sum, v) => sum + (v.riskScore ?? 0), 0) /
              totalVendors
          )
        : 0;

    const riskBuckets = {
      Strong: 0,
      Moderate: 0,
      Weak: 0,
      Unknown: 0,
    };

    for (const v of vendors) {
      const bucket = riskBucket(v.riskScore ?? null);
      (riskBuckets as any)[bucket] += 1;
    }

    const topRiskiest = [...vendors]
      .filter((v) => v.riskScore != null)
      .sort(
        (a, b) =>
          (a.riskScore ?? Number.POSITIVE_INFINITY) -
          (b.riskScore ?? Number.POSITIVE_INFINITY)
      )
      .slice(0, 5);

    const now = new Date();
    const generatedAt = now.toISOString();

    const doc = (
      <Document>
        <Page size="A4" style={styles.page}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.title}>Truvern Vendor Portfolio Snapshot</Text>
            <Text style={styles.subtitle}>
              Executive view of third-party risk posture
            </Text>
            <Text style={styles.small}>Generated at: {generatedAt}</Text>
          </View>

          {/* High-level stats */}
          <Text style={styles.sectionTitle}>Portfolio overview</Text>
          <View style={styles.row}>
            <Text style={styles.label}>Vendors onboarded</Text>
            <Text style={styles.value}>{totalVendors}</Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Average risk score</Text>
            <Text style={styles.value}>
              {totalVendors === 0 ? "—" : `${avgRisk} / 100`}
            </Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Assessments completed</Text>
            <Text style={styles.value}>{totalAssessments}</Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Evidence items</Text>
            <Text style={styles.value}>{totalEvidence}</Text>
          </View>

          {/* Risk distribution */}
          <Text style={styles.sectionTitle}>Risk distribution (by score band)</Text>
          {(["Strong", "Moderate", "Weak", "Unknown"] as const).map((bucket) => (
            <View key={bucket} style={styles.row}>
              <Text style={styles.label}>{bucket}</Text>
              <Text style={styles.value}>
                {(riskBuckets as any)[bucket]} of {totalVendors}
              </Text>
            </View>
          ))}

          {/* Alerts */}
          <Text style={styles.sectionTitle}>Open risk alerts</Text>
          {alerts.length === 0 ? (
            <Text style={styles.small}>
              No open automated alerts based on current rules.
            </Text>
          ) : (
            <>
              <Text style={styles.small}>
                {alerts.length} open alert{alerts.length === 1 ? "" : "s"} –
                highest priority items for follow-up.
              </Text>
              {alerts.slice(0, 6).map((a) => (
                <Text key={a.id} style={styles.listItem}>
                  • {a.vendor.name} – {a.message}
                </Text>
              ))}
              {alerts.length > 6 && (
                <Text style={styles.small}>
                  (Additional alerts not shown in this summary.)
                </Text>
              )}
            </>
          )}

          {/* Top riskiest */}
          <Text style={styles.sectionTitle}>Top 5 riskiest vendors</Text>
          {topRiskiest.length === 0 ? (
            <Text style={styles.small}>No vendors with risk scores yet.</Text>
          ) : (
            topRiskiest.map((v) => (
              <Text key={v.id} style={styles.listItem}>
                • {v.name} – score {v.riskScore ?? "—"}/100,{" "}
                {v._count.assessments} assessments, {v._count.evidence} evidence
                item(s)
              </Text>
            ))
          )}

          <Text
            style={{
              marginTop: 16,
              fontSize: 9,
              color: "#777",
            }}
          >
            This snapshot is generated automatically by the Truvern risk engine
            using current vendor data, assessments, evidence, and trend rules.
          </Text>
        </Page>
      </Document>
    );

    const pdfFile = await pdf(doc).toBuffer();

    return new NextResponse(pdfFile, {
      status: 200,
      headers: {
        "Content-Type": "application/pdf",
        "Content-Disposition":
          'attachment; filename="truvern-portfolio-snapshot.pdf"',
      },
    });
  } catch (err) {
    console.error("Error generating portfolio PDF:", err);
    return NextResponse.json(
      { error: "Failed to generate portfolio PDF" },
      { status: 500 }
    );
  }
}
