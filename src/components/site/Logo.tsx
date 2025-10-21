/**
 * Mock Logo component for build completion.
 * Fixes "Cannot find module '@/components/site/Logo'" error.
 * Displays placeholder logo text until real asset is added.
 */

"use client";

import React from "react";

export function Logo() {
  return (
    <div style={{
      fontSize: "1.5rem",
      fontWeight: "bold",
      color: "#0070f3",
      letterSpacing: "0.5px"
    }}>
      Truvern
    </div>
  );
}

export default Logo;
