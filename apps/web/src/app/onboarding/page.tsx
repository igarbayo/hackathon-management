"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { toast } from "sonner";
import { CheckIcon } from "lucide-react";
import { Button, buttonVariants } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { DatePicker } from "@/components/ui/date-picker";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Alert } from "@/components/f0/alert";
import { GitHubLogo } from "@/components/auth/provider-logos";
import { RepositoryLinker } from "@/components/github/repository-linker";
import { LoadingState } from "@/components/states";
import { useMe, useUpdateMe } from "@/hooks/use-me";
import { useCreateTeam, useJoinTeam, useTeam } from "@/hooks/use-teams";
import { useRepositories } from "@/hooks/use-github";
import { ApiError } from "@/lib/api-client";
import { cn } from "@/lib/utils";
import type { Me } from "@/types/api";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

// 04-pantallas.md#onboarding: Perfil → Equipo → (si lo crea) Repositorio →
// Invitar. Los pasos de repo e invitar se retoman por URL
// (`?team=<id>&step=repo|invite`), porque instalar la GitHub App sale de la
// web y vuelve aquí (RF-TEAM-014).
const CREATE_STEPS = ["Perfil", "Equipo", "Repositorio", "Invitar"];
const JOIN_STEPS = ["Perfil", "Equipo"];

function copyToClipboard(text: string, message: string) {
  navigator.clipboard.writeText(text);
  toast.success(message);
}

function initials(text: string) {
  return text
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0]?.toUpperCase())
    .join("");
}

function Steps({ steps, current }: { steps: string[]; current: number }) {
  return (
    <ol className="flex flex-wrap items-center justify-center gap-2 text-sm" aria-label="Pasos del onboarding">
      {steps.map((step, index) => {
        const done = index < current;
        const active = index === current;
        return (
          <li key={step} className="flex items-center gap-2" aria-current={active ? "step" : undefined}>
            <span
              className={cn(
                "flex size-5 items-center justify-center rounded-full text-xs font-medium",
                done && "bg-f1-background-selected-bold text-f1-foreground-inverse",
                active && "bg-f1-background-accent-bold text-f1-foreground-inverse",
                !done && !active && "bg-f1-background-secondary text-f1-foreground-secondary",
              )}
            >
              {done ? <CheckIcon className="size-3" /> : index + 1}
            </span>
            <span className={active ? "font-medium text-f1-foreground" : "text-f1-foreground-secondary"}>{step}</span>
            {index < steps.length - 1 && <span className="h-px w-6 bg-f1-border" aria-hidden />}
          </li>
        );
      })}
    </ol>
  );
}

function StepLayout({ steps, current, children }: { steps: string[]; current: number; children: React.ReactNode }) {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-6 p-4">
      <Steps steps={steps} current={current} />
      {children}
    </div>
  );
}

function OnboardingContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { data: me, isLoading, isError } = useMe();
  const code = searchParams.get("code");
  const teamId = searchParams.get("team");
  const step = searchParams.get("step");
  const [mode, setMode] = useState<"choose" | "create" | "join">(code ? "join" : "choose");

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

  // Pasos que siguen a crear el equipo, retomables tras instalar la App.
  if (teamId && step === "repo") {
    return <RepoStep teamId={teamId} onNext={() => router.replace(`/onboarding?team=${teamId}&step=invite`)} />;
  }
  if (teamId && step === "invite") return <InviteStep teamId={teamId} />;

  const steps = mode === "join" ? JOIN_STEPS : CREATE_STEPS;

  // RF-TEAM-014: quien aún no tiene equipo deja listo su perfil primero.
  if (!me.profile_completed && me.memberships.length === 0) {
    return (
      <StepLayout steps={steps} current={0}>
        <ProfileStep me={me} githubLink={searchParams.get("github_link")} />
      </StepLayout>
    );
  }

  if (mode === "create") {
    return (
      <StepLayout steps={steps} current={1}>
        <CreateTeamForm
          onBack={() => setMode("choose")}
          onCreated={(id) => router.replace(`/onboarding?team=${id}&step=repo`)}
        />
      </StepLayout>
    );
  }
  if (mode === "join") {
    return (
      <StepLayout steps={steps} current={1}>
        <JoinTeamForm onBack={() => setMode("choose")} initialCode={code ?? ""} />
      </StepLayout>
    );
  }

  const hasTeams = me.memberships.length > 0;

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-6 p-4">
      {!hasTeams && <Steps steps={steps} current={1} />}
      {hasTeams && (
        <div className="flex w-full max-w-md flex-col gap-2">
          <h1 className="text-xl font-semibold text-f1-foreground">Elige un equipo</h1>
          {me.memberships.map((membership) => (
            <Card
              key={membership.team_id}
              className="cursor-pointer transition-colors hover:border-f1-border-hover hover:shadow-md"
              onClick={() => router.push(`/t/${membership.team_id}/home`)}
            >
              <CardHeader>
                <CardTitle>{membership.team_name}</CardTitle>
                <CardDescription>{membership.role === "owner" ? "Owner" : "Miembro"}</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
      )}

      <div className="flex flex-col items-center gap-4">
        <h2 className={hasTeams ? "text-muted-foreground text-base" : "text-xl font-semibold text-f1-foreground"}>
          {hasTeams ? "O empieza otro equipo" : "¿Cómo empezamos?"}
        </h2>
        <div className="flex flex-wrap justify-center gap-4">
          <Card
            className="w-56 cursor-pointer transition-colors hover:border-f1-border-hover hover:shadow-md"
            onClick={() => setMode("create")}
          >
            <CardHeader>
              <CardTitle>Crear equipo</CardTitle>
              <CardDescription>Empieza un hackathon nuevo</CardDescription>
            </CardHeader>
          </Card>
          <Card
            className="w-56 cursor-pointer transition-colors hover:border-f1-border-hover hover:shadow-md"
            onClick={() => setMode("join")}
          >
            <CardHeader>
              <CardTitle>Unirme con código</CardTitle>
              <CardDescription>Ya tengo el código de mi equipo</CardDescription>
            </CardHeader>
          </Card>
        </div>
      </div>
    </div>
  );
}

const GITHUB_LINK_ERRORS: Record<string, string> = {
  taken: "Esa cuenta de GitHub ya está vinculada a otro usuario de Hackboard.",
  error: "No se ha podido vincular GitHub. Vuelve a intentarlo.",
};

// RF-TEAM-014: nombre, foto y cuenta de GitHub. Vincular GitHub hace que los
// commits se asignen solos a la persona (RF-GH-024), así que se recomienda,
// pero se puede seguir sin hacerlo.
function ProfileStep({ me, githubLink }: { me: Me; githubLink: string | null }) {
  const updateMe = useUpdateMe();
  const [name, setName] = useState(me.name);
  const [error, setError] = useState<string | null>(null);
  const linkError = githubLink ? GITHUB_LINK_ERRORS[githubLink] : undefined;
  const githubHref = `${API_URL}/api/v1/auth/github?link=1&return_to=${encodeURIComponent("/onboarding")}`;

  useEffect(() => {
    if (githubLink === "linked") toast.success("GitHub vinculado");
  }, [githubLink]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await updateMe.mutateAsync({ name: name.trim(), profile_completed: true });
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido guardar el perfil");
    }
  }

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <CardTitle>Tu perfil</CardTitle>
        <CardDescription>Así te verá tu equipo en el tablero y en la actividad.</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="flex items-center gap-3">
            <Avatar size="lg">
              {me.avatar_url && <AvatarImage src={me.avatar_url} alt="" referrerPolicy="no-referrer" />}
              <AvatarFallback className="bg-f1-background-selected-bold font-medium text-f1-foreground-inverse">
                {initials(name || me.email)}
              </AvatarFallback>
            </Avatar>
            <div className="flex min-w-0 flex-1 flex-col gap-1.5">
              <Label htmlFor="profile-name">Nombre</Label>
              <Input id="profile-name" required maxLength={80} value={name} onChange={(e) => setName(e.target.value)} />
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <Label>GitHub</Label>
            {me.github_login ? (
              <p className="flex items-center gap-2 text-base text-f1-foreground">
                <GitHubLogo />
                Vinculado como <span className="font-medium">@{me.github_login}</span>
              </p>
            ) : (
              <>
                <p className="text-base text-f1-foreground-secondary">
                  Vincula tu cuenta para que tus commits se te asignen solos, sin tener que reclamarlos.
                </p>
                <a href={githubHref} className={cn(buttonVariants({ variant: "outline" }), "self-start")}>
                  <GitHubLogo />
                  Vincular GitHub
                </a>
              </>
            )}
            {linkError && <Alert variant="critical" title={linkError} />}
          </div>

          {error && <p className="text-base text-f1-foreground-critical">{error}</p>}
          <Button type="submit" loading={updateMe.isPending}>
            Continuar
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

function CreateTeamForm({ onBack, onCreated }: { onBack: () => void; onCreated: (teamId: string) => void }) {
  const createTeam = useCreateTeam();
  const [name, setName] = useState("");
  const [hackathonName, setHackathonName] = useState("");
  // 04-pantallas.md#onboarding: el inicio es "ahora" por defecto.
  const [startsAt, setStartsAt] = useState<Date | undefined>(() => new Date());
  const [endsAt, setEndsAt] = useState<Date>();
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!startsAt || !endsAt) return;
    if (endsAt <= startsAt) {
      setError("El fin tiene que ser posterior al inicio");
      return;
    }
    setError(null);
    try {
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      const team = await createTeam.mutateAsync({
        name,
        hackathon: { name: hackathonName, starts_at: startsAt.toISOString(), ends_at: endsAt.toISOString(), timezone },
      });
      onCreated(team.id);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido crear el equipo");
    }
  }

  return (
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
            <Input id="hackathon-name" required value={hackathonName} onChange={(e) => setHackathonName(e.target.value)} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="starts-at">Fecha de inicio</Label>
            <DatePicker id="starts-at" value={startsAt} onChange={setStartsAt} />
            <p className="text-sm text-f1-foreground-secondary">Importaremos los commits de GitHub desde esta fecha.</p>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ends-at">Fecha de fin</Label>
            <DatePicker
              id="ends-at"
              value={endsAt}
              onChange={setEndsAt}
              disabled={{ before: startsAt && startsAt > new Date() ? startsAt : new Date() }}
            />
          </div>
          {error && <p className="text-base text-f1-foreground-critical">{error}</p>}
          <div className="flex gap-2">
            <Button type="button" variant="ghost" onClick={onBack}>
              Atrás
            </Button>
            <Button type="submit" loading={createTeam.isPending} className="flex-1">
              Crear equipo
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

function RepoStep({ teamId, onNext }: { teamId: string; onNext: () => void }) {
  const { data: repositories } = useRepositories(teamId);
  const hasRepos = (repositories?.length ?? 0) > 0;

  return (
    <StepLayout steps={CREATE_STEPS} current={2}>
      <Card className="w-full max-w-lg">
        <CardHeader>
          <CardTitle>Conecta tu repositorio</CardTitle>
          <CardDescription>
            Pega el repo de GitHub del proyecto. Importaremos los commits desde el inicio del hackathon y los PRs abiertos.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <RepositoryLinker teamId={teamId} returnTo="onboarding" />
          <div className="flex justify-end gap-2">
            {hasRepos ? (
              <Button onClick={onNext}>Continuar</Button>
            ) : (
              <Button variant="ghost" onClick={onNext}>
                Saltar por ahora
              </Button>
            )}
          </div>
        </CardContent>
      </Card>
    </StepLayout>
  );
}

function InviteStep({ teamId }: { teamId: string }) {
  const router = useRouter();
  const { data: team, isLoading } = useTeam(teamId);

  if (isLoading || !team) {
    return (
      <div className="p-6">
        <LoadingState />
      </div>
    );
  }

  const joinUrl = typeof window !== "undefined" ? `${window.location.origin}/onboarding?code=${team.code}` : "";

  return (
    <StepLayout steps={CREATE_STEPS} current={3}>
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Invita a tu equipo</CardTitle>
          <CardDescription>Comparte este código o el enlace</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <p className="rounded-md bg-f1-background-secondary py-3 text-center font-mono text-2xl tracking-wide text-f1-foreground">
            {team.formatted_code}
          </p>
          <Button variant="outline" onClick={() => copyToClipboard(team.code, "Código copiado")}>
            Copiar código
          </Button>
          <Button variant="outline" onClick={() => copyToClipboard(joinUrl, "Enlace copiado")}>
            Copiar enlace de invitación
          </Button>
          <Button onClick={() => router.push(`/t/${team.id}/home`)}>Continuar</Button>
        </CardContent>
      </Card>
    </StepLayout>
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
    <Card className="w-full max-w-sm">
      <CardHeader>
        <CardTitle>Unirme con código</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="code">Código del equipo</Label>
            <Input id="code" required placeholder="XXXX-XXXX" value={code} onChange={(e) => setCode(e.target.value)} />
          </div>
          {error && <p className="text-base text-f1-foreground-critical">{error}</p>}
          <div className="flex gap-2">
            <Button type="button" variant="ghost" onClick={onBack}>
              Atrás
            </Button>
            <Button type="submit" loading={joinTeam.isPending} className="flex-1">
              Unirme
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

export default function OnboardingPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <OnboardingContent />
    </Suspense>
  );
}
