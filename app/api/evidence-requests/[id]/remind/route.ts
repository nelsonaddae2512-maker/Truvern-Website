// app/api/evidence-requests/[id]/remind/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { notifyVendorEvidenceStatusChange, isOpenStatus } from "@/lib/vendor-notifications";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function parseId(raw: string) {
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

// Throttle marker stored in reviewNote.
// Format: "[REMIND:2025-12-23T12:34:56.789Z]"
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

export async function POST(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const requestId = parseId(id);
    if (!requestId) return NextResponse.json({ ok: false, error: "Invalid id" }, { status: 400 });

    const er = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      select: {
        id: true,
        label: true,
        status: true,
        dueAt: true,
        reviewNote: true,
      } as any,
    });

    if (!er) return NextResponse.json({ ok: false, error: "Not found" }, { status: 404 });

    if (!isOpenStatus((er as any).status)) {
      return NextResponse.json(
        { ok: false, error: "Request is not open; no reminder sent." },
        { status: 400 }
      );
    }

    // throttle: 30 minutes
    const lastIso = extractLastRemindIso((er as any).reviewNote);
    if (lastIso) {
      const lastMs = Date.parse(lastIso);
      if (Number.isFinite(lastMs)) {
        const mins = (Date.now() - lastMs) / 60000;
        if (mins < 30) {
          return NextResponse.json({
            ok: false,
            throttled: true,
            error: "Reminder recently sent",
            minutesUntilAllowed: Math.ceil(30 - mins),
          });
        }
      }
    }

    const orgNameHeader = ""; // notifier will pull org name safely
    const label = (er as any).label || `Evidence Request #${(er as any).id}`;
    const dueText = (er as any).dueAt ? new Date((er as any).dueAt).toLocaleString() : "No due date set";

    const sent = await notifyVendorEvidenceStatusChange({
      evidenceRequestId: requestId,
      subject: `Reminder: evidence request pending`,
      headline: `Reminder: action needed`,
      message: `Please complete: <b>${label}</b>.<br/>Due: <b>${dueText}</b>.<br/><br/>Sent on behalf of ${orgNameHeader || "your customer"}.`,
    });

    if (!sent?.ok) {
      return NextResponse.json({ ok: false, error: sent?.reason || "Unable to send reminder" }, { status: 400 });
    }

    const nowIso = new Date().toISOString();
    await prisma.evidenceRequest.update({
      where: { id: requestId },
      data: { reviewNote: addRemindMarker((er as any).reviewNote, nowIso) },
      select: { id: true } as any,
    });

    return NextResponse.json({ ok: true, requestId, to: (sent as any).to || null });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Server error" }, { status: 500 });
  }
}
