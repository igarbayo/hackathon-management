import type { MetadataRoute } from "next";
import { BRAND_COLOR, SITE_DESCRIPTION, SITE_NAME } from "@/lib/site";

// RF-UX-043: web app manifest with the logo icons (public/icons/).
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: SITE_NAME,
    short_name: SITE_NAME,
    description: SITE_DESCRIPTION,
    lang: "en",
    start_url: "/",
    display: "standalone",
    background_color: "#FFFFFF",
    theme_color: BRAND_COLOR,
    icons: [
      { src: "/icon.svg", type: "image/svg+xml", sizes: "any" },
      { src: "/icons/icon-192.png", type: "image/png", sizes: "192x192" },
      { src: "/icons/icon-512.png", type: "image/png", sizes: "512x512" },
      { src: "/icons/icon-maskable-512.png", type: "image/png", sizes: "512x512", purpose: "maskable" },
    ],
  };
}
