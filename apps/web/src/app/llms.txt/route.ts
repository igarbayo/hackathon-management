import { SITE_DESCRIPTION, SITE_NAME, SITE_TAGLINE, SITE_URL } from "@/lib/site";

// RF-UX-044: llms.txt (https://llmstxt.org) para que un LLM o un agente sepa
// qué es Hackboard y dónde están sus puntos de entrada públicos, incluidos la
// API y el servidor MCP (specs/12-acceso-programatico.md).
export const dynamic = "force-static";

const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001").replace(/\/+$/, "");

export function GET() {
  const body = `# ${SITE_NAME}

> ${SITE_TAGLINE}. ${SITE_DESCRIPTION}

Hackboard está pensado para equipos de 2 a 6 personas durante un hackathon. Deduce el estado del trabajo de la actividad real (commits, PRs y sesiones de Claude Code) en vez de pedir que se actualice a mano, y lo contrasta con los objetivos del reto. La interfaz está en español.

Principios: cero trabajo administrativo; privacidad por defecto (nunca se guardan diffs, contenido de ficheros ni texto de prompts); la IA propone y un humano decide; lo determinista va antes que la IA.

## Qué hace

- Objetivos del reto y matriz de cobertura objetivos × features.
- Features en un kanban (idea, en curso, hecha, descartada) con pros y contras votados.
- Milestones y cuenta atrás al siguiente deadline.
- Feed de actividad de GitHub (GitHub App) y de Claude Code (CLI \`hackboard\` con hooks opcionales, persona a persona).
- Atribución automática de commits y sesiones a features.
- Análisis de cobertura con IA (Gemini, con la clave de cada persona) y alertas deterministas.

## Web

- [Crear cuenta](${SITE_URL}/signup): registro con Google, GitHub o email.
- [Entrar](${SITE_URL}/login): acceso a los equipos del usuario.

## Acceso programático

- [OpenAPI](${API_URL}/api/v1/openapi.json): especificación de la API REST. Autenticación con tokens de acceso personal (\`hb_pat_\`), de integración (\`hb_it_\`) u OAuth 2.1; todo va acotado a un equipo.
- [Servidor MCP](${API_URL}/api/v1/mcp): JSON-RPC 2.0 sobre HTTP con herramientas de lectura y escritura (features, objetivos, milestones, actividad, análisis). Se puede añadir como custom connector en claude.ai.
- [OAuth 2.1 discovery](${API_URL}/.well-known/oauth-authorization-server): metadatos del servidor de autorización (PKCE S256 obligatorio, registro dinámico de clientes).

## Optional

- [Sitemap](${SITE_URL}/sitemap.xml)
`;

  return new Response(body, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
