import { SITE_DESCRIPTION, SITE_NAME, SITE_TAGLINE, SITE_URL } from "@/lib/site";

// RF-UX-044: llms.txt (https://llmstxt.org) so an LLM or an agent knows what
// Hackboard is and where its public entry points are, including the API and
// the MCP server (specs/12-acceso-programatico.md).
export const dynamic = "force-static";

const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001").replace(/\/+$/, "");

export function GET() {
  const body = `# ${SITE_NAME}

> ${SITE_TAGLINE}. ${SITE_DESCRIPTION}

Hackboard is built for teams of 2 to 6 people during a hackathon. It works out the state of the work from real activity (commits, PRs and Claude Code sessions) instead of asking people to update it by hand, and compares it with the challenge objectives. The interface is in English.

Principles: zero admin work; privacy by default (diffs, file contents and prompt text are never stored); the AI suggests and a human decides; deterministic rules come before AI.

## What it does

- Challenge objectives and an objectives × features coverage matrix.
- Features on a kanban board (idea, in progress, done, dropped) with voted pros and cons.
- Milestones and a countdown to the next deadline.
- Activity feed from GitHub (GitHub App) and Claude Code (the \`hackboard\` CLI with optional hooks, set up per person).
- Automatic attribution of commits and sessions to features.
- AI coverage analysis (Gemini, with each person's own key) and deterministic alerts.

## Web

- [Sign up](${SITE_URL}/signup): sign up with Google, GitHub or email.
- [Log in](${SITE_URL}/login): access the user's teams.

## Programmatic access

- [OpenAPI](${API_URL}/api/v1/openapi.json): REST API specification. Authentication with personal access tokens (\`hb_pat_\`), integration tokens (\`hb_it_\`) or OAuth 2.1; everything is scoped to one team.
- [MCP server](${API_URL}/api/v1/mcp): JSON-RPC 2.0 over HTTP with read and write tools (features, objectives, milestones, activity, analysis). It can be added as a custom connector in claude.ai.
- [OAuth 2.1 discovery](${API_URL}/.well-known/oauth-authorization-server): authorization server metadata (PKCE S256 required, dynamic client registration).

## Optional

- [Sitemap](${SITE_URL}/sitemap.xml)
`;

  return new Response(body, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
