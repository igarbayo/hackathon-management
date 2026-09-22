"use client";

import { use, useState } from "react";
import { Bot, Copy, GitBranch, RefreshCw, Trash2 } from "lucide-react";
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
import { ApiError } from "@/lib/api-client";
import type { ClaudeCodeStatus, Member } from "@/types/api";

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
      {myMember && <ClaudeCodeCard teamId={teamId} member={myMember} />}
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
function ClaudeCodeCard({ teamId, member }: { teamId: string; member: Member }) {
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
              No está conectado. Instala el CLI y ejecuta <code className="font-mono">hackboard init --team {teamId}</code> para
              enviar tu actividad de Claude Code a este equipo.
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
