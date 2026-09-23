import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

// RF-UX-043: las únicas rutas públicas de la web.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: SITE_URL, changeFrequency: "monthly", priority: 1 },
    { url: `${SITE_URL}/signup`, changeFrequency: "yearly", priority: 0.8 },
    { url: `${SITE_URL}/login`, changeFrequency: "yearly", priority: 0.5 },
  ];
}
