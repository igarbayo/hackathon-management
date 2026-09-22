import type { Metadata } from "next";
import { Geist_Mono, Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";

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

export const metadata: Metadata = {
  title: {
    default: "Hackboard",
    template: "%s · Hackboard",
  },
  description:
    "Gestión de equipos de hackathon: objetivos, features, deadlines y actividad.",
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
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
