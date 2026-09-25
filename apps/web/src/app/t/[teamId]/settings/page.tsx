"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { BotIcon, CopyIcon, TriangleAlertIcon, GitBranchIcon, PlugIcon, RefreshCwIcon, SettingsIcon, SparklesIcon, Trash2Icon, WebhookIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Checkbox } from "@/components/ui/checkbox";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { useDeleteMe, useMe, useUpdateMe } from "@/hooks/use-me";
import {
  useMembers,
  useRemoveMember,
  useRotateTeamCode,
  useTeam,
  useUpdateMember,
  useUpdateTeam,
} from "@/hooks/use-teams";
import { repositoriesKey } from "@/hooks/use-github";
import { RepositoryLinker } from "@/components/github/repository-linker";
import { DatePicker } from "@/components/ui/date-picker";
import { formatInTimezone } from "@/lib/format-date";
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
import type { ClaudeCodeStatus, Me, Member, Team } from "@/types/api";

function copyToClipboard(text: string, message = "Copiado") {
  navigator.clipboard.writeText(text);
  toast.success(message);
}

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
      <PageHeader icon={SettingsIcon} title="Equipo y ajustes" />

      <TeamCodeCard teamId={teamId} code={team.code} formattedCode={team.formatted_code} isOwner={isOwner} />
      <HackathonCard teamId={teamId} team={team} isOwner={isOwner} />
      <MembersCard teamId={teamId} members={members ?? []} myUserId={me?.id} isOwner={isOwner} />
      <GitHubCard teamId={teamId} />
      {myMember && <ClaudeCodeCard teamId={teamId} formattedCode={team.formatted_code} member={myMember} />}
      {me && <GeminiApiKeyCard me={me} isOwner={isOwner} />}
      <ApiTokensCard teamId={teamId} members={members ?? []} isOwner={isOwner} />
      {isOwner && <IntegrationsCard teamId={teamId} />}
      {isOwner && <WebhooksCard teamId={teamId} />}
      <ConnectedAppsCard />
      {isOwner && <TeamConnectedAppsCard teamId={teamId} />}
      {me && <DeleteAccountCard email={me.email} />}
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
        <CardTitle className="text-base">Código de equipo</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-lg">{formattedCode}</span>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(code, "Código copiado")}>
          <CopyIcon className="size-3.5" /> Copiar código
        </Button>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(joinUrl, "Enlace copiado")}>
          <CopyIcon className="size-3.5" /> Copiar enlace
        </Button>
        {isOwner && (
          <Button variant="outline" size="sm" onClick={() => rotateCode.mutate()} disabled={rotateCode.isPending}>
            <RefreshCwIcon className="size-3.5" /> Regenerar
          </Button>
        )}
      </CardContent>
    </Card>
  );
}

// RF-TEAM-015: el owner puede cambiar el inicio y el fin del hackathon. Al
// mover el inicio, la API vuelve a importar el histórico de GitHub.
function HackathonCard({
  teamId,
  team,
  isOwner,
}: {
  teamId: string;
  team: Team;
  isOwner: boolean;
}) {
  const queryClient = useQueryClient();
  const updateTeam = useUpdateTeam(teamId);
  const [challengeText, setChallengeText] = useState(team.hackathon?.challenge_text ?? "");
  const [datesError, setDatesError] = useState<string | null>(null);
  const startsAt = team.hackathon?.starts_at ? new Date(team.hackathon.starts_at) : undefined;
  const endsAt = team.hackathon?.ends_at ? new Date(team.hackathon.ends_at) : undefined;

  function updateDate(field: "starts_at" | "ends_at", date: Date | undefined) {
    if (!date) return;
    setDatesError(null);
    updateTeam.mutate(
      { hackathon: { [field]: date.toISOString() } },
      {
        onSuccess: () => {
          if (field === "starts_at") queryClient.invalidateQueries({ queryKey: repositoriesKey(teamId) });
        },
        onError: (err) => setDatesError(err instanceof ApiError ? err.message : "No se ha podido guardar la fecha"),
      },
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Hackathon</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div>
          <Label>Nombre del hackathon</Label>
          <p className="text-base">{team.hackathon?.name}</p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="hackathon-starts-at">Inicio</Label>
            {isOwner ? (
              <DatePicker id="hackathon-starts-at" value={startsAt} onChange={(date) => updateDate("starts_at", date)} />
            ) : (
              <p className="text-base">{formatInTimezone(team.hackathon?.starts_at, team.hackathon?.timezone) || "Sin fecha"}</p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="hackathon-ends-at">Fin</Label>
            {isOwner ? (
              <DatePicker
                id="hackathon-ends-at"
                value={endsAt}
                onChange={(date) => updateDate("ends_at", date)}
                disabled={startsAt ? { before: startsAt } : undefined}
              />
            ) : (
              <p className="text-base">{formatInTimezone(team.hackathon?.ends_at, team.hackathon?.timezone) || "Sin fecha"}</p>
            )}
          </div>
        </div>
        {isOwner && (
          <p className="text-sm text-f1-foreground-secondary">
            Los commits de GitHub se importan desde el inicio. Si lo cambias, se vuelve a importar el histórico.
          </p>
        )}
        {datesError && <p className="text-base text-f1-foreground-critical">{datesError}</p>}
        <div>
          <Label>Zona horaria</Label>
          <p className="text-base">{team.hackathon?.timezone}</p>
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
        <CardTitle className="text-base">Miembros</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {members.map((member) => {
          const isMe = member.user_id === myUserId;
          return (
            <div key={member.id} className="flex items-center gap-3 rounded-md border border-f1-border p-2">
              <Avatar>
                <AvatarFallback>{member.display_name.slice(0, 2).toUpperCase()}</AvatarFallback>
              </Avatar>
              <span className="flex-1 text-base text-f1-foreground">{member.display_name}</span>
              <Badge variant={member.claude_code ? "positive" : "outline"}>
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
                  <Trash2Icon className="size-4" />
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
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <GitBranchIcon className="size-4" /> GitHub
        </CardTitle>
      </CardHeader>
      <CardContent>
        <RepositoryLinker teamId={teamId} />
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
        <CardTitle className="flex items-center gap-2 text-base">
          <BotIcon className="size-4" /> Claude Code (personal)
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {!link ? (
          <>
            <p className="text-muted-foreground text-base">
              No está conectado. Son dos pasos:
            </p>
            <ol className="text-muted-foreground list-inside list-decimal text-base">
              <li>
                <code className="font-mono">npm i -g hackboard</code>
              </li>
              <li>
                <code className="font-mono">hackboard init --team {formattedCode}</code>
              </li>
            </ol>
            <p className="text-muted-foreground text-sm">
              Esto registra tu Claude Code en este equipo y añade el hook que envía tu actividad. Se envían metadatos
              (qué archivo, qué comando, cuánto tardó) y, si eliges ese nivel de privacidad, un resumen corto — nunca
              el contenido de los archivos, diffs, ni el texto de tus prompts.
            </p>
          </>
        ) : (
          <>
            <div className="flex items-center gap-2 text-base">
              <Badge variant={link.paused ? "outline" : "positive"}>{link.paused ? "Pausado" : "Conectado"}</Badge>
              <span className="text-muted-foreground font-mono text-sm">{link.token_prefix}…</span>
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

            <p className="text-muted-foreground text-sm">
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
                  <Trash2Icon className="size-3.5" /> Desconectar
                </Button>
              ) : (
                <div className="flex flex-col gap-1.5 rounded-md border p-2">
                  <p className="text-sm">¿Solo desconectar, o también borrar tus eventos ya enviados?</p>
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

// RF-AI-021: clave personal de Gemini, de la cuenta (no del equipo). Se usa
// en los análisis y sugerencias de atribución que esa persona dispara, y —
// si es owner — también en lo automático del equipo (06-analisis-ia.md#proveedor).
function GeminiApiKeyCard({ me, isOwner }: { me: Me; isOwner: boolean }) {
  const update = useUpdateMe();
  const [value, setValue] = useState("");

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!value.trim()) return;
    try {
      await update.mutateAsync({ gemini_api_key: value.trim() });
      setValue("");
      toast.success("Clave de Gemini guardada");
    } catch {
      toast.error("No se ha podido guardar la clave");
    }
  }

  async function handleRemove() {
    try {
      await update.mutateAsync({ gemini_api_key: "" });
      toast.success("Clave de Gemini eliminada");
    } catch {
      toast.error("No se ha podido eliminar la clave");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <SparklesIcon className="size-4" /> IA (Gemini) — clave personal
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="flex items-center gap-2 text-base">
          <Badge variant={me.gemini_api_key_configured ? "positive" : "outline"}>
            {me.gemini_api_key_configured ? "Configurada" : "No configurada"}
          </Badge>
        </div>
        <p className="text-muted-foreground text-sm">
          Se usa para tus análisis bajo demanda (“Analizar ahora”, MCP o API){isOwner ? " y, como eres owner, también para el análisis programado y la atribución sugerida de este equipo" : ""}.
          Nunca se vuelve a mostrar en claro tras guardarla.
        </p>
        <form onSubmit={handleSave} className="flex gap-2">
          <Input
            type="password"
            placeholder={me.gemini_api_key_configured ? "Sustituir por una clave nueva" : "Pega tu clave de Gemini (AIza…)"}
            value={value}
            onChange={(e) => setValue(e.target.value)}
          />
          <Button type="submit" disabled={update.isPending || !value.trim()}>
            Guardar
          </Button>
          {me.gemini_api_key_configured && (
            <Button type="button" variant="outline" onClick={handleRemove} disabled={update.isPending}>
              Quitar
            </Button>
          )}
        </form>
      </CardContent>
    </Card>
  );
}

function RevealedToken({ label, token, apiUrl, onDismiss }: { label: string; token: string; apiUrl: string; onDismiss: () => void }) {
  const mcpCommand = `claude mcp add --transport http --scope local hackboard ${apiUrl}/api/v1/mcp --header "Authorization: Bearer ${token}"`;

  return (
    <div className="flex flex-col gap-2 rounded-md border border-f1-border-warning-bold bg-f1-background-warning p-3 text-base">
      <p className="font-medium">{label}: apúntalo ahora, no se vuelve a mostrar.</p>
      <div className="flex items-center gap-2">
        <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{token}</code>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(token, "Token copiado")}>
          <CopyIcon className="size-3.5" /> Copiar
        </Button>
      </div>
      <p className="text-muted-foreground text-sm">Para registrar el MCP en Claude Code:</p>
      <div className="flex items-center gap-2">
        <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{mcpCommand}</code>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(mcpCommand, "Comando copiado")}>
          <CopyIcon className="size-3.5" /> Copiar
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
        <CardTitle className="text-base">Mis tokens de acceso (API y MCP)</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealed && <RevealedToken label="Token" token={revealed} apiUrl={apiUrl} onDismiss={() => setRevealed(null)} />}

        {tokens?.map((token) => {
          const owner = members.find((m) => m.id === token.membership_id);
          return (
            <div key={token.id} className="flex flex-col gap-1 rounded-md border p-2 text-base">
              <div className="flex items-center gap-3">
                <span className="flex-1">
                  {token.name}
                  {isOwner && owner && <span className="text-muted-foreground"> · {owner.display_name}</span>}
                </span>
                <span className="text-muted-foreground font-mono text-sm">{token.token_prefix}…</span>
                <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(token.id)}>
                  <Trash2Icon className="size-4" />
                </Button>
              </div>
              <p className="text-muted-foreground text-sm">
                {token.scopes.join(", ")} · caduca {token.expires_at ? new Date(token.expires_at).toLocaleDateString() : "—"} ·
                último uso: {token.last_used_at ? new Date(token.last_used_at).toLocaleString() : "todavía ninguno"}
              </p>
            </div>
          );
        })}
        {tokens?.length === 0 && <p className="text-muted-foreground text-base">Todavía no tienes tokens.</p>}

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
        {error && <p className="text-destructive text-base">{error}</p>}
        <p className="text-muted-foreground text-sm">
          No lo subas a un repositorio ni lo compartas: da acceso a la API con los permisos elegidos.{" "}
          <a href={`${apiUrl}/api/v1/openapi.json`} target="_blank" rel="noreferrer" className="text-primary underline">
            Documentación OpenAPI
          </a>
        </p>

        <div className="flex flex-col gap-1.5 rounded-md border p-3">
          <p className="text-base font-medium">claude.ai (custom connector)</p>
          <div className="flex items-center gap-2">
            <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{apiUrl}/api/v1/mcp</code>
            <Button variant="outline" size="sm" onClick={() => copyToClipboard(`${apiUrl}/api/v1/mcp`, "URL copiada")}>
              <CopyIcon className="size-3.5" /> Copiar
            </Button>
          </div>
          <p className="text-muted-foreground text-sm">
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
        <CardTitle className="flex items-center gap-2 text-base">
          <PlugIcon className="size-4" /> Tokens de integración
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealed && <RevealedToken label="Token de integración" token={revealed} apiUrl={apiUrl} onDismiss={() => setRevealed(null)} />}

        {integrations?.map((integration) => (
          <div key={integration.id} className="flex items-center gap-3 rounded-md border p-2 text-base">
            <span className="flex-1">{integration.name}</span>
            <span className="text-muted-foreground font-mono text-sm">{integration.token_prefix}…</span>
            <span className="text-muted-foreground text-sm">{integration.scopes.join(", ")}</span>
            <Button variant="outline" size="sm" onClick={() => handleRotate(integration.id)}>
              Rotar
            </Button>
            <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(integration.id)}>
              <Trash2Icon className="size-4" />
            </Button>
          </div>
        ))}
        {integrations?.length === 0 && <p className="text-muted-foreground text-base">Todavía no hay integraciones.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2">
          <Input placeholder="Nombre (p. ej. Bot de Slack)" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="flex flex-wrap gap-2">
            {INTEGRATION_SCOPES.map((scope) => (
              <label key={scope} className="flex items-center gap-1.5 rounded-md border px-2 py-1 text-sm has-data-[checked]:border-primary">
                <Checkbox checked={scopes.includes(scope)} onCheckedChange={() => toggleScope(scope)} />
                {scope}
              </label>
            ))}
          </div>
          <Button type="submit" disabled={create.isPending} className="self-start">
            Crear integración
          </Button>
        </form>
        {error && <p className="text-destructive text-base">{error}</p>}
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
        <CardTitle className="flex items-center gap-2 text-base">
          <WebhookIcon className="size-4" /> Webhooks salientes
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealedSecret && (
          <div className="flex flex-col gap-2 rounded-md border border-f1-border-warning-bold bg-f1-background-warning p-3 text-base">
            <p className="font-medium">Secreto de firma: apúntalo ahora, no se vuelve a mostrar.</p>
            <div className="flex items-center gap-2">
              <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{revealedSecret}</code>
              <Button variant="outline" size="sm" onClick={() => copyToClipboard(revealedSecret, "Secreto copiado")}>
                <CopyIcon className="size-3.5" /> Copiar
              </Button>
            </div>
            <Button variant="ghost" size="sm" className="self-start" onClick={() => setRevealedSecret(null)}>
              Ya lo he guardado
            </Button>
          </div>
        )}

        {webhooks?.map((webhook) => (
          <div key={webhook.id} className="flex flex-col gap-2 rounded-md border p-2 text-base">
            <div className="flex items-center gap-2">
              <Badge variant={webhook.active ? "positive" : "outline"}>{webhook.active ? "Activo" : "Pausado"}</Badge>
              <span className="flex-1 truncate">{webhook.url}</span>
              <Button
                variant="ghost"
                size="icon"
                aria-label={webhook.active ? "Pausar" : "Reanudar"}
                onClick={() => update.mutate({ id: webhook.id, active: !webhook.active })}
              >
                <RefreshCwIcon className="size-4" />
              </Button>
              <Button variant="ghost" size="icon" aria-label="Eliminar" onClick={() => remove.mutate(webhook.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">{webhook.events.join(", ")}</p>
            {webhook.consecutive_failures > 0 && (
              <p className="text-destructive text-sm">{webhook.consecutive_failures} fallos seguidos</p>
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
        {webhooks?.length === 0 && <p className="text-muted-foreground text-base">Todavía no hay webhooks.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2">
          <Input placeholder="https://…" value={url} onChange={(e) => setUrl(e.target.value)} />
          <div className="flex flex-wrap gap-2">
            {WEBHOOK_EVENTS.map((event) => (
              <label key={event} className="flex items-center gap-1.5 rounded-md border px-2 py-1 text-sm has-data-[checked]:border-primary">
                <Checkbox checked={events.includes(event)} onCheckedChange={() => toggleEvent(event)} />
                {event}
              </label>
            ))}
          </div>
          <Button type="submit" disabled={create.isPending} className="self-start">
            Crear webhook
          </Button>
        </form>
        {error && <p className="text-destructive text-base">{error}</p>}
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
        <div key={delivery.id} className="flex items-center gap-2 text-sm">
          <Badge variant={delivery.status === "succeeded" ? "positive" : "destructive"}>{delivery.status}</Badge>
          <span className="flex-1">{delivery.event}</span>
          <span className="text-muted-foreground">{delivery.response_status ?? "—"}</span>
          <Button variant="ghost" size="sm" onClick={() => redeliver.mutate({ webhookId, deliveryId: delivery.id })}>
            Reenviar
          </Button>
        </div>
      ))}
      {deliveries?.length === 0 && <p className="text-muted-foreground text-sm">Todavía no hay entregas.</p>}
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
        <CardTitle className="text-base">Apps conectadas</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {connections?.map((connection) => (
          <div key={connection.id} className="flex flex-col gap-1 rounded-md border p-2 text-base">
            <div className="flex items-center gap-3">
              <span className="flex-1">
                {connection.client.name ?? "App desconocida"}
                {!connection.client.first_party && (
                  <Badge variant="warning" className="ml-2">
                    No verificada
                  </Badge>
                )}
              </span>
              <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(connection.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">
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
        <CardTitle className="text-base">Apps conectadas (equipo)</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {connections?.map((connection) => (
          <div key={connection.id} className="flex flex-col gap-1 rounded-md border p-2 text-base">
            <div className="flex items-center gap-3">
              <span className="flex-1">
                {connection.client.name ?? "App desconocida"}
                {!connection.client.first_party && (
                  <Badge variant="warning" className="ml-2">
                    No verificada
                  </Badge>
                )}
              </span>
              <span className="text-muted-foreground text-sm">{connection.user.display_name ?? "—"}</span>
              <Button variant="ghost" size="icon" aria-label="Revocar" onClick={() => revoke.mutate(connection.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">
              {connection.scopes.join(", ")} · autorizada el {new Date(connection.created_at).toLocaleDateString()} · último
              uso: {connection.last_used_at ? new Date(connection.last_used_at).toLocaleString() : "todavía ninguno"}
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}

// RF-AUTH-007 / RF-SEC-004: borrar la cuenta. Es irreversible, así que se
// confirma escribiendo el email de la cuenta, no con un simple sí/no.
function DeleteAccountCard({ email }: { email: string }) {
  const router = useRouter();
  const deleteMe = useDeleteMe();
  const [open, setOpen] = useState(false);
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const confirmed = confirmation.trim().toLowerCase() === email.toLowerCase();

  function handleOpenChange(next: boolean) {
    if (deleteMe.isPending) return;
    setOpen(next);
    if (!next) {
      setConfirmation("");
      setError(null);
    }
  }

  async function handleDelete(e: React.FormEvent) {
    e.preventDefault();
    if (!confirmed) return;
    setError(null);
    try {
      await deleteMe.mutateAsync();
      toast.success("Tu cuenta se ha borrado");
      router.replace("/login");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido borrar la cuenta");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <TriangleAlertIcon className="size-4" /> Borrar cuenta
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="text-muted-foreground text-sm">
          Borra tu cuenta y tus datos personales en todos tus equipos. Si eres el único owner de un equipo con más
          miembros, antes tienes que pasarle la propiedad a otro. Más detalles en la{" "}
          <Link href="/privacy" className="text-foreground underline">
            política de privacidad
          </Link>
          .
        </p>
        <div>
          <Button variant="destructive" onClick={() => setOpen(true)}>
            Borrar cuenta
          </Button>
        </div>
      </CardContent>

      <AlertDialog open={open} onOpenChange={handleOpenChange}>
        <AlertDialogContent>
          <form onSubmit={handleDelete} className="flex flex-col gap-4">
            <AlertDialogHeader>
              <AlertDialogTitle>Borrar tu cuenta</AlertDialogTitle>
              <AlertDialogDescription>
                No se puede deshacer. Se borran tu perfil, tus sesiones, tus tokens y apps conectadas, tu clave de Gemini
                y tu actividad de Claude Code. En la actividad de GitHub pasarás a aparecer como «Usuario eliminado». Los
                equipos en los que eres el único miembro se eliminan.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="delete-account-confirmation">
                Escribe <span className="text-foreground font-semibold">{email}</span> para confirmar
              </Label>
              <Input
                id="delete-account-confirmation"
                type="email"
                autoComplete="off"
                value={confirmation}
                onChange={(e) => setConfirmation(e.target.value)}
                disabled={deleteMe.isPending}
              />
            </div>
            {error && (
              <p role="alert" className="text-destructive text-base">
                {error}
              </p>
            )}
            <AlertDialogFooter>
              <AlertDialogCancel disabled={deleteMe.isPending}>Cancelar</AlertDialogCancel>
              <AlertDialogAction type="submit" variant="destructive" disabled={!confirmed} loading={deleteMe.isPending}>
                Borrar cuenta
              </AlertDialogAction>
            </AlertDialogFooter>
          </form>
        </AlertDialogContent>
      </AlertDialog>
    </Card>
  );
}
