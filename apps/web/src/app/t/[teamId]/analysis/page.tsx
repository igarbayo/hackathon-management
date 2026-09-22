"use client";

import { use } from "react";
import { toast } from "sonner";
import { SparklesIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { Alert } from "@/components/f0/alert";
import { useLatestAnalysis, useRunAnalysis } from "@/hooks/use-analyses";
import { useTeam } from "@/hooks/use-teams";
import { relativeTime } from "@/lib/format-date";
import { ApiError } from "@/lib/api-client";
import type { DeterministicAlert } from "@/types/analysis";
import type { badgeVariants } from "@/components/ui/badge";
import type { VariantProps } from "class-variance-authority";

type BadgeTone = NonNullable<VariantProps<typeof badgeVariants>["variant"]>;

const STATUS_LABEL: Record<string, string> = { covered: "Cubierto", partial: "Parcial", uncovered: "Sin cubrir" };
const STATUS_VARIANT: Record<string, BadgeTone> = {
  covered: "positive",
  partial: "warning",
  uncovered: "destructive",
};
const SEVERITY_LABEL: Record<string, string> = { high: "Alta", medium: "Media", low: "Baja" };
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

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const aiEnabled = team?.settings?.ai_enabled !== false;
  const analysis = data?.analysis;
  const alerts = data?.deterministic_alerts ?? [];

  async function handleRun() {
    try {
      await runAnalysis.mutateAsync();
    } catch (err) {
      if (err instanceof ApiError && err.code === "rate_limited") {
        toast.warning("Se ha alcanzado la cuota de análisis manuales de hoy.");
      }
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        icon={SparklesIcon}
        title="Análisis IA"
        description={
          analysis ? `${analysis.model} · hace ${relativeTime(analysis.finished_at ?? analysis.created_at)}` : undefined
        }
        actions={
          aiEnabled && (
            <Button onClick={handleRun} loading={runAnalysis.isPending}>
              <SparklesIcon className="size-4" /> Analizar ahora
            </Button>
          )
        }
      />

      <AlertsCard alerts={alerts} />

      {!aiEnabled ? (
        <EmptyState icon={SparklesIcon} title="El análisis con IA está desactivado" description="Un owner puede activarlo en Equipo y ajustes." />
      ) : !analysis ? (
        <EmptyState icon={SparklesIcon} title="Todavía no hay ningún análisis" description="Lanza el primero con “Analizar ahora”." />
      ) : (
        <>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Resumen</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-base text-f1-foreground">{analysis.result?.summary}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Cobertura de objetivos</CardTitle>
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
                <CardTitle className="text-base">Esto sobra</CardTitle>
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
                <CardTitle className="text-base">Huecos</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-2">
                {analysis.result?.gaps.map((g, i) => (
                  <div key={i} className="rounded-md border border-f1-border p-2 text-base">
                    {g.objective_key && <Badge variant="outline">{g.objective_key}</Badge>} {g.description}
                    <p className="mt-1 text-sm text-f1-foreground-secondary">Sugerencia: {g.suggested_feature_title}</p>
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
