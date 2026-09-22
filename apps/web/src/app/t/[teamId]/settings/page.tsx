"use client";

import { use, useState } from "react";
import { Bot, Copy, GitBranch, Plug, RefreshCw, Trash2, Webhook as WebhookIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ErrorState, LoadingState } from "@/components/states";
import { useMe } from "@/hooks/use-me";
import {
  useMembers,
  useRemoveMember,
  useRotateTeamCode,
  useTeam,
  useUpdateMember,
  useUpdateTeam,
} from "@/hooks/use-teams";
import { useLinkRepository, useRepositories, useResyncRepository, useUnlinkRepository } from "@/hooks/use-github";
import { useDisconnectMyClaudeCode, useUpdateMyClaudeCode } from "@/hooks/use-claude-code";
import {
  useCreateIntegration,
  useCreateToken,
  useCreateWebhook,
  useDeleteWebhook,
  useIntegrations,
  useOAuthConnections,
  useRedeliverWebhook,
  useRevokeIntegration,
  useRevokeOAuthConnection,
  useRevokeTeamOAuthConnection,
  useRevokeToken,
  useRotateIntegration,
  useRotateWebhookSecret,
  useTeamOAuthConnections,
  useTestWebhook,
  useTokens,
  useUpdateWebhook,
  useWebhookDeliveries,
  useWebhooks,
} from "@/hooks/use-api-access";
import { ApiError } from "@/lib/api-client";
import type { ClaudeCodeStatus, Member } from "@/types/api";

const PAT_PRESETS = [
  { value: "observar", label: "Observar (solo lectura)" },
  { value: "agente", label: "Agente (lectura + mover features + progreso)" },
  { value: "completo", label: "Completo (todo salvo ingesta)" },
];

const INTEGRATION_SCOPES = [
  "read",
  "features:write",
  "objectives:write",
  "arguments:write",
  "milestones:write",
  "attribution:write",
  "analyses:run",
];

const WEBHOOK_EVENTS = [
  "feature.created",
  "feature.updated",
  "feature.status_changed",
  "feature.assigned",
  "objective.created",
  "objective.updated",
  "milestone.created",
  "milestone.updated",
  "milestone.due_soon",
  "activity.created",
  "analysis.succeeded",
];

export default function SettingsPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: me } = useMe();
  const { data: team, isLoading, isError, refetch } = useTeam(teamId);
  const { data: members } = useMembers(teamId);

  if (isLoading) return <LoadingState />;
  if (isError || !team) return <ErrorState onRetry={() => refetch()} />;

  const myRole = me?.memberships.find((m) => m.team_id === teamId)?.role;
  const isOwner = myRole === "owner";
  const myMember = members?.find((m) => m.user_id === me?.id);

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6">
      <h1 className="text-2xl font-semibold">Equipo y ajustes</h1>

      <TeamCodeCard teamId={teamId} code={team.code} formattedCode={team.formatted_code} isOwner={isOwner} />
      <HackathonCard teamId={teamId} team={team} isOwner={isOwner} />
      <MembersCard teamId={teamId} members={members ?? []} myUserId={me?.id} isOwner={isOwner} />
      <GitHubCard teamId={teamId} />
      {myMember && <ClaudeCodeCard teamId={teamId} formattedCode={team.formatted_code} member={myMember} />}
      <ApiTokensCard teamId={teamId} members={members ?? []} isOwner={isOwner} />
      {isOwner && <IntegrationsCard teamId={teamId} />}
      {isOwner && <WebhooksCard teamId={teamId} />}
      <ConnectedAppsCard />
      {isOwner && <TeamConnectedAppsCard teamId={teamId} />}
    </div>
  );
}

function TeamCodeCard({
  teamId,
  code,
  formattedCode,
  isOwner,
}: {
  teamId: string;
  code: string;
  formattedCode: string;
  isOwner: boolean;
}) {
  const rotateCode = useRotateTeamCode(teamId);
  const joinUrl = typeof window !== "undefined" ? `${window.location.origin}/onboarding?code=${code}` : "";

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Código de equipo</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-lg">{formattedCode}</span>
        <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(code)}>
          <Copy className="size-3.5" /> Copiar código
        </Button>
        <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(joinUrl)}>
          <Copy className="size-3.5" /> Copiar enlace
        </Button>
        {isOwner && (
          <Button variant="outline" size="sm" onClick={() => rotateCode.mutate()} disabled={rotateCode.isPending}>
            <RefreshCw className="size-3.5" /> Regenerar
          </Button>
        )}
      </CardContent>
    </Card>
  );
}

function HackathonCard({
  teamId,
  team,
  isOwner,
}: {
  teamId: string;
  team: { name: string; hackathon: { name: string; timezone: string; challenge_text: string | null } | null };
  isOwner: boolean;
}) {
  const updateTeam = useUpdateTeam(teamId);
  const [challengeText, setChallengeText] = useState(team.hackathon?.challenge_text ?? "");

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Hackathon</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div>
          <Label>Nombre del hackathon</Label>
          <p className="text-sm">{team.hackathon?.name}</p>
        </div>
        <div>
          <Label>Zona horaria</Label>
          <p className="text-sm">{team.hackathon?.timezone}</p>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="challenge">Texto del reto</Label>
          <Textarea
            id="challenge"
            disabled={!isOwner}
            rows={4}
            maxLength={10000}
            value={challengeText}
            onChange={(e) => setChallengeText(e.target.value)}
            onBlur={() => isOwner && updateTeam.mutate({ hackathon: { challenge_text: challengeText } })}
          />
        </div>
      </CardContent>
    </Card>
  );
}

function MembersCard({
  teamId,
  members,
  myUserId,
  isOwner,
}: {
  teamId: string;
  members: { id: string; user_id: string; role: string; display_name: string; claude_code: unknown }[];
  myUserId: string | undefined;
  isOwner: boolean;
}) {
  const updateMember = useUpdateMember(teamId);
  const removeMember = useRemoveMember(teamId);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Miembros</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {members.map((member) => {
          const isMe = member.user_id === myUserId;
          return (
            <div key={member.id} className="flex items-center gap-3 rounded-md border p-2">
              <div className="bg-muted flex size-8 items-center justify-center rounded-full text-xs">
                {member.display_name.slice(0, 2).toUpperCase()}
              </div>
              <span className="flex-1 text-sm">{member.display_name}</span>
              <Badge variant={member.claude_code ? "default" : "outline"}>
                {member.claude_code ? "Claude Code conectado" : "Claude Code no conectado"}
              </Badge>

              {isOwner ? (
                <Select value={member.role} onValueChange={(role) => updateMember.mutate({ memberId: member.id, role })}>
                  <SelectTrigger className="w-28">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="owner">Owner</SelectItem>
                    <SelectItem value="member">Member</SelectItem>
                  </SelectContent>
                </Select>
              ) : (
                <Badge variant="secondary">{member.role}</Badge>
              )}

              {(isOwner || isMe) && (
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label={isMe ? "Salir del equipo" : "Expulsar"}
                  onClick={() => removeMember.mutate(member.id)}
                >
                  <Trash2 className="size-4" />
                </Button>
              )}
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}

// RF-GH-010: repos vinculados, botón "Añadir repo" y estado de la instalación.
function GitHubCard({ teamId }: { teamId: string }) {
  const { data: repositories, isLoading } = useRepositories(teamId);
  const linkRepository = useLinkRepository(teamId);
  const unlinkRepository = useUnlinkRepository(teamId);
  const resyncRepository = useResyncRepository(teamId);
  const [input, setInput] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [installUrl, setInstallUrl] = useState<string | null>(null);

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!input.trim()) return;
    setError(null);
    setInstallUrl(null);

    try {
      const result = await linkRepository.mutateAsync(input.trim());
      if (result.needs_install && result.install_url) {
        setInstallUrl(result.install_url);
      } else {
        setInput("");
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido vincular el repositorio");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-sm">
          <GitBranch className="size-4" /> GitHub
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {isLoading && <p className="text-muted-foreground text-sm">Cargando…</p>}
        {repositories?.map((repo) => (
          <div key={repo.id} className="flex items-center gap-3 rounded-md border p-2 text-sm">
            <Badge variant="default">Conectado ✓</Badge>
            <span className="flex-1">{repo.full_name}</span>
            <span className="text-muted-foreground text-xs">{repo.default_branch}</span>
            <Button
              variant="ghost"
              size="icon"
              aria-label="Resincronizar"
              onClick={() => resyncRepository.mutate(repo.id)}
              disabled={resyncRepository.isPending}
            >
              <RefreshCw className="size-4" />
            </Button>
            <Button variant="ghost" size="icon" aria-label="Desvincular" onClick={() => unlinkRepository.mutate(repo.id)}>
              <Trash2 className="size-4" />
            </Button>
          </div>
        ))}
        {repositories?.length === 0 && <p className="text-muted-foreground text-sm">Todavía no hay repos vinculados.</p>}

        <form onSubmit={handleAdd} className="flex gap-2">
          <Input
            placeholder="org/repo o https://github.com/org/repo"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <Button type="submit" disabled={linkRepository.isPending}>
            Añadir repo
          </Button>
        </form>

        {error && <p className="text-destructive text-sm">{error}</p>}

        {installUrl && (
          <div className="rounded-md border p-2 text-sm">
            <p>Hace falta instalar la GitHub App para acceder a este repositorio.</p>
            <a href={installUrl} className="text-primary underline">
              Instalar la App en GitHub
            </a>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

// RF-CC-010: cada persona solo ve y toca su propio enlace, nunca el de otro
// miembro (es opt-in e individual, 08-integracion-claude-code.md).
function ClaudeCodeCard({
  teamId,
  formattedCode,
  member,
}: {
  teamId: string;
  formattedCode: string;
  member: Member;
}) {
  const update = useUpdateMyClaudeCode(teamId);
  const disconnect = useDisconnectMyClaudeCode(teamId);
  const [confirmingPurge, setConfirmingPurge] = useState(false);
  const link: ClaudeCodeStatus | null = member.claude_code;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-sm">
          <Bot className="size-4" /> Claude Code (personal)
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {!link ? (
          <>
            <p className="text-muted-foreground text-sm">
              No está conectado. Son dos pasos:
            </p>
            <ol className="text-muted-foreground list-inside list-decimal text-sm">
              <li>
                <code className="font-mono">npm i -g hackboard</code>
              </li>
              <li>
                <code className="font-mono">hackboard init --team {formattedCode}</code>
              </li>
            </ol>
            <p className="text-muted-foreground text-xs">
              Esto registra tu Claude Code en este equipo y añade el hook que envía tu actividad. Se envían metadatos
              (qué archivo, qué comando, cuánto tardó) y, si eliges ese nivel de privacidad, un resumen corto — nunca
              el contenido de los archivos, diffs, ni el texto de tus prompts.
            </p>
          </>
        ) : (
          <>
            <div className="flex items-center gap-2 text-sm">
              <Badge variant={link.paused ? "outline" : "default"}>{link.paused ? "Pausado" : "Conectado"}</Badge>
              <span className="text-muted-foreground font-mono text-xs">{link.token_prefix}…</span>
            </div>

            <div className="flex flex-col gap-1.5">
              <Label>Nivel de privacidad</Label>
              <Select
                value={link.privacy_level}
                onValueChange={(privacy_level) => privacy_level && update.mutate({ privacy_level })}
              >
                <SelectTrigger className="w-56">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="metadata">Metadata</SelectItem>
                  <SelectItem value="summaries">Metadata + resúmenes</SelectItem>
                  <SelectItem value="off">Desactivado</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <p className="text-muted-foreground text-xs">
              Último evento: {link.last_event_at ? new Date(link.last_event_at).toLocaleString() : "todavía ninguno"}
            </p>

            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => update.mutate({ paused: !link.paused })}
                disabled={update.isPending}
              >
                {link.paused ? "Reanudar" : "Pausar"}
              </Button>
              {!confirmingPurge ? (
                <Button variant="ghost" size="sm" onClick={() => setConfirmingPurge(true)}>
                  <Trash2 className="size-3.5" /> Desconectar
                </Button>
              ) : (
                <div className="flex flex-col gap-1.5 rounded-md border p-2">
                  <p className="text-xs">¿Solo desconectar, o también borrar tus eventos ya enviados?</p>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" onClick={() => disconnect.mutate(false)} disabled={disconnect.isPending}>
                      Solo desconectar
                    </Button>
                    <Button variant="destructive" size="sm" onClick={() => disconnect.mutate(true)} disabled={disconnect.isPending}>
                      Desconectar y borrar mis eventos
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => setConfirmingPurge(false)}>
                      Cancelar
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}

function RevealedToken({ label, token, apiUrl, onDismiss }: { label: string; token: string; apiUrl: string; onDismiss: () => void }) {
  const mcpCommand = `claude mcp add --transport http --scope local hackboard ${apiUrl}/api/v1/mcp --header "Authorization: Bearer ${token}"`;

  return (
    <div className="flex flex-col gap-2 rounded-md border border-primary p-3 text-sm">
      <p className="font-medium">{label}: apúntalo ahora, no se vuelve a mostrar.</p>
      <div className="flex items-center gap-2">
        <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-xs">{token}</code>
        <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(token)}>
          <Copy className="size-3.5" /> Copiar
        </Button>
      </div>
      <p className="text-muted-foreground text-xs">Para registrar el MCP en Claude Code:</p>
      <div className="flex items-center gap-2">
        <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-xs">{mcpCommand}</code>
        <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(mcpCommand)}>
          <Copy className="size-3.5" /> Copiar
        </Button>
      </div>
      <Button variant="ghost" size="sm" className="self-start" onClick={onDismiss}>
        Ya lo he guardado
      </Button>
    </div>
  );
}

// RF-API-001/RF-MCP-010/RF-API-020: PATs. Cualquier miembro crea los suyos;
// un owner ve además los del resto del equipo (ya viene así del backend,
// sin parámetro que pedirlo) y aquí se etiqueta de quién es cada uno.
function ApiTokensCard({ teamId, members, isOwner }: { teamId: string; members: Member[]; isOwner: boolean }) {
  const { data: tokens } = useTokens(teamId);
  const create = useCreateToken(teamId);
  const revoke = useRevokeToken(teamId);
  const [name, setName] = useState("");
  const [preset, setPreset] = useState("observar");
  const [error, setError] = useState<string | null>(null);
  const [revealed, setRevealed] = useState<string | null>(null);
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "";

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setError(null);
    try {
      const result = await create.mutateAsync({ name: name.trim(), preset });
      setRevealed(result.token);
      setName("");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido crear el token");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Mis tokens de acceso (API y MCP)</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealed && <RevealedToken label="Token" token={revealed} apiUrl={apiUrl} onDismiss={() => setRevealed(null)} />}

        {tokens?.map((token) => {
          const owner = members.find((m) => m.id === token.membership_id);
          return (
            <div key={token.id} className="flex flex-col gap-1 rounded-md border p-2 text-sm">
              <div className="flex items-center gap-3">
                <span className="flex-1">
                  {token.name}
                  {isOwner && owner && <span className="text-muted-foreground"> · {owner.display_name}</span>}
                </span>
                <span className="text-muted-foreground font-mono text-xs">{token.token_prefix}…</span>
                <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(token.id)}>
                  <Trash2 className="size-4" />
                </Button>
              </div>
              <p className="text-muted-foreground text-xs">
                {token.scopes.join(", ")} · caduca {token.expires_at ? new Date(token.expires_at).toLocaleDateString() : "—"} ·
                último uso: {token.last_used_at ? new Date(token.last_used_at).toLocaleString() : "todavía ninguno"}
              </p>
            </div>
          );
        })}
        {tokens?.length === 0 && <p className="text-muted-foreground text-sm">Todavía no tienes tokens.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2 sm:flex-row">
          <Input placeholder="Nombre (p. ej. Claude Code portátil)" value={name} onChange={(e) => setName(e.target.value)} className="flex-1" />
          <Select value={preset} onValueChange={(v) => v && setPreset(v)}>
            <SelectTrigger className="sm:w-64">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PAT_PRESETS.map((p) => (
                <SelectItem key={p.value} value={p.value}>
                  {p.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button type="submit" disabled={create.isPending}>
            Crear token
          </Button>
        </form>
        {error && <p className="text-destructive text-sm">{error}</p>}
        <p className="text-muted-foreground text-xs">
          No lo subas a un repositorio ni lo compartas: da acceso a la API con los permisos elegidos.{" "}
          <a href={`${apiUrl}/api/v1/openapi.json`} target="_blank" rel="noreferrer" className="text-primary underline">
            Documentación OpenAPI
          </a>
        </p>

        <div className="flex flex-col gap-1.5 rounded-md border p-3">
          <p className="text-sm font-medium">claude.ai (custom connector)</p>
          <div className="flex items-center gap-2">
            <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-xs">{apiUrl}/api/v1/mcp</code>
            <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(`${apiUrl}/api/v1/mcp`)}>
              <Copy className="size-3.5" /> Copiar
            </Button>
          </div>
          <p className="text-muted-foreground text-xs">
            En claude.ai: Ajustes → Connectors → Añadir custom connector, pega esta URL e inicia sesión cuando te lo pida.
            No hace falta copiar ningún token: claude.ai pedirá permiso con la pantalla de consentimiento. Las conexiones
            autorizadas aparecen en{" "}
            <a href="#apps-conectadas" className="text-primary underline">
              Apps conectadas
            </a>
            .
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

// RF-API-011/RF-API-023: solo owners. El actor de lo que hace es la integración.
function IntegrationsCard({ teamId }: { teamId: string }) {
  const { data: integrations } = useIntegrations(teamId);
  const create = useCreateIntegration(teamId);
  const revoke = useRevokeIntegration(teamId);
  const rotate = useRotateIntegration(teamId);
  const [name, setName] = useState("");
  const [scopes, setScopes] = useState<string[]>(["read"]);
  const [error, setError] = useState<string | null>(null);
  const [revealed, setRevealed] = useState<string | null>(null);
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "";

  function toggleScope(scope: string) {
    setScopes((current) => (current.includes(scope) ? current.filter((s) => s !== scope) : [...current, scope]));
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setError(null);
    try {
      const result = await create.mutateAsync({ name: name.trim(), scopes });
      setRevealed(result.token);
      setName("");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido crear la integración");
    }
  }

  async function handleRotate(id: string) {
    const result = await rotate.mutateAsync(id);
    setRevealed(result.token);
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-sm">
          <Plug className="size-4" /> Tokens de integración
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealed && <RevealedToken label="Token de integración" token={revealed} apiUrl={apiUrl} onDismiss={() => setRevealed(null)} />}

        {integrations?.map((integration) => (
          <div key={integration.id} className="flex items-center gap-3 rounded-md border p-2 text-sm">
            <span className="flex-1">{integration.name}</span>
            <span className="text-muted-foreground font-mono text-xs">{integration.token_prefix}…</span>
            <span className="text-muted-foreground text-xs">{integration.scopes.join(", ")}</span>
            <Button variant="outline" size="sm" onClick={() => handleRotate(integration.id)}>
              Rotar
            </Button>
            <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(integration.id)}>
              <Trash2 className="size-4" />
            </Button>
          </div>
        ))}
        {integrations?.length === 0 && <p className="text-muted-foreground text-sm">Todavía no hay integraciones.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2">
          <Input placeholder="Nombre (p. ej. Bot de Slack)" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="flex flex-wrap gap-2">
            {INTEGRATION_SCOPES.map((scope) => (
              <label key={scope} className="flex items-center gap-1.5 rounded-md border px-2 py-1 text-xs has-[:checked]:border-primary">
                <input type="checkbox" checked={scopes.includes(scope)} onChange={() => toggleScope(scope)} />
                {scope}
              </label>
            ))}
          </div>
          <Button type="submit" disabled={create.isPending} className="self-start">
            Crear integración
          </Button>
        </form>
        {error && <p className="text-destructive text-sm">{error}</p>}
      </CardContent>
    </Card>
  );
}

// RF-API-009: webhooks salientes, solo owners.
function WebhooksCard({ teamId }: { teamId: string }) {
  const { data: webhooks } = useWebhooks(teamId);
  const create = useCreateWebhook(teamId);
  const update = useUpdateWebhook(teamId);
  const remove = useDeleteWebhook(teamId);
  const test = useTestWebhook(teamId);
  const rotateSecret = useRotateWebhookSecret(teamId);
  const [url, setUrl] = useState("");
  const [events, setEvents] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [revealedSecret, setRevealedSecret] = useState<string | null>(null);
  const [openDeliveries, setOpenDeliveries] = useState<string | null>(null);

  function toggleEvent(event: string) {
    setEvents((current) => (current.includes(event) ? current.filter((e) => e !== event) : [...current, event]));
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!url.trim() || events.length === 0) return;
    setError(null);
    try {
      const result = await create.mutateAsync({ url: url.trim(), events });
      setRevealedSecret(result.secret);
      setUrl("");
      setEvents([]);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido crear el webhook");
    }
  }

  async function handleRotate(id: string) {
    const result = await rotateSecret.mutateAsync(id);
    setRevealedSecret(result.secret);
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-sm">
          <WebhookIcon className="size-4" /> Webhooks salientes
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealedSecret && (
          <div className="flex flex-col gap-2 rounded-md border border-primary p-3 text-sm">
            <p className="font-medium">Secreto de firma: apúntalo ahora, no se vuelve a mostrar.</p>
            <div className="flex items-center gap-2">
              <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-xs">{revealedSecret}</code>
              <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(revealedSecret)}>
                <Copy className="size-3.5" /> Copiar
              </Button>
            </div>
            <Button variant="ghost" size="sm" className="self-start" onClick={() => setRevealedSecret(null)}>
              Ya lo he guardado
            </Button>
          </div>
        )}

        {webhooks?.map((webhook) => (
          <div key={webhook.id} className="flex flex-col gap-2 rounded-md border p-2 text-sm">
            <div className="flex items-center gap-2">
              <Badge variant={webhook.active ? "default" : "outline"}>{webhook.active ? "Activo" : "Pausado"}</Badge>
              <span className="flex-1 truncate">{webhook.url}</span>
              <Button
                variant="ghost"
                size="icon"
                aria-label={webhook.active ? "Pausar" : "Reanudar"}
                onClick={() => update.mutate({ id: webhook.id, active: !webhook.active })}
              >
                <RefreshCw className="size-4" />
              </Button>
              <Button variant="ghost" size="icon" aria-label="Eliminar" onClick={() => remove.mutate(webhook.id)}>
                <Trash2 className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-xs">{webhook.events.join(", ")}</p>
            {webhook.consecutive_failures > 0 && (
              <p className="text-destructive text-xs">{webhook.consecutive_failures} fallos seguidos</p>
            )}
            <div className="flex gap-2">
              <Button variant="outline" size="sm" onClick={() => test.mutate(webhook.id)} disabled={test.isPending}>
                Probar
              </Button>
              <Button variant="outline" size="sm" onClick={() => handleRotate(webhook.id)}>
                Rotar secreto
              </Button>
              <Button variant="outline" size="sm" onClick={() => setOpenDeliveries(openDeliveries === webhook.id ? null : webhook.id)}>
                Ver entregas
              </Button>
            </div>
            {openDeliveries === webhook.id && <WebhookDeliveries teamId={teamId} webhookId={webhook.id} />}
          </div>
        ))}
        {webhooks?.length === 0 && <p className="text-muted-foreground text-sm">Todavía no hay webhooks.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2">
          <Input placeholder="https://…" value={url} onChange={(e) => setUrl(e.target.value)} />
          <div className="flex flex-wrap gap-2">
            {WEBHOOK_EVENTS.map((event) => (
              <label key={event} className="flex items-center gap-1.5 rounded-md border px-2 py-1 text-xs has-[:checked]:border-primary">
                <input type="checkbox" checked={events.includes(event)} onChange={() => toggleEvent(event)} />
                {event}
              </label>
            ))}
          </div>
          <Button type="submit" disabled={create.isPending} className="self-start">
            Crear webhook
          </Button>
        </form>
        {error && <p className="text-destructive text-sm">{error}</p>}
      </CardContent>
    </Card>
  );
}

function WebhookDeliveries({ teamId, webhookId }: { teamId: string; webhookId: string }) {
  const { data: deliveries } = useWebhookDeliveries(teamId, webhookId);
  const redeliver = useRedeliverWebhook(teamId);

  return (
    <div className="flex flex-col gap-1 rounded-md bg-muted/50 p-2">
      {deliveries?.map((delivery) => (
        <div key={delivery.id} className="flex items-center gap-2 text-xs">
          <Badge variant={delivery.status === "succeeded" ? "default" : "outline"}>{delivery.status}</Badge>
          <span className="flex-1">{delivery.event}</span>
          <span className="text-muted-foreground">{delivery.response_status ?? "—"}</span>
          <Button variant="ghost" size="sm" onClick={() => redeliver.mutate({ webhookId, deliveryId: delivery.id })}>
            Reenviar
          </Button>
        </div>
      ))}
      {deliveries?.length === 0 && <p className="text-muted-foreground text-xs">Todavía no hay entregas.</p>}
    </div>
  );
}

// RF-API-021: "Apps conectadas" no es por equipo, es de la cuenta. Se
// muestra aquí igualmente por simplicidad, ya que hoy no hay una pantalla
// de ajustes de cuenta aparte de los ajustes de equipo.
function ConnectedAppsCard() {
  const { data: connections } = useOAuthConnections();
  const revoke = useRevokeOAuthConnection();

  if (connections?.length === 0) return null;

  return (
    <Card id="apps-conectadas">
      <CardHeader>
        <CardTitle className="text-sm">Apps conectadas</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {connections?.map((connection) => (
          <div key={connection.id} className="flex flex-col gap-1 rounded-md border p-2 text-sm">
            <div className="flex items-center gap-3">
              <span className="flex-1">
                {connection.client.name ?? "App desconocida"}
                {!connection.client.first_party && (
                  <Badge variant="outline" className="ml-2 text-xs">
                    no verificada
                  </Badge>
                )}
              </span>
              <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(connection.id)}>
                <Trash2 className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-xs">
              {connection.scopes.join(", ")} · autorizada el {new Date(connection.created_at).toLocaleDateString()} · último
              uso: {connection.last_used_at ? new Date(connection.last_used_at).toLocaleString() : "todavía ninguno"}
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}

// RF-API-021: "un owner ve las de todo el equipo y puede revocarlas" — a
// diferencia de ConnectedAppsCard (mis apps), esta muestra las de
// cualquier miembro del equipo.
function TeamConnectedAppsCard({ teamId }: { teamId: string }) {
  const { data: connections } = useTeamOAuthConnections(teamId);
  const revoke = useRevokeTeamOAuthConnection(teamId);

  if (connections?.length === 0) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Apps conectadas (equipo)</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {connections?.map((connection) => (
          <div key={connection.id} className="flex flex-col gap-1 rounded-md border p-2 text-sm">
            <div className="flex items-center gap-3">
              <span className="flex-1">
                {connection.client.name ?? "App desconocida"}
                {!connection.client.first_party && (
                  <Badge variant="outline" className="ml-2 text-xs">
                    no verificada
                  </Badge>
                )}
              </span>
              <span className="text-muted-foreground text-xs">{connection.user.display_name ?? "—"}</span>
              <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(connection.id)}>
                <Trash2 className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-xs">
              {connection.scopes.join(", ")} · autorizada el {new Date(connection.created_at).toLocaleDateString()} · último
              uso: {connection.last_used_at ? new Date(connection.last_used_at).toLocaleString() : "todavía ninguno"}
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
