// app/api/evidence/upload-url/route.ts
import { NextRequest, NextResponse } from "next/server";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export const runtime = "nodejs";

const bucket = process.env.S3_BUCKET_NAME;
const region = process.env.AWS_REGION;
const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;

if (!bucket || !region || !accessKeyId || !secretAccessKey) {
  console.warn(
    "[evidence/upload-url] Missing S3 env vars. " +
      "Uploads will fail until AWS_REGION, AWS_ACCESS_KEY_ID, " +
      "AWS_SECRET_ACCESS_KEY, and S3_BUCKET_NAME are set."
  );
}

const publicBaseUrl =
  process.env.S3_PUBLIC_BASE_URL ||
  (bucket && region
    ? `https://${bucket}.s3.${region}.amazonaws.com`
    : "");

const s3 =
  bucket && region && accessKeyId && secretAccessKey
    ? new S3Client({
        region,
        credentials: {
          accessKeyId,
          secretAccessKey,
        },
      })
    : null;

export async function POST(req: NextRequest) {
  try {
    if (!s3 || !bucket || !region || !publicBaseUrl) {
      return NextResponse.json(
        { error: "S3 is not configured on the server." },
        { status: 500 }
      );
    }

    const body = await req.json().catch(() => ({}));
    const { fileName, fileType } = body ?? {};

    if (!fileName || typeof fileName !== "string") {
      return NextResponse.json(
        { error: "fileName is required." },
        { status: 400 }
      );
    }

    const safeName = fileName.replace(/[^\w.\-]+/g, "_");
    const key = `evidence/${Date.now()}-${Math.random()
      .toString(36)
      .slice(2)}-${safeName}`;

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: typeof fileType === "string" ? fileType : undefined,
    });

    const uploadUrl = await getSignedUrl(s3, command, {
      expiresIn: 60 * 5, // 5 minutes
    });

    const fileUrl = `${publicBaseUrl}/${key}`;

    return NextResponse.json(
      {
        uploadUrl,
        fileUrl,
        key,
      },
      { status: 200 }
    );
  } catch (error) {
    console.error("[evidence/upload-url] error:", error);
    return NextResponse.json(
      { error: "Failed to generate upload URL." },
      { status: 500 }
    );
  }
}
