"use client";

import { useState } from "react";
import { CheckIcon, XIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import type { Feature } from "@/types/api";
import type { Attribution } from "@/types/activity";

// RF-ACT-012: confirmada (sólido), sugerida (borde discontinuo, con ✓/✗ y
// el motivo en un tooltip) o sin atribuir (Asignar a…).
export function AttributionChip({
  attribution,
  features,
  onConfirm,
  onReject,
  onAssign,
}: {
  attribution: Attribution | null;
  features: Feature[];
  onConfirm: () => void;
  onReject: () => void;
  onAssign: (featureId: string) => void;
}) {
  const [assigning, setAssigning] = useState(false);
  const feature = attribution?.feature_id ? features.find((f) => f.id === attribution.feature_id) : undefined;

  if (attribution?.status === "confirmed") {
    return (
      <Badge title={attribution.reason ?? undefined}>
        {feature?.key ?? "F-?"} · {attribution.method}
      </Badge>
    );
  }

  if (attribution?.status === "suggested") {
    const suggestedBadge = <Badge variant="outline-dashed">{feature?.key ?? "F-?"}?</Badge>;
    return (
      <div className="flex items-center gap-1">
        {attribution.reason ? (
          <Tooltip>
            <TooltipTrigger>{suggestedBadge}</TooltipTrigger>
            <TooltipContent>{attribution.reason}</TooltipContent>
          </Tooltip>
        ) : (
          suggestedBadge
        )}
        <Button variant="ghost" size="icon-xs" aria-label="Confirmar" onClick={onConfirm}>
          <CheckIcon className="size-3.5" />
        </Button>
        <Button variant="ghost" size="icon-xs" aria-label="Rechazar" onClick={onReject}>
          <XIcon className="size-3.5" />
        </Button>
      </div>
    );
  }

  if (assigning) {
    return (
      <Select
        onValueChange={(featureId: string | null) => {
          if (featureId) onAssign(featureId);
          setAssigning(false);
        }}
      >
        <SelectTrigger className="h-6 w-32 text-sm" data-size="sm">
          <SelectValue placeholder="Elige…" />
        </SelectTrigger>
        <SelectContent>
          {features.map((f) => (
            <SelectItem key={f.id} value={f.id}>
              {f.key} · {f.title}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    );
  }

  return (
    <Button variant="outline" size="xs" onClick={() => setAssigning(true)}>
      Asignar a…
    </Button>
  );
}
