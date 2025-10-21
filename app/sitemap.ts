import type { MetadataRoute } from "next";
export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://truvern.com";
  return [
    { url: `${base}/`,        changeFrequency: "weekly",  priority: 1.0 },
    { url: `${base}/trust`,   changeFrequency: "weekly",  priority: 0.8 },
    { url: `${base}/compare`, changeFrequency: "monthly", priority: 0.6 },
    { url: `${base}/docs`,    changeFrequency: "monthly", priority: 0.6 }
  ];
}
