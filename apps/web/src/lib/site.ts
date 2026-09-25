// Public site data for SEO (metadata, JSON-LD, sitemap, robots,
// manifest, OG image). See specs/04-pantallas.md, RF-UX-040…044.
export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL ?? "https://hackboard.ignaciogarbayo.com").replace(/\/+$/, "");

export const SITE_NAME = "Hackboard";

export const SITE_TAGLINE = "The board for your hackathon team";

export const SITE_DESCRIPTION =
  "Management for hackathon teams: challenge objectives, a feature kanban, pros and cons, deadlines, " +
  "an activity feed from GitHub and Claude Code, and AI coverage analysis.";

// Purple from the logos (public/logo-*.svg) and the dark one behind the negative logo.
export const BRAND_COLOR = "#5E3A8C";
export const BRAND_COLOR_DARK = "#2A1A40";

// Metadata for a public page. Next merges `openGraph`/`twitter` shallowly:
// if a page sets its own, it loses the OG image and the other fields from
// the root layout, so they are all filled in here.
export function publicPageMetadata({ title, description, path }: { title: string; description: string; path: string }) {
  const fullTitle = `${title} · ${SITE_NAME}`;
  const image = { url: "/opengraph-image", width: 1200, height: 630, alt: `${SITE_NAME} · ${SITE_TAGLINE}` };
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "website" as const,
      locale: "en_US",
      siteName: SITE_NAME,
      url: path,
      title: fullTitle,
      description,
      images: [image],
    },
    twitter: { card: "summary_large_image" as const, title: fullTitle, description, images: [image] },
  };
}
