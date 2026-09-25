"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { LoadingState, ErrorState } from "@/components/states";
import { useMe } from "@/hooks/use-me";
import { useConsentInfo, useDecideAuthorization } from "@/hooks/use-oauth";
import { ApiError } from "@/lib/api-client";

const SCOPE_LABELS: Record<string, string> = {
  read: "View the team: objectives, features, arguments, milestones, activity and analyses",
  "features:write": "Create and edit features, move them and change assignees",
  "objectives:write": "Create and edit objectives",
  "arguments:write": "Add pros and cons, and vote",
  "milestones:write": "Create and edit milestones",
  "attribution:write": "Confirm or correct which feature each event belongs to",
  "analyses:run": "Run an AI coverage analysis",
  "progress:write": "Report progress on a feature",
};

function ConsentContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const requestId = searchParams.get("request_id") ?? "";
  const { data: me, isLoading: meLoading, isError: meError } = useMe();
  const { data: consent, isLoading: consentLoading, isError: consentError } = useConsentInfo(requestId);
  const decide = useDecideAuthorization();

  const [selectedTeamId, setSelectedTeamId] = useState<string | undefined>(undefined);
  const [grantedScopes, setGrantedScopes] = useState<string[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const teamId = selectedTeamId ?? me?.memberships[0]?.team_id;
  const scopes = grantedScopes ?? consent?.scopes ?? [];

  useEffect(() => {
    if (meError) {
      router.replace(`/login?next=${encodeURIComponent(`/oauth/consent?request_id=${requestId}`)}`);
    }
  }, [meError, router, requestId]);

  if (meLoading || consentLoading || !me) return <LoadingState />;
  if (consentError || !consent) return <ErrorState onRetry={() => window.location.reload()} />;

  if (me.memberships.length === 0) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center p-4">
        <p className="text-muted-foreground text-base">You are not in any team yet. Join one before you connect {consent.client.name}.</p>
      </div>
    );
  }

  function toggleScope(scope: string) {
    const current = grantedScopes ?? consent!.scopes;
    setGrantedScopes(current.includes(scope) ? current.filter((s) => s !== scope) : [...current, scope]);
  }

  async function handleDecision(approve: boolean) {
    setError(null);
    try {
      const result = await decide.mutateAsync({ request_id: requestId, approve, team_id: teamId, scopes: approve ? scopes : undefined });
      window.location.href = result.redirect_url;
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Could not complete the authorization");
    }
  }

  return (
    <div className="flex min-h-[60vh] items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            {consent.client.name} wants to access Hackboard
            {!consent.client.first_party && <Badge variant="warning">Unverified</Badge>}
          </CardTitle>
          <CardDescription>
            Choose the team and review the permissions before you approve. You will go back to{" "}
            <span className="font-mono">{new URL(consent.redirect_uri).host}</span>.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {me.memberships.length > 1 && (
            <div className="flex flex-col gap-1.5">
              <Label>Team</Label>
              <Select value={teamId} onValueChange={(v) => setSelectedTeamId(v ?? undefined)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {me.memberships.map((m) => (
                    <SelectItem key={m.team_id} value={m.team_id}>
                      {m.team_name ?? m.team_id}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}

          <div className="flex flex-col gap-2">
            <Label>Permissions</Label>
            {consent.scopes.map((scope) => (
              <label key={scope} className="flex cursor-pointer items-start gap-2 rounded-md border border-input p-2 text-base has-data-[checked]:border-primary">
                <Checkbox
                  className="mt-0.5"
                  checked={scopes.includes(scope)}
                  onCheckedChange={() => toggleScope(scope)}
                />
                <span>{SCOPE_LABELS[scope] ?? scope}</span>
              </label>
            ))}
            {consent.scopes.length === 0 && <p className="text-muted-foreground text-sm">Read-only access to the team.</p>}
          </div>

          {error && <p className="text-destructive text-base">{error}</p>}

          <p className="text-muted-foreground text-sm">
            {consent.client.name} will be able to act on your behalf in the chosen team, with the permissions checked
            above, until you revoke access from Connected apps.
          </p>

          <div className="flex gap-2">
            <Button type="button" variant="outline" className="flex-1" onClick={() => handleDecision(false)} loading={decide.isPending}>
              Deny
            </Button>
            <Button type="button" className="flex-1" onClick={() => handleDecision(true)} loading={decide.isPending} disabled={!teamId}>
              Approve
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function ConsentPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <ConsentContent />
    </Suspense>
  );
}
