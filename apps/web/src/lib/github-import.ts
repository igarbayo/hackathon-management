import type { GithubImport } from "@/types/github";

export function isImporting(lastImport: GithubImport | null | undefined): boolean {
  return lastImport?.status === "queued" || lastImport?.status === "running";
}

function plural(count: number, singular: string, pluralForm: string): string {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}

// RF-GH-025: cuenta qué trajo la importación del histórico, o por qué nada.
export function importSummary(lastImport: GithubImport | null | undefined): string | null {
  if (!lastImport) return null;
  if (isImporting(lastImport)) return "Importando el histórico…";
  if (lastImport.status === "failed") return "No se ha podido importar el histórico. Prueba a resincronizar.";

  const pullRequests = plural(lastImport.pull_requests ?? 0, "PR abierto", "PRs abiertos");
  if (lastImport.reason === "no_starts_at") {
    return `El hackathon no tiene fecha de inicio, así que no se han importado commits. ${pullRequests}.`;
  }

  const since = lastImport.since
    ? new Intl.DateTimeFormat("es-ES", { dateStyle: "medium" }).format(new Date(lastImport.since))
    : null;
  const commits = plural(lastImport.commits ?? 0, "commit", "commits");
  const branches = lastImport.branches ? ` de ${plural(lastImport.branches, "rama", "ramas")}` : "";
  return `${commits}${branches}${since ? ` desde el ${since}` : ""} y ${pullRequests}.`;
}
