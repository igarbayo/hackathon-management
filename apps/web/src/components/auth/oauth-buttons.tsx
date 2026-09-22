import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

// RF-AUTH-010: "Continuar con Google" y "Continuar con GitHub" encima del
// formulario de email. Es una navegación de página completa (no fetch):
// el servidor tiene que ver la petición para fijar el state firmado.
// Se estiliza el <a> directamente en vez de envolverlo en Button: Base UI
// desaconseja renderizar enlaces a través del botón (tienen semántica propia).
export function OAuthButtons() {
  return (
    <div className="flex flex-col gap-2">
      <a href={`${API_URL}/api/v1/auth/google`} className={cn(buttonVariants({ variant: "outline" }))}>
        Continuar con Google
      </a>
      <a href={`${API_URL}/api/v1/auth/github`} className={cn(buttonVariants({ variant: "outline" }))}>
        Continuar con GitHub
      </a>
    </div>
  );
}
