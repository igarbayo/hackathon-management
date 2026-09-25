"use client";

import { useState } from "react";
import { RefreshCwIcon, Trash2Icon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useLinkRepository, useRepositories, useResyncRepository, useUnlinkRepository } from "@/hooks/use-github";
import { ApiError } from "@/lib/api-client";
import { importSummary } from "@/lib/github-import";

// RF-GH-020: paste the repo and you are done. Used by settings and by the
// onboarding repo step (RF-TEAM-014); `returnTo` decides where GitHub goes
// back to if the App has to be installed. Under each repo it shows what the
// last history import brought (RF-GH-025).
export function RepositoryLinker({ teamId, returnTo = "settings" }: { teamId: string; returnTo?: "settings" | "onboarding" }) {
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
      const result = await linkRepository.mutateAsync({ url: input.trim(), returnTo });
      if (result.needs_install && result.install_url) {
        setInstallUrl(result.install_url);
      } else {
        setInput("");
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Could not link the repository");
    }
  }

  return (
    <div className="flex flex-col gap-3">
      {isLoading && <p className="text-base text-f1-foreground-secondary">Loading…</p>}
      {repositories?.map((repo) => {
        const summary = importSummary(repo.last_import);
        return (
          <div key={repo.id} className="flex flex-col gap-1 rounded-md border border-f1-border p-2 text-base">
            <div className="flex items-center gap-3">
              <Badge variant="positive">Connected</Badge>
              <span className="flex-1 truncate">{repo.full_name}</span>
              <span className="text-sm text-f1-foreground-secondary">{repo.default_branch}</span>
              <Button
                variant="ghost"
                size="icon"
                aria-label="Resync"
                onClick={() => resyncRepository.mutate(repo.id)}
                disabled={resyncRepository.isPending}
              >
                <RefreshCwIcon className="size-4" />
              </Button>
              <Button variant="ghost" size="icon" aria-label="Unlink" onClick={() => unlinkRepository.mutate(repo.id)}>
                <Trash2Icon className="size-4" />
              </Button>
            </div>
            {summary && (
              <p
                className={
                  repo.last_import?.status === "failed"
                    ? "text-sm text-f1-foreground-critical"
                    : "text-sm text-f1-foreground-secondary"
                }
              >
                {summary}
              </p>
            )}
          </div>
        );
      })}
      {repositories?.length === 0 && (
        <p className="text-base text-f1-foreground-secondary">No linked repos yet.</p>
      )}

      <form onSubmit={handleAdd} className="flex gap-2">
        <Input
          aria-label="GitHub repository"
          placeholder="org/repo or https://github.com/org/repo"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <Button type="submit" loading={linkRepository.isPending}>
          Add repo
        </Button>
      </form>

      {error && <p className="text-base text-f1-foreground-critical">{error}</p>}

      {installUrl && (
        <div className="rounded-md border border-f1-border p-2 text-base">
          <p>You need to install the GitHub App to access this repository.</p>
          <a href={installUrl} className="text-f1-foreground-accent underline">
            Install the App on GitHub
          </a>
        </div>
      )}
    </div>
  );
}
