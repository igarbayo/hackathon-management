import type { Metadata } from "next";
import { publicPageMetadata } from "@/lib/site";

export const metadata: Metadata = publicPageMetadata({
  title: "Crear cuenta",
  description:
    "Crea tu cuenta de Hackboard gratis y monta el tablero de tu equipo de hackathon en menos de 2 minutos.",
  path: "/signup",
});

export default function SignupLayout({ children }: { children: React.ReactNode }) {
  return children;
}
