"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { LoadingState } from "@/components/states";
import { useMe } from "@/hooks/use-me";
import { useCreateTeam, useJoinTeam } from "@/hooks/use-teams";
import { ApiError } from "@/lib/api-client";

function OnboardingContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { data: me, isLoading, isError } = useMe();
  const [mode, setMode] = useState<"choose" | "create" | "join">(searchParams.get("code") ? "join" : "choose");

  useEffect(() => {
    if (isError) router.replace("/login");
  }, [isError, router]);

  if (isLoading || !me) {
    return (
      <div className="p-6">
        <LoadingState />
      </div>
    );
  }

  if (mode === "create") return <CreateTeamForm onBack={() => setMode("choose")} />;
  if (mode === "join") {
    return <JoinTeamForm onBack={() => setMode("choose")} initialCode={searchParams.get("code") ?? ""} />;
  }

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-4">
      <h1 className="text-xl font-semibold">¿Cómo empezamos?</h1>
      <div className="flex gap-4">
        <Card className="w-56 cursor-pointer" onClick={() => setMode("create")}>
          <CardHeader>
            <CardTitle>Crear equipo</CardTitle>
            <CardDescription>Empieza un hackathon nuevo</CardDescription>
          </CardHeader>
        </Card>
        <Card className="w-56 cursor-pointer" onClick={() => setMode("join")}>
          <CardHeader>
            <CardTitle>Unirme con código</CardTitle>
            <CardDescription>Ya tengo el código de mi equipo</CardDescription>
          </CardHeader>
        </Card>
      </div>
    </div>
  );
}

function CreateTeamForm({ onBack }: { onBack: () => void }) {
  const router = useRouter();
  const createTeam = useCreateTeam();
  const [name, setName] = useState("");
  const [hackathonName, setHackathonName] = useState("");
  const [endsAt, setEndsAt] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [created, setCreated] = useState<{ id: string; code: string; formatted_code: string } | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      const team = await createTeam.mutateAsync({
        name,
        hackathon: { name: hackathonName, ends_at: new Date(endsAt).toISOString(), timezone },
      });
      setCreated(team);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido crear el equipo");
    }
  }

  if (created) {
    const joinUrl = typeof window !== "undefined" ? `${window.location.origin}/onboarding?code=${created.code}` : "";
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle>Invita a tu equipo</CardTitle>
            <CardDescription>Comparte este código o el enlace</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            <p className="text-center font-mono text-2xl">{created.formatted_code}</p>
            <Button variant="outline" onClick={() => navigator.clipboard.writeText(created.code)}>
              Copiar código
            </Button>
            <Button variant="outline" onClick={() => navigator.clipboard.writeText(joinUrl)}>
              Copiar enlace de invitación
            </Button>
            <Button onClick={() => router.push(`/t/${created.id}/home`)}>Continuar</Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Crear equipo</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="team-name">Nombre del equipo</Label>
              <Input id="team-name" required value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="hackathon-name">Nombre del hackathon</Label>
              <Input
                id="hackathon-name"
                required
                value={hackathonName}
                onChange={(e) => setHackathonName(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="ends-at">Fecha de fin</Label>
              <Input id="ends-at" type="datetime-local" required value={endsAt} onChange={(e) => setEndsAt(e.target.value)} />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
            <div className="flex gap-2">
              <Button type="button" variant="ghost" onClick={onBack}>
                Atrás
              </Button>
              <Button type="submit" disabled={createTeam.isPending} className="flex-1">
                {createTeam.isPending ? "Creando…" : "Crear equipo"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

function JoinTeamForm({ onBack, initialCode }: { onBack: () => void; initialCode: string }) {
  const router = useRouter();
  const joinTeam = useJoinTeam();
  const [code, setCode] = useState(initialCode);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const { team_id } = await joinTeam.mutateAsync(code);
      router.push(`/t/${team_id}/home`);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Código no válido");
    }
  }

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Unirme con código</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="code">Código del equipo</Label>
              <Input
                id="code"
                required
                placeholder="XXXX-XXXX"
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
            <div className="flex gap-2">
              <Button type="button" variant="ghost" onClick={onBack}>
                Atrás
              </Button>
              <Button type="submit" disabled={joinTeam.isPending} className="flex-1">
                {joinTeam.isPending ? "Uniéndome…" : "Unirme"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

export default function OnboardingPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <OnboardingContent />
    </Suspense>
  );
}
