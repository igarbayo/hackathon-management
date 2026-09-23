import type { Metadata } from "next";
import { publicPageMetadata } from "@/lib/site";

export const metadata: Metadata = publicPageMetadata({
  title: "Entrar",
  description: "Entra en Hackboard con Google, GitHub o tu email para ver el tablero de tu equipo de hackathon.",
  path: "/login",
});

export default function LoginLayout({ children }: { children: React.ReactNode }) {
  return children;
}
