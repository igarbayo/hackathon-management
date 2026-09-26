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
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
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
import { actorInitials } from "@/lib/actor-avatar";
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

function copyToClipboard(text: string, message = "Copied") {
  navigator.clipboard.writeText(text);
  toast.success(message);
}

const PAT_PRESETS = [
  { value: "observe", label: "Observe (read only)" },
  { value: "agent", label: "Agent (read + move features + progress)" },
  { value: "full", label: "Full (everything except ingest)" },
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
      <PageHeader icon={SettingsIcon} title="Team and settings" />

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
        <CardTitle className="text-base">Team code</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-lg">{formattedCode}</span>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(code, "Code copied")}>
          <CopyIcon className="size-3.5" /> Copy code
        </Button>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(joinUrl, "Link copied")}>
          <CopyIcon className="size-3.5" /> Copy link
        </Button>
        {isOwner && (
          <Button variant="outline" size="sm" onClick={() => rotateCode.mutate()} disabled={rotateCode.isPending}>
            <RefreshCwIcon className="size-3.5" /> Regenerate
          </Button>
        )}
      </CardContent>
    </Card>
  );
}

// RF-TEAM-015: the owner can change the hackathon start and end. Moving the
// start makes the API import the GitHub history again.
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
        onError: (err) => setDatesError(err instanceof ApiError ? err.message : "Could not save the date"),
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
          <Label>Hackathon name</Label>
          <p className="text-base">{team.hackathon?.name}</p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="hackathon-starts-at">Start</Label>
            {isOwner ? (
              <DatePicker id="hackathon-starts-at" value={startsAt} onChange={(date) => updateDate("starts_at", date)} />
            ) : (
              <p className="text-base">{formatInTimezone(team.hackathon?.starts_at, team.hackathon?.timezone) || "No date"}</p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="hackathon-ends-at">End</Label>
            {isOwner ? (
              <DatePicker
                id="hackathon-ends-at"
                value={endsAt}
                onChange={(date) => updateDate("ends_at", date)}
                disabled={startsAt ? { before: startsAt } : undefined}
              />
            ) : (
              <p className="text-base">{formatInTimezone(team.hackathon?.ends_at, team.hackathon?.timezone) || "No date"}</p>
            )}
          </div>
        </div>
        {isOwner && (
          <p className="text-sm text-f1-foreground-secondary">
            GitHub commits are imported from the start date. If you change it, the history is imported again.
          </p>
        )}
        {datesError && <p className="text-base text-f1-foreground-critical">{datesError}</p>}
        <div>
          <Label>Time zone</Label>
          <p className="text-base">{team.hackathon?.timezone}</p>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="challenge">Challenge text</Label>
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
  members: Member[];
  myUserId: string | undefined;
  isOwner: boolean;
}) {
  const updateMember = useUpdateMember(teamId);
  const removeMember = useRemoveMember(teamId);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Members</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {members.map((member) => {
          const isMe = member.user_id === myUserId;
          return (
            <div key={member.id} className="flex items-center gap-3 rounded-md border border-f1-border p-2">
              <Avatar>
                {member.avatar_url && <AvatarImage src={member.avatar_url} alt="" referrerPolicy="no-referrer" />}
                <AvatarFallback>{actorInitials(member.display_name)}</AvatarFallback>
              </Avatar>
              <span className="flex-1 text-base text-f1-foreground">{member.display_name}</span>
              <Badge variant={member.claude_code ? "positive" : "outline"}>
                {member.claude_code ? "Claude Code connected" : "Claude Code not connected"}
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
                  aria-label={isMe ? "Leave team" : "Remove"}
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

// RF-GH-010: linked repos, the "Add repo" button and the install status.
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

// RF-CC-010: each person only sees and changes their own link, never another
// member's (it is opt-in and per person, 08-integracion-claude-code.md).
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
              Not connected. It takes two steps:
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
              This registers your Claude Code with this team and adds the hook that sends your activity. It sends
              metadata (which file, which command, how long it took) and, if you choose that privacy level, a short
              summary — never file contents, diffs or the text of your prompts.
            </p>
          </>
        ) : (
          <>
            <div className="flex items-center gap-2 text-base">
              <Badge variant={link.paused ? "outline" : "positive"}>{link.paused ? "Paused" : "Connected"}</Badge>
              <span className="text-muted-foreground font-mono text-sm">{link.token_prefix}…</span>
            </div>

            <div className="flex flex-col gap-1.5">
              <Label>Privacy level</Label>
              <Select
                value={link.privacy_level}
                onValueChange={(privacy_level) => privacy_level && update.mutate({ privacy_level })}
              >
                <SelectTrigger className="w-56">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="metadata">Metadata</SelectItem>
                  <SelectItem value="summaries">Metadata + summaries</SelectItem>
                  <SelectItem value="off">Off</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <p className="text-muted-foreground text-sm">
              Last event: {link.last_event_at ? new Date(link.last_event_at).toLocaleString("en-US") : "none yet"}
            </p>

            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => update.mutate({ paused: !link.paused })}
                disabled={update.isPending}
              >
                {link.paused ? "Resume" : "Pause"}
              </Button>
              {!confirmingPurge ? (
                <Button variant="ghost" size="sm" onClick={() => setConfirmingPurge(true)}>
                  <Trash2Icon className="size-3.5" /> Disconnect
                </Button>
              ) : (
                <div className="flex flex-col gap-1.5 rounded-md border p-2">
                  <p className="text-sm">Only disconnect, or also delete the events you already sent?</p>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" onClick={() => disconnect.mutate(false)} disabled={disconnect.isPending}>
                      Only disconnect
                    </Button>
                    <Button variant="destructive" size="sm" onClick={() => disconnect.mutate(true)} disabled={disconnect.isPending}>
                      Disconnect and delete my events
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => setConfirmingPurge(false)}>
                      Cancel
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

// RF-AI-021: personal Gemini key, per account (not per team). It is used for
// the analyses and attribution suggestions that person triggers and, if they
// are an owner, also for the team's automatic runs (06-analisis-ia.md#proveedor).
function GeminiApiKeyCard({ me, isOwner }: { me: Me; isOwner: boolean }) {
  const update = useUpdateMe();
  const [value, setValue] = useState("");

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!value.trim()) return;
    try {
      await update.mutateAsync({ gemini_api_key: value.trim() });
      setValue("");
      toast.success("Gemini key saved");
    } catch (err) {
      toast.error(err instanceof ApiError ? `Could not save the key: ${err.message}` : "Could not save the key");
    }
  }

  async function handleRemove() {
    try {
      await update.mutateAsync({ gemini_api_key: "" });
      toast.success("Gemini key removed");
    } catch (err) {
      toast.error(err instanceof ApiError ? `Could not remove the key: ${err.message}` : "Could not remove the key");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <SparklesIcon className="size-4" /> AI (Gemini) — personal key
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="flex items-center gap-2 text-base">
          <Badge variant={me.gemini_api_key_configured ? "positive" : "outline"}>
            {me.gemini_api_key_configured ? "Set up" : "Not set up"}
          </Badge>
        </div>
        <p className="text-muted-foreground text-sm">
          Used for your on-demand analyses (“Analyze now”, MCP or API){isOwner ? " and, since you are an owner, also for this team's scheduled analysis and suggested attribution" : ""}.
          It is never shown in plain text again after you save it.
        </p>
        <form onSubmit={handleSave} className="flex gap-2">
          <Input
            type="password"
            placeholder={me.gemini_api_key_configured ? "Replace with a new key" : "Paste your Gemini key (AIza…)"}
            value={value}
            onChange={(e) => setValue(e.target.value)}
          />
          <Button type="submit" disabled={update.isPending || !value.trim()}>
            Save
          </Button>
          {me.gemini_api_key_configured && (
            <Button type="button" variant="outline" onClick={handleRemove} disabled={update.isPending}>
              Remove
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
      <p className="font-medium">{label}: copy it now, it will not be shown again.</p>
      <div className="flex items-center gap-2">
        <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{token}</code>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(token, "Token copied")}>
          <CopyIcon className="size-3.5" /> Copy
        </Button>
      </div>
      <p className="text-muted-foreground text-sm">To add the MCP server to Claude Code:</p>
      <div className="flex items-center gap-2">
        <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{mcpCommand}</code>
        <Button variant="outline" size="sm" onClick={() => copyToClipboard(mcpCommand, "Command copied")}>
          <CopyIcon className="size-3.5" /> Copy
        </Button>
      </div>
      <Button variant="ghost" size="sm" className="self-start" onClick={onDismiss}>
        I have saved it
      </Button>
    </div>
  );
}

// RF-API-001/RF-MCP-010/RF-API-020: PATs. Any member creates their own;
// an owner also sees the rest of the team's (the backend already returns
// them, with no parameter to ask for it) and here each one is labeled with
// whose it is.
function ApiTokensCard({ teamId, members, isOwner }: { teamId: string; members: Member[]; isOwner: boolean }) {
  const { data: tokens } = useTokens(teamId);
  const create = useCreateToken(teamId);
  const revoke = useRevokeToken(teamId);
  const [name, setName] = useState("");
  const [preset, setPreset] = useState("observe");
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
      setError(err instanceof ApiError ? err.message : "Could not create the token");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">My access tokens (API and MCP)</CardTitle>
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
                <Button variant="ghost" size="icon" aria-label="Revoke" onClick={() => revoke.mutate(token.id)}>
                  <Trash2Icon className="size-4" />
                </Button>
              </div>
              <p className="text-muted-foreground text-sm">
                {token.scopes.join(", ")} · expires {token.expires_at ? new Date(token.expires_at).toLocaleDateString("en-US") : "—"} ·
                last used: {token.last_used_at ? new Date(token.last_used_at).toLocaleString("en-US") : "never"}
              </p>
            </div>
          );
        })}
        {tokens?.length === 0 && <p className="text-muted-foreground text-base">You have no tokens yet.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2 sm:flex-row">
          <Input placeholder="Name (e.g. Claude Code laptop)" value={name} onChange={(e) => setName(e.target.value)} className="flex-1" />
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
            Create token
          </Button>
        </form>
        {error && <p className="text-destructive text-base">{error}</p>}
        <p className="text-muted-foreground text-sm">
          Do not commit it to a repository or share it: it gives access to the API with the chosen permissions.{" "}
          <a href={`${apiUrl}/api/v1/openapi.json`} target="_blank" rel="noreferrer" className="text-primary underline">
            OpenAPI docs
          </a>
        </p>

        <div className="flex flex-col gap-1.5 rounded-md border p-3">
          <p className="text-base font-medium">claude.ai (custom connector)</p>
          <div className="flex items-center gap-2">
            <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{apiUrl}/api/v1/mcp</code>
            <Button variant="outline" size="sm" onClick={() => copyToClipboard(`${apiUrl}/api/v1/mcp`, "URL copied")}>
              <CopyIcon className="size-3.5" /> Copy
            </Button>
          </div>
          <p className="text-muted-foreground text-sm">
            In claude.ai: Settings → Connectors → Add custom connector, paste this URL and log in when asked. You do
            not need to copy any token: claude.ai asks for permission with the consent screen. Authorized connections
            show up in{" "}
            <a href="#connected-apps" className="text-primary underline">
              Connected apps
            </a>
            .
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

// RF-API-011/RF-API-023: owners only. The integration is the actor of what it does.
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
      setError(err instanceof ApiError ? err.message : "Could not create the integration");
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
          <PlugIcon className="size-4" /> Integration tokens
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealed && <RevealedToken label="Integration token" token={revealed} apiUrl={apiUrl} onDismiss={() => setRevealed(null)} />}

        {integrations?.map((integration) => (
          <div key={integration.id} className="flex items-center gap-3 rounded-md border p-2 text-base">
            <span className="flex-1">{integration.name}</span>
            <span className="text-muted-foreground font-mono text-sm">{integration.token_prefix}…</span>
            <span className="text-muted-foreground text-sm">{integration.scopes.join(", ")}</span>
            <Button variant="outline" size="sm" onClick={() => handleRotate(integration.id)}>
              Rotate
            </Button>
            <Button variant="ghost" size="icon" aria-label="Revoke" onClick={() => revoke.mutate(integration.id)}>
              <Trash2Icon className="size-4" />
            </Button>
          </div>
        ))}
        {integrations?.length === 0 && <p className="text-muted-foreground text-base">No integrations yet.</p>}

        <form onSubmit={handleCreate} className="flex flex-col gap-2">
          <Input placeholder="Name (e.g. Slack bot)" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="flex flex-wrap gap-2">
            {INTEGRATION_SCOPES.map((scope) => (
              <label key={scope} className="flex items-center gap-1.5 rounded-md border px-2 py-1 text-sm has-data-[checked]:border-primary">
                <Checkbox checked={scopes.includes(scope)} onCheckedChange={() => toggleScope(scope)} />
                {scope}
              </label>
            ))}
          </div>
          <Button type="submit" disabled={create.isPending} className="self-start">
            Create integration
          </Button>
        </form>
        {error && <p className="text-destructive text-base">{error}</p>}
      </CardContent>
    </Card>
  );
}

// RF-API-009: outgoing webhooks, owners only.
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
      setError(err instanceof ApiError ? err.message : "Could not create the webhook");
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
          <WebhookIcon className="size-4" /> Outgoing webhooks
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {revealedSecret && (
          <div className="flex flex-col gap-2 rounded-md border border-f1-border-warning-bold bg-f1-background-warning p-3 text-base">
            <p className="font-medium">Signing secret: copy it now, it will not be shown again.</p>
            <div className="flex items-center gap-2">
              <code className="bg-muted flex-1 truncate rounded p-1.5 font-mono text-sm">{revealedSecret}</code>
              <Button variant="outline" size="sm" onClick={() => copyToClipboard(revealedSecret, "Secret copied")}>
                <CopyIcon className="size-3.5" /> Copy
              </Button>
            </div>
            <Button variant="ghost" size="sm" className="self-start" onClick={() => setRevealedSecret(null)}>
              I have saved it
            </Button>
          </div>
        )}

        {webhooks?.map((webhook) => (
          <div key={webhook.id} className="flex flex-col gap-2 rounded-md border p-2 text-base">
            <div className="flex items-center gap-2">
              <Badge variant={webhook.active ? "positive" : "outline"}>{webhook.active ? "Active" : "Paused"}</Badge>
              <span className="flex-1 truncate">{webhook.url}</span>
              <Button
                variant="ghost"
                size="icon"
                aria-label={webhook.active ? "Pause" : "Resume"}
                onClick={() => update.mutate({ id: webhook.id, active: !webhook.active })}
              >
                <RefreshCwIcon className="size-4" />
              </Button>
              <Button variant="ghost" size="icon" aria-label="Delete" onClick={() => remove.mutate(webhook.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">{webhook.events.join(", ")}</p>
            {webhook.consecutive_failures > 0 && (
              <p className="text-destructive text-sm">{webhook.consecutive_failures} failures in a row</p>
            )}
            <div className="flex gap-2">
              <Button variant="outline" size="sm" onClick={() => test.mutate(webhook.id)} disabled={test.isPending}>
                Test
              </Button>
              <Button variant="outline" size="sm" onClick={() => handleRotate(webhook.id)}>
                Rotate secret
              </Button>
              <Button variant="outline" size="sm" onClick={() => setOpenDeliveries(openDeliveries === webhook.id ? null : webhook.id)}>
                View deliveries
              </Button>
            </div>
            {openDeliveries === webhook.id && <WebhookDeliveries teamId={teamId} webhookId={webhook.id} />}
          </div>
        ))}
        {webhooks?.length === 0 && <p className="text-muted-foreground text-base">No webhooks yet.</p>}

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
            Create webhook
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
            Redeliver
          </Button>
        </div>
      ))}
      {deliveries?.length === 0 && <p className="text-muted-foreground text-sm">No deliveries yet.</p>}
    </div>
  );
}

// RF-API-021: "Connected apps" is not per team, it belongs to the account. It
// is shown here anyway for simplicity, since there is no account settings
// screen apart from the team settings yet.
function ConnectedAppsCard() {
  const { data: connections } = useOAuthConnections();
  const revoke = useRevokeOAuthConnection();

  if (connections?.length === 0) return null;

  return (
    <Card id="connected-apps">
      <CardHeader>
        <CardTitle className="text-base">Connected apps</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {connections?.map((connection) => (
          <div key={connection.id} className="flex flex-col gap-1 rounded-md border p-2 text-base">
            <div className="flex items-center gap-3">
              <span className="flex-1">
                {connection.client.name ?? "Unknown app"}
                {!connection.client.first_party && (
                  <Badge variant="warning" className="ml-2">
                    Unverified
                  </Badge>
                )}
              </span>
              <Button variant="ghost" size="icon" aria-label="Revoke" onClick={() => revoke.mutate(connection.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">
              {connection.scopes.join(", ")} · authorized on {new Date(connection.created_at).toLocaleDateString("en-US")} · last
              used: {connection.last_used_at ? new Date(connection.last_used_at).toLocaleString("en-US") : "never"}
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}

// RF-API-021: "an owner sees the whole team's and can revoke them" — unlike
// ConnectedAppsCard (my apps), this one shows those of any team member.
function TeamConnectedAppsCard({ teamId }: { teamId: string }) {
  const { data: connections } = useTeamOAuthConnections(teamId);
  const revoke = useRevokeTeamOAuthConnection(teamId);

  if (connections?.length === 0) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Connected apps (team)</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {connections?.map((connection) => (
          <div key={connection.id} className="flex flex-col gap-1 rounded-md border p-2 text-base">
            <div className="flex items-center gap-3">
              <span className="flex-1">
                {connection.client.name ?? "Unknown app"}
                {!connection.client.first_party && (
                  <Badge variant="warning" className="ml-2">
                    Unverified
                  </Badge>
                )}
              </span>
              <span className="text-muted-foreground text-sm">{connection.user.display_name ?? "—"}</span>
              <Button variant="ghost" size="icon" aria-label="Revoke" onClick={() => revoke.mutate(connection.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">
              {connection.scopes.join(", ")} · authorized on {new Date(connection.created_at).toLocaleDateString("en-US")} · last
              used: {connection.last_used_at ? new Date(connection.last_used_at).toLocaleString("en-US") : "never"}
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}

// RF-AUTH-007 / RF-SEC-004: delete the account. It cannot be undone, so it is
// confirmed by typing the account email, not with a simple yes/no.
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
      toast.success("Your account has been deleted");
      router.replace("/login");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Could not delete the account");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <TriangleAlertIcon className="size-4" /> Delete account
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="text-muted-foreground text-sm">
          Deletes your account and your personal data in all your teams. If you are the only owner of a team with
          more members, you first have to hand ownership to someone else. More details in the{" "}
          <Link href="/privacy" className="text-foreground underline">
            privacy policy
          </Link>
          .
        </p>
        <div>
          <Button variant="destructive" onClick={() => setOpen(true)}>
            Delete account
          </Button>
        </div>
      </CardContent>

      <AlertDialog open={open} onOpenChange={handleOpenChange}>
        <AlertDialogContent>
          <form onSubmit={handleDelete} className="flex flex-col gap-4">
            <AlertDialogHeader>
              <AlertDialogTitle>Delete your account</AlertDialogTitle>
              <AlertDialogDescription>
                This cannot be undone. It deletes your profile, sessions, tokens and connected apps, your Gemini key
                and your Claude Code activity. In GitHub activity you will show up as “Deleted user”. Teams where you
                are the only member are deleted.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="delete-account-confirmation">
                Type <span className="text-foreground font-semibold">{email}</span> to confirm
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
              <AlertDialogCancel disabled={deleteMe.isPending}>Cancel</AlertDialogCancel>
              <AlertDialogAction type="submit" variant="destructive" disabled={!confirmed} loading={deleteMe.isPending}>
                Delete account
              </AlertDialogAction>
            </AlertDialogFooter>
          </form>
        </AlertDialogContent>
      </AlertDialog>
    </Card>
  );
}
