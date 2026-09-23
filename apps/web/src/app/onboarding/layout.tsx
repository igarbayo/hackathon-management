import type { Metadata } from "next";

// RF-UX-043: área privada, fuera de buscadores.
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default function OnboardingLayout({ children }: { children: React.ReactNode }) {
  return children;
}
