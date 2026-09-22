"use client";

import { use } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { LoadingState, ErrorState } from "@/components/states";
import { useFeatures } from "@/hooks/use-features";
import type { Feature, FeatureStatus } from "@/types/api";

const COUNTED_STATUSES: FeatureStatus[] = ["idea", "in_progress", "done"];

export function progressByStatus(features: Feature[]) {
  const counted = features.filter((f) => COUNTED_STATUSES.includes(f.status));
  const total = counted.length;
  const byStatus = Object.fromEntries(COUNTED_STATUSES.map((s) => [s, counted.filter((f) => f.status === s).length]));
  const donePercent = total > 0 ? Math.round((byStatus.done / total) * 100) : 0;

  return { total, byStatus, donePercent };
}

export default function HomePage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: features, isLoading, isError, refetch } = useFeatures(teamId);

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-2xl font-semibold">Inicio</h1>

      <Card>
        <CardHeader>
          <CardTitle>Progreso global</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading && <LoadingState rows={1} />}
          {isError && <ErrorState onRetry={() => refetch()} />}
          {features && <ProgressBar features={features} />}
        </CardContent>
      </Card>
    </div>
  );
}

function ProgressBar({ features }: { features: Feature[] }) {
  const { total, byStatus, donePercent } = progressByStatus(features);

  if (total === 0) {
    return <p className="text-muted-foreground text-sm">Todavía no hay features.</p>;
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between text-sm">
        <span>{donePercent}% completado</span>
        <span className="text-muted-foreground">
          {byStatus.done} de {total}
        </span>
      </div>
      <div className="bg-secondary flex h-2 overflow-hidden rounded-full">
        <div className="bg-emerald-500" style={{ width: `${(byStatus.done / total) * 100}%` }} />
        <div className="bg-amber-500" style={{ width: `${(byStatus.in_progress / total) * 100}%` }} />
        <div className="bg-muted-foreground/30" style={{ width: `${(byStatus.idea / total) * 100}%` }} />
      </div>
    </div>
  );
}
