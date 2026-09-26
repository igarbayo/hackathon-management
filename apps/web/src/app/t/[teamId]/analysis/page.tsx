"use client";

import { use, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { SparklesIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { Alert } from "@/components/f0/alert";
import { isAnalysisInProgress, useAnalysisHistory, useLatestAnalysis, useRunAnalysis } from "@/hooks/use-analyses";
import { useTeam } from "@/hooks/use-teams";
import { relativeTime } from "@/lib/format-date";
import { ApiError } from "@/lib/api-client";
import type { AiAnalysis, DeterministicAlert } from "@/types/analysis";
import type { badgeVariants } from "@/components/ui/badge";
import type { VariantProps } from "class-variance-authority";

type BadgeTone = NonNullable<VariantProps<typeof badgeVariants>["variant"]>;

const STATUS_LABEL: Record<string, string> = { covered: "Covered", partial: "Partial", uncovered: "Not covered" };
const STATUS_VARIANT: Record<string, BadgeTone> = {
  covered: "positive",
  partial: "warning",
  uncovered: "destructive",
};
const SEVERITY_LABEL: Record<string, string> = { high: "High", medium: "Medium", low: "Low" };
const SEVERITY_ALERT_VARIANT: Record<string, "critical" | "warning" | "neutral"> = {
  high: "critical",
  medium: "warning",
  low: "neutral",
};
const SEVERITY_BADGE_VARIANT: Record<string, BadgeTone> = {
  high: "destructive",
  medium: "warning",
  low: "secondary",
};

export default function AnalysisPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: team } = useTeam(teamId);
  const { data, isLoading, isError, refetch } = useLatestAnalysis(teamId);
  const runAnalysis = useRunAnalysis(teamId);
  const { data: history } = useAnalysisHistory(teamId);
  const newest = history?.[0];
  const inProgress = isAnalysisInProgress(newest);
  // The analysis this person just launched: when it finishes, they are told
  // how it went (before, a failed or skipped run looked like nothing happened).
  const [launchedId, setLaunchedId] = useState<string | null>(null);
  const notifiedId = useRef<string | null>(null);

  useEffect(() => {
    if (!launchedId || newest?.id !== launchedId || isAnalysisInProgress(newest)) return;
    if (notifiedId.current === launchedId) return;

    notifiedId.current = launchedId;
    refetch();
    notifyFinished(newest);
  }, [launchedId, newest, refetch]);

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const aiEnabled = team?.settings?.ai_enabled !== false;
  const analysis = data?.analysis;
  const alerts = data?.deterministic_alerts ?? [];

  async function handleRun() {
    try {
      const queued = await runAnalysis.mutateAsync();
      setLaunchedId(queued.id);
    } catch (err) {
      if (err instanceof ApiError && err.code === "rate_limited") {
        toast.warning("You have reached today's limit of manual analyses.");
      } else if (err instanceof ApiError && err.code === "missing_gemini_api_key") {
        toast.warning("Set up your Gemini key in Team and settings to run an analysis.");
      } else {
        toast.error(err instanceof ApiError ? `Could not start the analysis: ${err.message}` : "Could not start the analysis");
      }
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        icon={SparklesIcon}
        title="AI analysis"
        description={
          analysis ? `${analysis.model} · ${relativeTime(analysis.finished_at ?? analysis.created_at)}` : undefined
        }
        actions={
          aiEnabled && (
            <Button onClick={handleRun} loading={runAnalysis.isPending || inProgress}>
              <SparklesIcon className="size-4" /> {inProgress ? "Analyzing…" : "Analyze now"}
            </Button>
          )
        }
      />

      {newest?.status === "failed" && (
        <Alert
          variant="critical"
          title={`The last analysis failed ${relativeTime(newest.finished_at ?? newest.created_at)}`}
          description={newest.error ?? undefined}
        />
      )}

      <AlertsCard alerts={alerts} />

      {!aiEnabled ? (
        <EmptyState icon={SparklesIcon} title="AI analysis is turned off" description="An owner can turn it on in Team and settings." />
      ) : !analysis ? (
        <EmptyState icon={SparklesIcon} title="No analyses yet" description="Run the first one with “Analyze now”." />
      ) : (
        <>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Summary</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-base text-f1-foreground">{analysis.result?.summary}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Objective coverage</CardTitle>
            </CardHeader>
            <CardContent className="flex flex-col gap-2">
              {analysis.result?.coverage.map((entry) => (
                <div key={entry.objective_key} className="flex items-start gap-3 rounded-md border border-f1-border p-2 text-base">
                  <Badge variant="outline">{entry.objective_key}</Badge>
                  <Badge variant={STATUS_VARIANT[entry.status]}>{STATUS_LABEL[entry.status]}</Badge>
                  <div className="flex-1">
                    <p>{entry.rationale}</p>
                    {entry.feature_keys.length > 0 && (
                      <p className="mt-1 text-sm text-f1-foreground-secondary">{entry.feature_keys.join(", ")}</p>
                    )}
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>

          {(analysis.result?.orphan_features.length ?? 0) > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Not needed</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-2">
                {analysis.result?.orphan_features.map((o) => (
                  <div key={o.feature_key} className="rounded-md border border-f1-border p-2 text-base">
                    <Badge variant="outline">{o.feature_key}</Badge> {o.rationale}
                  </div>
                ))}
              </CardContent>
            </Card>
          )}

          {(analysis.result?.gaps.length ?? 0) > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Gaps</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-2">
                {analysis.result?.gaps.map((g, i) => (
                  <div key={i} className="rounded-md border border-f1-border p-2 text-base">
                    {g.objective_key && <Badge variant="outline">{g.objective_key}</Badge>} {g.description}
                    <p className="mt-1 text-sm text-f1-foreground-secondary">Suggestion: {g.suggested_feature_title}</p>
                  </div>
                ))}
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  );
}

function notifyFinished(analysis: AiAnalysis) {
  if (analysis.status === "succeeded") {
    toast.success("Analysis ready");
  } else if (analysis.status === "failed") {
    toast.error(analysis.error ? `The analysis failed: ${analysis.error}` : "The analysis failed");
  } else if (analysis.skip_reason === "no_changes") {
    toast.info("Nothing changed since the last analysis, so it was not run again.");
  } else if (analysis.skip_reason === "no_api_key") {
    toast.warning("Set up your Gemini key in Team and settings to run an analysis.");
  }
}

function AlertsCard({ alerts }: { alerts: DeterministicAlert[] }) {
  if (alerts.length === 0) return null;

  return (
    <div className="flex flex-col gap-2">
      {alerts.map((alert, i) => (
        <Alert
          key={i}
          variant={SEVERITY_ALERT_VARIANT[alert.severity]}
          title={
            <span className="flex items-center gap-2">
              <Badge variant={SEVERITY_BADGE_VARIANT[alert.severity]}>{SEVERITY_LABEL[alert.severity]}</Badge>
              {alert.code}
            </span>
          }
          description={alert.related_keys.length > 0 ? alert.related_keys.join(", ") : undefined}
        />
      ))}
    </div>
  );
}
