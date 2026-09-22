"use client";

import { use } from "react";
import { HouseIcon } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { LoadingState, ErrorState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { BigNumber } from "@/components/f0/big-number";
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
      <PageHeader icon={HouseIcon} title="Inicio" />

      <Card>
        <CardHeader>
          <CardTitle>Progreso global</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading && <LoadingState rows={1} />}
          {isError && <ErrorState onRetry={() => refetch()} />}
          {features && <Progress features={features} />}
        </CardContent>
      </Card>
    </div>
  );
}

function Progress({ features }: { features: Feature[] }) {
  const { total, byStatus, donePercent } = progressByStatus(features);

  if (total === 0) {
    return <p className="text-muted-foreground text-base">Todavía no hay features.</p>;
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-6">
        <BigNumber value={`${donePercent}%`} label="Completado" tone="positive" />
        <BigNumber value={byStatus.done} label="Hechas" tone="positive" />
        <BigNumber value={byStatus.in_progress} label="En curso" tone="warning" />
        <BigNumber value={byStatus.idea} label="Idea" tone="neutral" />
      </div>
      <div className="flex h-2 overflow-hidden rounded-full bg-f1-background-secondary">
        <div className="bg-f1-background-positive-bold" style={{ width: `${(byStatus.done / total) * 100}%` }} />
        <div className="bg-f1-background-warning-bold" style={{ width: `${(byStatus.in_progress / total) * 100}%` }} />
      </div>
    </div>
  );
}
