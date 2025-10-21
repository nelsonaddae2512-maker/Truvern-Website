import prisma from "@/lib/db";

export const runtime = "nodejs"
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner"
export async function POST(req: Request){ const { getServerSession } = await import("next-auth"); const { authOptions } = await import("@/lib/auth"); 
  const session = await getServerSession(authOptions);
  if(!session?.user) return NextResponse.json({ error:'Unauthorized' }, { status: 401 });
  const { filename, type } = await req.json().catch(()=>({}));
  if(!filename || !type) return NextResponse.json({ error:'filename & type required' }, { status: 400 });

  const region = process.env.S3_REGION || 'us-east-1';
  const bucket = process.env.S3_BUCKET;
  if(!bucket) return NextResponse.json({ error:'S3_BUCKET not set' }, { status: 500 });

  const s3 = new S3Client({ region });
  const key = `evidence/${Date.now()}-${Math.random().toString(36).slice(2)}-${filename}`;
  const cmd = new PutObjectCommand({ Bucket: bucket, Key: key, ContentType: type });
  const url = await getSignedUrl(s3, cmd, { expiresIn: 60 });
  return NextResponse.json({ url, key });
}

export async function GET(){ return new Response('{"ok":true}',{ status:200, headers:{ "Content-Type":"application/json" }}); }

