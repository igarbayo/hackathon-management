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

// 04-pantallas.md#onboarding: Profile → Team → (if they create it) Repository →
// Invite. The repo and invite steps are resumed through the URL
// (`?team=<id>&step=repo|invite`), because installing the GitHub App leaves
// the web and comes back here (RF-TEAM-014).
const CREATE_STEPS = ["Profile", "Team", "Repository", "Invite"];
const JOIN_STEPS = ["Profile", "Team"];

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
    <ol className="flex flex-wrap items-center justify-center gap-2 text-sm" aria-label="Onboarding steps">
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

  // Steps after creating the team, resumable after installing the App.
  if (teamId && step === "repo") {
    return <RepoStep teamId={teamId} onNext={() => router.replace(`/onboarding?team=${teamId}&step=invite`)} />;
  }
  if (teamId && step === "invite") return <InviteStep teamId={teamId} />;

  const steps = mode === "join" ? JOIN_STEPS : CREATE_STEPS;

  // RF-TEAM-014: people without a team set up their profile first.
  if (!me.profile_completed && me.memberships.length === 0) {
    return (
      <StepLayout steps={steps} current={0}>
        <ProfileStep me={me} githubLink={searchParams.get("github_link")} inviteCode={code} />
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
          <h1 className="text-xl font-semibold text-f1-foreground">Choose a team</h1>
          {me.memberships.map((membership) => (
            <Card
              key={membership.team_id}
              className="cursor-pointer transition-colors hover:border-f1-border-hover hover:shadow-md"
              onClick={() => router.push(`/t/${membership.team_id}/home`)}
            >
              <CardHeader>
                <CardTitle>{membership.team_name}</CardTitle>
                <CardDescription>{membership.role === "owner" ? "Owner" : "Member"}</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
      )}

      <div className="flex flex-col items-center gap-4">
        <h2 className={hasTeams ? "text-muted-foreground text-base" : "text-xl font-semibold text-f1-foreground"}>
          {hasTeams ? "Or start another team" : "How do you want to start?"}
        </h2>
        <div className="flex flex-wrap justify-center gap-4">
          <Card
            className="w-56 cursor-pointer transition-colors hover:border-f1-border-hover hover:shadow-md"
            onClick={() => setMode("create")}
          >
            <CardHeader>
              <CardTitle>Create team</CardTitle>
              <CardDescription>Start a new hackathon</CardDescription>
            </CardHeader>
          </Card>
          <Card
            className="w-56 cursor-pointer transition-colors hover:border-f1-border-hover hover:shadow-md"
            onClick={() => setMode("join")}
          >
            <CardHeader>
              <CardTitle>Join with a code</CardTitle>
              <CardDescription>I already have my team&apos;s code</CardDescription>
            </CardHeader>
          </Card>
        </div>
      </div>
    </div>
  );
}

const GITHUB_LINK_ERRORS: Record<string, string> = {
  taken: "That GitHub account is already linked to another Hackboard user.",
  error: "Could not link GitHub. Please try again.",
};

// RF-TEAM-014: name, photo and GitHub account. Linking GitHub means commits
// are assigned to the person automatically (RF-GH-024), so it is recommended,
// but they can continue without it.
function ProfileStep({ me, githubLink, inviteCode }: { me: Me; githubLink: string | null; inviteCode: string | null }) {
  const updateMe = useUpdateMe();
  const [name, setName] = useState(me.name);
  const [error, setError] = useState<string | null>(null);
  const linkError = githubLink ? GITHUB_LINK_ERRORS[githubLink] : undefined;
  // Coming back from GitHub keeps the invite code, if there was one.
  const returnTo = inviteCode ? `/onboarding?code=${encodeURIComponent(inviteCode)}` : "/onboarding";
  const githubHref = `${API_URL}/api/v1/auth/github?link=1&return_to=${encodeURIComponent(returnTo)}`;

  useEffect(() => {
    if (githubLink === "linked") toast.success("GitHub linked");
  }, [githubLink]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await updateMe.mutateAsync({ name: name.trim(), profile_completed: true });
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Could not save the profile");
    }
  }

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <CardTitle>Your profile</CardTitle>
        <CardDescription>This is how your team will see you on the board and in the activity.</CardDescription>
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
              <Label htmlFor="profile-name">Name</Label>
              <Input id="profile-name" required maxLength={80} value={name} onChange={(e) => setName(e.target.value)} />
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <Label>GitHub</Label>
            {me.github_login ? (
              <p className="flex items-center gap-2 text-base text-f1-foreground">
                <GitHubLogo />
                Linked as <span className="font-medium">@{me.github_login}</span>
              </p>
            ) : (
              <>
                <p className="text-base text-f1-foreground-secondary">
                  Link your account so your commits are assigned to you automatically, without claiming them.
                </p>
                <a href={githubHref} className={cn(buttonVariants({ variant: "outline" }), "self-start")}>
                  <GitHubLogo />
                  Link GitHub
                </a>
              </>
            )}
            {linkError && <Alert variant="critical" title={linkError} />}
          </div>

          {error && <p className="text-base text-f1-foreground-critical">{error}</p>}
          <Button type="submit" loading={updateMe.isPending}>
            Continue
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
  // 04-pantallas.md#onboarding: the start is "now" by default.
  const [startsAt, setStartsAt] = useState<Date | undefined>(() => new Date());
  const [endsAt, setEndsAt] = useState<Date>();
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!startsAt || !endsAt) return;
    if (endsAt <= startsAt) {
      setError("The end must be after the start");
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
      setError(err instanceof ApiError ? err.message : "Could not create the team");
    }
  }

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <CardTitle>Create team</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="team-name">Team name</Label>
            <Input id="team-name" required value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="hackathon-name">Hackathon name</Label>
            <Input id="hackathon-name" required value={hackathonName} onChange={(e) => setHackathonName(e.target.value)} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="starts-at">Start date</Label>
            <DatePicker id="starts-at" value={startsAt} onChange={setStartsAt} />
            <p className="text-sm text-f1-foreground-secondary">We will import GitHub commits from this date.</p>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ends-at">End date</Label>
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
              Back
            </Button>
            <Button type="submit" loading={createTeam.isPending} className="flex-1">
              Create team
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
          <CardTitle>Connect your repository</CardTitle>
          <CardDescription>
            Paste the project&apos;s GitHub repo. We will import the commits since the hackathon start and the open PRs.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <RepositoryLinker teamId={teamId} returnTo="onboarding" />
          <div className="flex justify-end gap-2">
            {hasRepos ? (
              <Button onClick={onNext}>Continue</Button>
            ) : (
              <Button variant="ghost" onClick={onNext}>
                Skip for now
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
          <CardTitle>Invite your team</CardTitle>
          <CardDescription>Share this code or the link</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <p className="rounded-md bg-f1-background-secondary py-3 text-center font-mono text-2xl tracking-wide text-f1-foreground">
            {team.formatted_code}
          </p>
          <Button variant="outline" onClick={() => copyToClipboard(team.code, "Code copied")}>
            Copy code
          </Button>
          <Button variant="outline" onClick={() => copyToClipboard(joinUrl, "Link copied")}>
            Copy invite link
          </Button>
          <Button onClick={() => router.push(`/t/${team.id}/home`)}>Continue</Button>
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
      setError(err instanceof ApiError ? err.message : "Invalid code");
    }
  }

  return (
    <Card className="w-full max-w-sm">
      <CardHeader>
        <CardTitle>Join with a code</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="code">Team code</Label>
            <Input id="code" required placeholder="XXXX-XXXX" value={code} onChange={(e) => setCode(e.target.value)} />
          </div>
          {error && <p className="text-base text-f1-foreground-critical">{error}</p>}
          <div className="flex gap-2">
            <Button type="button" variant="ghost" onClick={onBack}>
              Back
            </Button>
            <Button type="submit" loading={joinTeam.isPending} className="flex-1">
              Join
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
