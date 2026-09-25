import type { Metadata } from "next";

// RF-UX-043: private area, kept out of search engines.
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default function TeamAreaLayout({ children }: { children: React.ReactNode }) {
  return children;
}
