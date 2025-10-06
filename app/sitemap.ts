
import type { MetadataRoute } from "next";
export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://truvern.com";
  return [
    { url: base + "/", changeFrequency: "weekly", priority: 1 },
    { url: base + "/features" },
    { url: base + "/pricing" },
    { url: base + "/vendors" },
    { url: base + "/buyers" },
    { url: base + "/trust-network" },
    { url: base + "/trust" }
  ];
}
