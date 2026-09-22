"use client";

import { use, useState } from "react";
import Link from "next/link";
import { Scale } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
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
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Pros y contras</h1>
        <label className="text-muted-foreground flex items-center gap-2 text-sm">
          <input type="checkbox" checked={onlyIdea} onChange={(e) => setOnlyIdea(e.target.checked)} />
          Solo &ldquo;idea&rdquo;
        </label>
      </div>

      {visible.length === 0 ? (
        <EmptyState icon={Scale} title="No hay features que decidir" />
      ) : (
        <ul className="flex flex-col gap-2">
          {visible.map((feature) => {
            const participants = new Set((feature.arguments ?? []).map((a) => a.author_id)).size;
            return (
              <li key={feature.id} className="flex items-center gap-3 rounded-md border p-3">
                <Badge variant="outline">{feature.key}</Badge>
                <Link href={`/t/${teamId}/features/${feature.key}`} className="flex-1 font-medium hover:underline">
                  {feature.title}
                </Link>
                <span className="text-muted-foreground text-sm">score {feature.score}</span>
                <span className="text-muted-foreground text-sm">{participants} participantes</span>
                {feature.status === "idea" && (
                  <>
                    <Button size="sm" variant="outline" onClick={() => updateFeature.mutate({ key: feature.key, status: "in_progress" })}>
                      Pasar a En curso
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => updateFeature.mutate({ key: feature.key, status: "discarded" })}>
                      Descartar
                    </Button>
                  </>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
