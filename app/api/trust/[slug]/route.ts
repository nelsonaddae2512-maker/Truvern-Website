export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { computeTrustScore } from "@/lib/trust";
import { rateLimit } from "@/lib/ratelimit";
type AnswerLite = { frameworks?: string[] };

export async function GET(req: NextRequest, { params }: { params: { slug: string } }){
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0] || '127.0.0.1';
  const rl = await rateLimit(ip, 'rl:trust');
  if(!rl.allowed){ return new Response('Too Many Requests', { status: 429, headers: { 'Retry-After': Math.ceil((rl.reset - Date.now())/1000).toString() } }); }

  const vendor = await prisma.vendor.findUnique({ where: { slug: params.slug } });
  if(!vendor || !vendor.trustPublic) return NextResponse.json({ error:"Not found" }, { status: 404 });

  const answers = await prisma.answer.findMany({ where: { vendorId: vendor.id }, select: { answer:true, maturity:true, criticality:true, frameworks:true } });
  const evidenceApproved = await prisma.evidence.count({ where: { vendorId: vendor.id, status: "approved" } });
  const evidencePending = await prisma.evidence.count({ where: { vendorId: vendor.id, status: "pending" } });

  let disclosuresHigh = false;
  const { score, level } = computeTrustScore({ answers, evidenceApproved, evidencePending, disclosuresHigh });
  await prisma.vendor.update({ where: { id: vendor.id }, data: { trustScore: score, trustLevel: level, trustUpdatedAt: new Date() } });

const frameworks = new Set<string>(); (answers as AnswerLite[]).forEach((a) => (a.frameworks ?? []).forEach((f: string) => frameworks.add(f)));
  return NextResponse.json({ vendor: { name: vendor.name, slug: vendor.slug }, trust: { score, level, updatedAt: new Date().toISOString() }, stats: { answers: answers.length, evidenceApproved, evidencePending, frameworks: Array.from(frameworks).slice(0, 12) } });
}
