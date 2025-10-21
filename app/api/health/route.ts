import prisma from "@/lib/db";

import { NextResponse } from "next/server"
export const dynamic = "force-dynamic"
export async function GET() { return NextResponse.json({ ok: true, source: "app-router/health" }); }