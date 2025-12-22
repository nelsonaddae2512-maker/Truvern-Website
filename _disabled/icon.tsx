// app/icon.tsx
import { ImageResponse } from "next/og";

export const runtime = "edge";
export const size = { width: 64, height: 64 };
export const contentType = "image/png";

export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "64px",
          height: "64px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          borderRadius: "14px",
          background: "radial-gradient(circle at 30% 30%, #34d399 0%, #0f172a 55%, #020617 100%)",
          color: "white",
          fontSize: 34,
          fontWeight: 800,
          letterSpacing: -1,
        }}
      >
        T
      </div>
    ),
    { ...size }
  );
}
