
import { NextResponse } from "next/server";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

export async function GET(req: Request){
  const session = await getServerSession(authOptions);
  if(!session?.user) return NextResponse.json({ error:'Unauthorized' }, { status: 401 });
  const { searchParams } = new URL(req.url);
  const key = searchParams.get('key');
  if(!key) return NextResponse.json({ error:'key required' }, { status: 400 });
  const region = process.env.S3_REGION || 'us-east-1';
  const bucket = process.env.S3_BUCKET;
  if(!bucket) return NextResponse.json({ error:'S3_BUCKET not set' }, { status: 500 });
  const s3 = new S3Client({ region });
  const cmd = new GetObjectCommand({ Bucket: bucket, Key: key });
  const url = await getSignedUrl(s3, cmd, { expiresIn: 60 });
  return NextResponse.json({ url });
}
