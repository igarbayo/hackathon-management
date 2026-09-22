"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { LoadingState, ErrorState } from "@/components/states";
import { useMe } from "@/hooks/use-me";
import { useConsentInfo, useDecideAuthorization } from "@/hooks/use-oauth";
import { ApiError } from "@/lib/api-client";

const SCOPE_LABELS: Record<string, string> = {
  read: "Ver el equipo: objetivos, features, argumentos, milestones, actividad y análisis",
  "features:write": "Crear y editar features, moverlas y cambiar asignaciones",
  "objectives:write": "Crear y editar objetivos",
  "arguments:write": "Añadir pros y contras, y votar",
  "milestones:write": "Crear y editar milestones",
  "attribution:write": "Confirmar o corregir a qué feature pertenece cada evento",
  "analyses:run": "Lanzar un análisis de cobertura con IA",
  "progress:write": "Informar del progreso de una feature",
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
        <p className="text-muted-foreground text-sm">Todavía no tienes ningún equipo. Únete a uno antes de conectar {consent.client.name}.</p>
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
      setError(err instanceof ApiError ? err.message : "No se ha podido completar la autorización");
    }
  }

  return (
    <div className="flex min-h-[60vh] items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            {consent.client.name} quiere acceder a Hackboard
            {!consent.client.first_party && <Badge variant="outline">no verificada</Badge>}
          </CardTitle>
          <CardDescription>
            Elige el equipo y revisa los permisos antes de aprobar. Volverás a{" "}
            <span className="font-mono">{new URL(consent.redirect_uri).host}</span>.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {me.memberships.length > 1 && (
            <div className="flex flex-col gap-1.5">
              <Label>Equipo</Label>
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
            <Label>Permisos</Label>
            {consent.scopes.map((scope) => (
              <label key={scope} className="flex cursor-pointer items-start gap-2 rounded-md border p-2 text-sm has-[:checked]:border-primary">
                <input type="checkbox" className="mt-0.5" checked={scopes.includes(scope)} onChange={() => toggleScope(scope)} />
                <span>{SCOPE_LABELS[scope] ?? scope}</span>
              </label>
            ))}
            {consent.scopes.length === 0 && <p className="text-muted-foreground text-xs">Solo lectura del equipo.</p>}
          </div>

          {error && <p className="text-destructive text-sm">{error}</p>}

          <p className="text-muted-foreground text-xs">
            {consent.client.name} podrá actuar en tu nombre en el equipo elegido, con los permisos marcados arriba, hasta que
            revoques el acceso desde Apps conectadas.
          </p>

          <div className="flex gap-2">
            <Button type="button" variant="outline" className="flex-1" onClick={() => handleDecision(false)} disabled={decide.isPending}>
              Rechazar
            </Button>
            <Button type="button" className="flex-1" onClick={() => handleDecision(true)} disabled={decide.isPending || !teamId}>
              {decide.isPending ? "Autorizando…" : "Aprobar"}
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
