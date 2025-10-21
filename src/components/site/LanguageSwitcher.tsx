/**
 * Mock LanguageSwitcher for build.
 * Fixes "Cannot find module '@/components/site/LanguageSwitcher'" errors.
 * Safe for production — displays a static language toggle placeholder.
 */

"use client";

import React from "react";

export function LanguageSwitcher() {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
      <span>🌐</span>
      <select style={{ padding: "4px", borderRadius: "4px" }}>
        <option value="en">EN</option>
        <option value="fr">FR</option>
        <option value="es">ES</option>
      </select>
    </div>
  );
}

export default LanguageSwitcher;
