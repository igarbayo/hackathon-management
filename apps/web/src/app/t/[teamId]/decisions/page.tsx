"use client";

import { use, useState } from "react";
import Link from "next/link";
import { ScaleIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { useFeatures, useUpdateFeature } from "@/hooks/use-features";

// RF-PC-010/013: lista de features en idea (por defecto) o todas, con
// score, participantes y acciones de decisión rápidas.
export default function DecisionsPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: features, isLoading, isError, refetch } = useFeatures(teamId);
  const updateFeature = useUpdateFeature(teamId);
  const [onlyIdea, setOnlyIdea] = useState(true);

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const visible = (features ?? []).filter((f) => !onlyIdea || f.status === "idea");

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        icon={ScaleIcon}
        title="Pros y contras"
        actions={
          <label className="flex items-center gap-2 text-sm text-f1-foreground-secondary">
            <Switch size="sm" checked={onlyIdea} onCheckedChange={setOnlyIdea} />
            Solo &ldquo;idea&rdquo;
          </label>
        }
      />

      {visible.length === 0 ? (
        <EmptyState icon={ScaleIcon} title="No hay features que decidir" />
      ) : (
        <Card className="divide-y divide-f1-border-secondary py-0">
          {visible.map((feature) => {
            const participants = new Set((feature.arguments ?? []).map((a) => a.author_id)).size;
            return (
              <div key={feature.id} className="flex items-center gap-3 px-3 py-2.5">
                <Badge variant="outline">{feature.key}</Badge>
                <Link
                  href={`/t/${teamId}/features/${feature.key}`}
                  className="flex-1 font-medium text-f1-foreground hover:underline"
                >
                  {feature.title}
                </Link>
                <span className="text-sm text-f1-foreground-secondary">score {feature.score}</span>
                <span className="text-sm text-f1-foreground-secondary">{participants} participantes</span>
                {feature.status === "idea" && (
                  <>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => updateFeature.mutate({ key: feature.key, status: "in_progress" })}
                    >
                      Pasar a En curso
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => updateFeature.mutate({ key: feature.key, status: "discarded" })}
                    >
                      Descartar
                    </Button>
                  </>
                )}
              </div>
            );
          })}
        </Card>
      )}
    </div>
  );
}
