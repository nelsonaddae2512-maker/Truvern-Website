// app/api/evidence/presign/route.ts
import { NextResponse } from "next/server";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = await request.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const { filename, type } = body as {
      filename?: string;
      type?: string;
    };

    if (!filename || !type) {
      return NextResponse.json(
        { error: "filename and type are required" },
        { status: 400 }
      );
    }

    const bucket = process.env.S3_BUCKET;
    const region = process.env.S3_REGION || "us-east-1";

    if (!bucket) {
      // This matches the UI message: “Evidence uploads are not configured…”
      return NextResponse.json(
        { error: "S3_BUCKET not set" },
        { status: 500 }
      );
    }

    const s3 = new S3Client({ region });

    const key = `evidence/${Date.now()}-${Math.random()
      .toString(36)
      .slice(2)}-${filename}`;

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: type,
    });

    const url = await getSignedUrl(s3, command, { expiresIn: 60 });

    return NextResponse.json({ url, key });
  } catch (error) {
    console.error("POST /api/evidence/presign error", error);
    return NextResponse.json(
      { error: "Failed to generate presigned URL" },
      { status: 500 }
    );
  }
}
