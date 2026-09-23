// Datos públicos del sitio para SEO (metadata, JSON-LD, sitemap, robots,
// manifest, OG image). Ver specs/04-pantallas.md, RF-UX-040…044.
export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL ?? "https://hackboard.ignaciogarbayo.com").replace(/\/+$/, "");

export const SITE_NAME = "Hackboard";

export const SITE_TAGLINE = "El tablero de tu equipo de hackathon";

export const SITE_DESCRIPTION =
  "Gestión para equipos de hackathon: objetivos del reto, features en kanban, pros y contras, deadlines, " +
  "feed de actividad de GitHub y Claude Code, y análisis de cobertura con IA.";

// Morado de los logos (public/logo-*.svg) y su versión oscura del logo negativo.
export const BRAND_COLOR = "#5E3A8C";
export const BRAND_COLOR_DARK = "#2A1A40";

// Metadata de una página pública. Next fusiona `openGraph`/`twitter` de forma
// superficial: si una página define el suyo, pierde la imagen OG y el resto
// de campos del layout raíz, así que se rellenan completos aquí.
export function publicPageMetadata({ title, description, path }: { title: string; description: string; path: string }) {
  const fullTitle = `${title} · ${SITE_NAME}`;
  const image = { url: "/opengraph-image", width: 1200, height: 630, alt: `${SITE_NAME} · ${SITE_TAGLINE}` };
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "website" as const,
      locale: "es_ES",
      siteName: SITE_NAME,
      url: path,
      title: fullTitle,
      description,
      images: [image],
    },
    twitter: { card: "summary_large_image" as const, title: fullTitle, description, images: [image] },
  };
}
