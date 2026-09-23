import type { Metadata, Viewport } from "next";
import { Geist_Mono, Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";
import { BRAND_COLOR, BRAND_COLOR_DARK, SITE_DESCRIPTION, SITE_NAME, SITE_TAGLINE, SITE_URL } from "@/lib/site";

// F0 usa Inter en los pesos 400/500/600 (packages/core/src/tokens/typography.ts).
const inter = Inter({
  variable: "--font-inter",
  weight: ["400", "500", "600"],
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// RF-UX-040: metadata base del sitio. Los iconos (favicon.ico, icon.svg,
// apple-icon.png) y la imagen OG (opengraph-image.tsx) salen de las
// convenciones de ficheros de app/, así que no se repiten aquí.
export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${SITE_NAME} · ${SITE_TAGLINE}`,
    template: `%s · ${SITE_NAME}`,
  },
  description: SITE_DESCRIPTION,
  applicationName: SITE_NAME,
  keywords: [
    "hackathon",
    "gestión de equipos",
    "kanban",
    "objetivos",
    "deadlines",
    "GitHub",
    "Claude Code",
    "MCP",
    "análisis con IA",
  ],
  authors: [{ name: "Ignacio Garbayo" }],
  creator: "Ignacio Garbayo",
  category: "productivity",
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    locale: "es_ES",
    url: "/",
    siteName: SITE_NAME,
    title: `${SITE_NAME} · ${SITE_TAGLINE}`,
    description: SITE_DESCRIPTION,
  },
  twitter: {
    card: "summary_large_image",
    title: `${SITE_NAME} · ${SITE_TAGLINE}`,
    description: SITE_DESCRIPTION,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large", "max-snippet": -1 },
  },
  formatDetection: { telephone: false, email: false, address: false },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: BRAND_COLOR },
    { media: "(prefers-color-scheme: dark)", color: BRAND_COLOR_DARK },
  ],
};

// RF-UX-042: datos estructurados (schema.org) de la organización, el sitio y
// la aplicación, en todas las páginas.
const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": `${SITE_URL}/#organization`,
      name: SITE_NAME,
      url: SITE_URL,
      logo: { "@type": "ImageObject", url: `${SITE_URL}/icons/icon-512.png`, width: 512, height: 512 },
    },
    {
      "@type": "WebSite",
      "@id": `${SITE_URL}/#website`,
      url: SITE_URL,
      name: SITE_NAME,
      description: SITE_DESCRIPTION,
      inLanguage: "es",
      publisher: { "@id": `${SITE_URL}/#organization` },
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}/#app`,
      name: SITE_NAME,
      url: SITE_URL,
      description: SITE_DESCRIPTION,
      applicationCategory: "BusinessApplication",
      applicationSubCategory: "Project management",
      operatingSystem: "Web",
      inLanguage: "es",
      image: `${SITE_URL}/opengraph-image`,
      offers: { "@type": "Offer", price: "0", priceCurrency: "EUR" },
      featureList: [
        "Objetivos del reto y cobertura por features",
        "Kanban de features con pros y contras votados",
        "Milestones y cuenta atrás de deadlines",
        "Feed de actividad de GitHub y Claude Code",
        "Análisis de cobertura con IA (Gemini)",
        "API REST, servidor MCP y OAuth 2.1",
      ],
      publisher: { "@id": `${SITE_URL}/#organization` },
    },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="es"
      className={`${inter.variable} ${geistMono.variable} h-full antialiased`}
      // next-themes cambia `class` y `style` en el cliente antes del primer
      // pintado; sin esto, React avisa de un mismatch de hidratación en cada
      // carga aunque el resultado final sea correcto.
      suppressHydrationWarning
    >
      <body className="min-h-full flex flex-col">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }}
        />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
