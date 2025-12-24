// app/api/evidence-requests/remind-due-soon/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { notifyVendorEvidenceStatusChange, isOpenStatus } from "@/lib/vendor-notifications";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function extractLastRemindIso(note: string | null | undefined): string | null {
  if (!note) return null;
  const m = note.match(/\[REMIND:([0-9T:\.\-Z]+)\]/i);
  return m?.[1] || null;
}

function addRemindMarker(note: string | null | undefined, iso: string) {
  const base = (note || "").trim();
  const marker = `[REMIND:${iso}]`;
  if (!base) return marker;
  return `${base}\n${marker}`;
}

function parseBool(v: any, fallback = false) {
  if (typeof v === "boolean") return v;
  if (typeof v === "number") return v !== 0;
  if (typeof v === "string") {
    const s = v.trim().toLowerCase();
    if (["true", "1", "yes", "y", "on"].includes(s)) return true;
    if (["false", "0", "no", "n", "off"].includes(s)) return false;
  }
  return fallback;
}

function parseLooseJsonObject(raw: string): any {
  // Accepts PowerShell-ish object text like:
  // { days: 7, limit: 200, dryRun: true }
  // Converts keys to quoted JSON keys.
  const trimmed = raw.trim();
  if (!trimmed.startsWith("{") || !trimmed.endsWith("}")) return null;

  // Quote unquoted keys: { days: 7 } -> { "days": 7 }
  const withQuotedKeys = trimmed.replace(/([{\s,])([A-Za-z_][A-Za-z0-9_]*)\s*:/g, '$1"$2":');

  try {
    return JSON.parse(withQuotedKeys);
  } catch {
    return null;
  }
}

async function readBody(req: NextRequest) {
  const rawBody = await req.text().catch(() => "");
  if (!rawBody) return { rawBody: "", body: {} as any, parsedVia: "empty" as const };

  // First: strict JSON
  try {
    return { rawBody, body: JSON.parse(rawBody), parsedVia: "json" as const };
  } catch {}

  // Second: loose JSON (PowerShell-ish)
  const loose = parseLooseJsonObject(rawBody);
  if (loose) return { rawBody, body: loose, parsedVia: "loose" as const };

  // Fallback
  return { rawBody, body: {} as any, parsedVia: "failed" as const };
}

function findAnyEmail(vendor: any): string | null {
  if (!vendor) return null;

  const direct = [
    vendor.contactEmail,
    vendor.email,
    vendor.primaryEmail,
    vendor.securityEmail,
    vendor.supportEmail,
  ]
    .map((x: any) => (typeof x === "string" ? x.trim() : ""))
    .filter(Boolean);

  const fromDirect = direct.find((x: string) => x.includes("@"));
  if (fromDirect) return fromDirect;

  for (const [k, v] of Object.entries(vendor)) {
    if (k.toLowerCase().includes("email") && typeof v === "string" && v.includes("@")) return v.trim();
  }

  return null;
}

export async function POST(req: NextRequest) {
  try {
    const orgIdHeader = req.headers.get("x-org-id");
    const orgId = orgIdHeader ? Number(orgIdHeader) : null;
    if (orgIdHeader && !Number.isFinite(orgId)) {
      return NextResponse.json({ ok: false, error: "Invalid x-org-id" }, { status: 400 });
    }

    const { rawBody, body, parsedVia } = await readBody(req);

    const url = new URL(req.url);
    const qDry = url.searchParams.get("dryRun");

    const days = Number.isFinite(body?.days) ? Math.max(1, Math.min(30, Number(body.days))) : 7;
    const limit = Number.isFinite(body?.limit) ? Math.max(1, Math.min(500, Number(body.limit))) : 200;

    const dryRun = qDry != null ? parseBool(qDry, false) : parseBool(body?.dryRun, false);

    const now = new Date();
    const end = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    const dueSoon = await prisma.evidenceRequest.findMany({
      where: {
        ...(orgId ? { organizationId: orgId } : {}),
        dueAt: { gte: now, lte: end },
      } as any,
      orderBy: [{ dueAt: "asc" }],
      take: limit,
      select: {
        id: true,
        label: true,
        status: true,
        dueAt: true,
        reviewNote: true,
        vendorId: true,
      } as any,
    });

    // In dryRun, we want to preview eligibility even if throttled.
    let eligibleNow = 0;
    let wouldBeThrottled = 0;

    let sentOrWouldSend = 0;
    let skippedThrottled = 0;
    let skippedClosed = 0;
    let skippedNoEmail = 0;
    const errors: Array<{ id: number; error: string }> = [];

    for (const r of dueSoon as any[]) {
      if (!isOpenStatus(r.status)) {
        skippedClosed++;
        continue;
      }

      const vendor = await prisma.vendor.findUnique({ where: { id: r.vendorId } } as any);
      const vendorEmail = findAnyEmail(vendor);
      if (!vendorEmail) {
        skippedNoEmail++;
        continue;
      }

      const lastIso = extractLastRemindIso(r.reviewNote);
      let throttled = false;
      if (lastIso) {
        const lastMs = Date.parse(lastIso);
        if (Number.isFinite(lastMs)) {
          const mins = (Date.now() - lastMs) / 60000;
          if (mins < 30) throttled = true;
        }
      }

      if (dryRun) {
        // Preview counters
        if (throttled) wouldBeThrottled++;
        else eligibleNow++;

        // "would send" means: has email + open + within window
        sentOrWouldSend++;
        continue;
      }

      if (throttled) {
        skippedThrottled++;
        continue;
      }

      try {
        const dueText = r.dueAt ? new Date(r.dueAt).toLocaleString() : "No due date set";
        const label = r.label || `Evidence Request #${r.id}`;

        const sent = await notifyVendorEvidenceStatusChange({
          evidenceRequestId: r.id,
          subject: `Reminder: evidence due soon`,
          headline: `Reminder: evidence due soon`,
          message: `This is a friendly reminder to complete: <b>${label}</b>.<br/>Due: <b>${dueText}</b>.`,
        });

        if (!sent?.ok) {
          skippedNoEmail++;
          continue;
        }

        const nowIso = new Date().toISOString();
        await prisma.evidenceRequest.update({
          where: { id: r.id },
          data: { reviewNote: addRemindMarker(r.reviewNote, nowIso) },
          select: { id: true } as any,
        });

        sentOrWouldSend++;
      } catch (e: any) {
        errors.push({ id: r.id, error: e?.message || "Unknown error" });
      }
    }

    return NextResponse.json({
      ok: true,
      window: { days, start: now.toISOString(), end: end.toISOString() },
      orgId: orgId ?? null,
      limit,
      dryRun,
      totals: {
        fetched: dueSoon.length,
        sentOrWouldSend,
        skippedClosed,
        skippedThrottled,
        skippedNoEmail,
        errors: errors.length,
      },
      preview: dryRun
        ? {
            eligibleNow,
            wouldBeThrottled,
          }
        : null,
      errors,
      debug: {
        queryDryRun: qDry,
        parsedVia,
        rawBody: rawBody?.slice(0, 500),
        parsedBody: body,
      },
    });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Server error" }, { status: 500 });
  }
}
