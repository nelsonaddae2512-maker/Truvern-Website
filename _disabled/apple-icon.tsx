// app/apple-icon.tsx
import { ImageResponse } from "next/og";

export const runtime = "nodejs";
export const size = { width: 180, height: 180 };
export const contentType = "image/png";

export default function AppleIcon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          borderRadius: 40,
          background: "#020617",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          position: "relative",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: -60,
            background:
              "radial-gradient(circle at 20% 20%, rgba(52,211,153,0.38), transparent 58%), radial-gradient(circle at 70% 75%, rgba(34,211,238,0.30), transparent 58%), radial-gradient(circle at 75% 20%, rgba(96,165,250,0.28), transparent 58%)",
          }}
        />
        <div
          style={{
            width: 104,
            height: 104,
            borderRadius: 32,
            border: "1px solid rgba(255,255,255,0.18)",
            background: "rgba(255,255,255,0.06)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "rgba(255,255,255,0.92)",
            fontSize: 56,
            fontWeight: 800,
            letterSpacing: -2,
          }}
        >
          T
        </div>
      </div>
    ),
    size
  );
}
