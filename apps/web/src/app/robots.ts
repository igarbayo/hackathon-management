import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

// RF-UX-043: only public pages can be indexed. The team area, onboarding,
// OAuth consent and CLI approval are private.
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/login", "/signup", "/privacy", "/llms.txt"],
      disallow: ["/t/", "/onboarding", "/oauth/", "/cli/"],
    },
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
