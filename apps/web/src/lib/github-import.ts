import type { GithubImport } from "@/types/github";

export function isImporting(lastImport: GithubImport | null | undefined): boolean {
  return lastImport?.status === "queued" || lastImport?.status === "running";
}

function plural(count: number, singular: string, pluralForm: string): string {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}

// RF-GH-025: says what the history import brought, or why nothing.
export function importSummary(lastImport: GithubImport | null | undefined): string | null {
  if (!lastImport) return null;
  if (isImporting(lastImport)) return "Importing history…";
  if (lastImport.status === "failed" && lastImport.reason === "stalled") {
    return "The history import got stuck and did not finish. Try resyncing.";
  }
  if (lastImport.status === "failed") return "Could not import the history. Try resyncing.";

  const pullRequests = plural(lastImport.pull_requests ?? 0, "open PR", "open PRs");
  if (lastImport.reason === "no_starts_at") {
    return `The hackathon has no start date, so no commits were imported. ${pullRequests}.`;
  }

  const since = lastImport.since
    ? new Intl.DateTimeFormat("en-US", { dateStyle: "medium" }).format(new Date(lastImport.since))
    : null;
  const commits = plural(lastImport.commits ?? 0, "commit", "commits");
  const branches = lastImport.branches ? ` from ${plural(lastImport.branches, "branch", "branches")}` : "";
  return `${commits}${branches}${since ? ` since ${since}` : ""} and ${pullRequests}.`;
}
