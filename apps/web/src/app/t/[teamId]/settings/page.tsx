"use client";

import { use, useState } from "react";
import { Copy, RefreshCw, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
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

export default function SettingsPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: me } = useMe();
  const { data: team, isLoading, isError, refetch } = useTeam(teamId);
  const { data: members } = useMembers(teamId);

  if (isLoading) return <LoadingState />;
  if (isError || !team) return <ErrorState onRetry={() => refetch()} />;

  const myRole = me?.memberships.find((m) => m.team_id === teamId)?.role;
  const isOwner = myRole === "owner";

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6">
      <h1 className="text-2xl font-semibold">Equipo y ajustes</h1>

      <TeamCodeCard teamId={teamId} code={team.code} formattedCode={team.formatted_code} isOwner={isOwner} />
      <HackathonCard teamId={teamId} team={team} isOwner={isOwner} />
      <MembersCard teamId={teamId} members={members ?? []} myUserId={me?.id} isOwner={isOwner} />
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
