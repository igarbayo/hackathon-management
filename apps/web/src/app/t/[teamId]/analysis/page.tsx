"use client";

import { use } from "react";
import { AlertTriangle, Sparkles } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { useLatestAnalysis, useRunAnalysis } from "@/hooks/use-analyses";
import { useTeam } from "@/hooks/use-teams";
import { relativeTime } from "@/lib/format-date";
import { ApiError } from "@/lib/api-client";
import type { DeterministicAlert } from "@/types/analysis";

const STATUS_LABEL: Record<string, string> = { covered: "Cubierto", partial: "Parcial", uncovered: "Sin cubrir" };
const STATUS_VARIANT: Record<string, "default" | "secondary" | "outline"> = {
  covered: "default",
  partial: "secondary",
  uncovered: "outline",
};
const SEVERITY_LABEL: Record<string, string> = { high: "Alta", medium: "Media", low: "Baja" };

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
        alert("Se ha alcanzado la cuota de análisis manuales de hoy.");
      }
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Análisis IA</h1>
          {analysis && (
            <p className="text-muted-foreground text-sm">
              {analysis.model} · hace {relativeTime(analysis.finished_at ?? analysis.created_at)}
            </p>
          )}
        </div>
        {aiEnabled && (
          <Button onClick={handleRun} disabled={runAnalysis.isPending}>
            <Sparkles className="size-4" /> {runAnalysis.isPending ? "Lanzando…" : "Analizar ahora"}
          </Button>
        )}
      </div>

      <AlertsCard alerts={alerts} />

      {!aiEnabled ? (
        <EmptyState icon={Sparkles} title="El análisis con IA está desactivado" description="Un owner puede activarlo en Equipo y ajustes." />
      ) : !analysis ? (
        <EmptyState icon={Sparkles} title="Todavía no hay ningún análisis" description="Lanza el primero con “Analizar ahora”." />
      ) : (
        <>
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Resumen</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm">{analysis.result?.summary}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Cobertura de objetivos</CardTitle>
            </CardHeader>
            <CardContent className="flex flex-col gap-2">
              {analysis.result?.coverage.map((entry) => (
                <div key={entry.objective_key} className="flex items-start gap-3 rounded-md border p-2 text-sm">
                  <Badge variant="outline">{entry.objective_key}</Badge>
                  <Badge variant={STATUS_VARIANT[entry.status]}>{STATUS_LABEL[entry.status]}</Badge>
                  <div className="flex-1">
                    <p>{entry.rationale}</p>
                    {entry.feature_keys.length > 0 && (
                      <p className="text-muted-foreground mt-1 text-xs">{entry.feature_keys.join(", ")}</p>
                    )}
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>

          {(analysis.result?.orphan_features.length ?? 0) > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Esto sobra</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-2">
                {analysis.result?.orphan_features.map((o) => (
                  <div key={o.feature_key} className="rounded-md border p-2 text-sm">
                    <Badge variant="outline">{o.feature_key}</Badge> {o.rationale}
                  </div>
                ))}
              </CardContent>
            </Card>
          )}

          {(analysis.result?.gaps.length ?? 0) > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Huecos</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-2">
                {analysis.result?.gaps.map((g, i) => (
                  <div key={i} className="rounded-md border p-2 text-sm">
                    {g.objective_key && <Badge variant="outline">{g.objective_key}</Badge>} {g.description}
                    <p className="text-muted-foreground mt-1 text-xs">Sugerencia: {g.suggested_feature_title}</p>
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
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Alertas</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {alerts.map((alert, i) => (
          <div key={i} className="flex items-center gap-2 rounded-md border p-2 text-sm">
            <AlertTriangle className="text-muted-foreground size-4 shrink-0" />
            <Badge variant={alert.severity === "high" ? "default" : "secondary"}>{SEVERITY_LABEL[alert.severity]}</Badge>
            <span className="flex-1">{alert.code}</span>
            {alert.related_keys.length > 0 && (
              <span className="text-muted-foreground text-xs">{alert.related_keys.join(", ")}</span>
            )}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
