import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

// RF-UX-043: solo las páginas públicas son indexables. El área de equipo,
// onboarding, el consentimiento OAuth y la aprobación del CLI son privadas.
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
