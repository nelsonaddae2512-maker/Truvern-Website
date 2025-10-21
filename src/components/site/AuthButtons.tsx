/**
 * Mock AuthButtons component for build and UI placeholder.
 * Replaces missing "@/components/site/AuthButtons".
 */

"use client";

import React from "react";

export function AuthButtons() {
  return (
    <div style={{ display: "flex", gap: "10px" }}>
      <button style={{ padding: "6px 12px", background: "#0070f3", color: "white", border: "none", borderRadius: "4px" }}>
        Sign In
      </button>
      <button style={{ padding: "6px 12px", background: "gray", color: "white", border: "none", borderRadius: "4px" }}>
        Register
      </button>
    </div>
  );
}

export default AuthButtons;
