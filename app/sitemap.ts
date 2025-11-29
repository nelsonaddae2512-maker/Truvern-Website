import type { MetadataRoute } from "next";
export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.APP_URL ?? "https://truvern.com";
  const routes = ["/", "/vendors", "/trust", "/dashboard"];
  const now = new Date().toISOString();
  return routes.map((p) => ({
    url: `${base}${p}`,
    lastModified: now,
    changeFrequency: "daily",
    priority: p === "/" ? 1 : 0.7
  }));
}
