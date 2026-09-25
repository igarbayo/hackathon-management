import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { BRAND_COLOR_DARK, SITE_DESCRIPTION, SITE_NAME, SITE_TAGLINE } from "@/lib/site";

// RF-UX-041: Open Graph / X image. It is built at build time from the negative
// logo (public/logo-horizontal-negativo-transparente.svg) on its own dark
// purple background. Satori does not understand Tailwind classes or the f1-*
// tokens, so colors here are inline styles (RNF-UI-001).
export const alt = `${SITE_NAME} · ${SITE_TAGLINE}`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const logoSvg = await readFile(join(process.cwd(), "public/logo-horizontal-negativo-transparente.svg"), "base64");
const logoSrc = `data:image/svg+xml;base64,${logoSvg}`;

export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 32,
          padding: 80,
          background: BRAND_COLOR_DARK,
          color: "#FFFFFF",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element -- Satori only understands <img> */}
        <img src={logoSrc} width={789} height={200} alt="" />
        <div style={{ fontSize: 40, fontWeight: 600, textAlign: "center" }}>{SITE_TAGLINE}</div>
        <div style={{ fontSize: 26, textAlign: "center", opacity: 0.75, maxWidth: 960, lineHeight: 1.4 }}>
          {SITE_DESCRIPTION}
        </div>
      </div>
    ),
    size,
  );
}
