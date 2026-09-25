"use client";

import { useState } from "react";
import { RefreshCwIcon, Trash2Icon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useLinkRepository, useRepositories, useResyncRepository, useUnlinkRepository } from "@/hooks/use-github";
import { ApiError } from "@/lib/api-client";
import { importSummary } from "@/lib/github-import";

// RF-GH-020: pegar el repo y listo. Lo usan ajustes y el paso de repo del
// onboarding (RF-TEAM-014); `returnTo` decide a dónde vuelve GitHub si hay
// que instalar la App. Debajo de cada repo se ve qué trajo la última
// importación del histórico (RF-GH-025).
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
      setError(err instanceof ApiError ? err.message : "No se ha podido vincular el repositorio");
    }
  }

  return (
    <div className="flex flex-col gap-3">
      {isLoading && <p className="text-base text-f1-foreground-secondary">Cargando…</p>}
      {repositories?.map((repo) => {
        const summary = importSummary(repo.last_import);
        return (
          <div key={repo.id} className="flex flex-col gap-1 rounded-md border border-f1-border p-2 text-base">
            <div className="flex items-center gap-3">
              <Badge variant="positive">Conectado</Badge>
              <span className="flex-1 truncate">{repo.full_name}</span>
              <span className="text-sm text-f1-foreground-secondary">{repo.default_branch}</span>
              <Button
                variant="ghost"
                size="icon"
                aria-label="Resincronizar"
                onClick={() => resyncRepository.mutate(repo.id)}
                disabled={resyncRepository.isPending}
              >
                <RefreshCwIcon className="size-4" />
              </Button>
              <Button variant="ghost" size="icon" aria-label="Desvincular" onClick={() => unlinkRepository.mutate(repo.id)}>
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
        <p className="text-base text-f1-foreground-secondary">Todavía no hay repos vinculados.</p>
      )}

      <form onSubmit={handleAdd} className="flex gap-2">
        <Input
          aria-label="Repositorio de GitHub"
          placeholder="org/repo o https://github.com/org/repo"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <Button type="submit" loading={linkRepository.isPending}>
          Añadir repo
        </Button>
      </form>

      {error && <p className="text-base text-f1-foreground-critical">{error}</p>}

      {installUrl && (
        <div className="rounded-md border border-f1-border p-2 text-base">
          <p>Hace falta instalar la GitHub App para acceder a este repositorio.</p>
          <a href={installUrl} className="text-f1-foreground-accent underline">
            Instalar la App en GitHub
          </a>
        </div>
      )}
    </div>
  );
}
