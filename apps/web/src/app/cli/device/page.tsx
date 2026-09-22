"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { LoadingState } from "@/components/states";
import { useMe } from "@/hooks/use-me";
import { useApproveDevice, useDenyDevice } from "@/hooks/use-claude-code";
import { ApiError } from "@/lib/api-client";

const PRIVACY_LEVELS = [
  { value: "metadata", label: "Metadata (recomendado)", description: "Tipo de evento, horas, rama, ficheros editados, nº de herramientas y longitud del prompt. Nunca el texto." },
  { value: "summaries", label: "Metadata + resúmenes", description: "Lo de metadata más un resumen del turno que tú mismo apruebas antes de enviarse." },
  { value: "off", label: "Desactivado", description: "No se envía nada, aunque quede conectado." },
];

function DeviceApprovalContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { data: me, isLoading, isError } = useMe();
  const [userCode, setUserCode] = useState(searchParams.get("user_code") ?? "");
  const [selectedTeamId, setSelectedTeamId] = useState<string | undefined>(undefined);
  const [privacyLevel, setPrivacyLevel] = useState("metadata");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<"approved" | "denied" | null>(null);
  const teamId = selectedTeamId ?? me?.memberships[0]?.team_id;

  const approve = useApproveDevice(teamId ?? "");
  const deny = useDenyDevice(teamId ?? "");

  useEffect(() => {
    if (isError) {
      const here = `/cli/device?user_code=${encodeURIComponent(userCode)}`;
      router.replace(`/login?next=${encodeURIComponent(here)}`);
    }
  }, [isError, router, userCode]);

  if (isLoading || !me || isError) return <LoadingState />;

  if (me.memberships.length === 0) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center p-4">
        <p className="text-muted-foreground text-base">Todavía no tienes ningún equipo. Únete a uno antes de conectar el CLI.</p>
      </div>
    );
  }

  if (done) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center p-4">
        <Card className="w-full max-w-sm">
          <CardHeader>
            <CardTitle>{done === "approved" ? "Dispositivo aprobado" : "Solicitud rechazada"}</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground text-base">
              {done === "approved"
                ? "Ya puedes volver a la terminal: hackboard debería continuar solo."
                : "El CLI recibirá el rechazo la próxima vez que compruebe el estado."}
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  async function handleApprove(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await approve.mutateAsync({ user_code: userCode, privacy_level: privacyLevel });
      setDone("approved");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido aprobar");
    }
  }

  async function handleDeny() {
    setError(null);
    try {
      await deny.mutateAsync({ user_code: userCode });
      setDone("denied");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido rechazar");
    }
  }

  return (
    <div className="flex min-h-[60vh] items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Conectar Claude Code</CardTitle>
          <CardDescription>Un CLI está pidiendo acceso con este código. Solo tú decides qué se envía.</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleApprove} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="user-code">Código</Label>
              <Input
                id="user-code"
                required
                placeholder="XXXX-XXXX"
                value={userCode}
                onChange={(e) => setUserCode(e.target.value.toUpperCase())}
              />
            </div>

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
              <Label>Qué se envía</Label>
              <RadioGroup value={privacyLevel} onValueChange={(v) => v && setPrivacyLevel(v)}>
                {PRIVACY_LEVELS.map((level) => (
                  <label
                    key={level.value}
                    className="flex cursor-pointer flex-col gap-0.5 rounded-md border border-input p-2 has-data-[checked]:border-primary"
                  >
                    <span className="flex items-center gap-2 text-base font-medium">
                      <RadioGroupItem value={level.value} />
                      {level.label}
                    </span>
                    <span className="text-muted-foreground pl-6 text-sm">{level.description}</span>
                  </label>
                ))}
              </RadioGroup>
            </div>

            {error && <p className="text-destructive text-base">{error}</p>}

            <div className="flex gap-2">
              <Button type="button" variant="outline" className="flex-1" onClick={handleDeny} loading={deny.isPending}>
                Rechazar
              </Button>
              <Button type="submit" className="flex-1" loading={approve.isPending} disabled={!teamId}>
                Aprobar
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

export default function DeviceApprovalPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <DeviceApprovalContent />
    </Suspense>
  );
}
