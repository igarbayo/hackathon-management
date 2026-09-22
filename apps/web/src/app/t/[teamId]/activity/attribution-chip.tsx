"use client";

import { useState } from "react";
import { Check, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Feature } from "@/types/api";
import type { Attribution } from "@/types/activity";

// RF-ACT-012: confirmada (sólido), sugerida (con ✓/✗) o sin atribuir (Asignar a…).
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
    return (
      <div className="flex items-center gap-1">
        <Badge variant="outline" title={attribution.reason ?? undefined}>
          {feature?.key ?? "F-?"}?
        </Badge>
        <Button variant="ghost" size="icon-xs" aria-label="Confirmar" onClick={onConfirm}>
          <Check className="size-3.5" />
        </Button>
        <Button variant="ghost" size="icon-xs" aria-label="Rechazar" onClick={onReject}>
          <X className="size-3.5" />
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
        <SelectTrigger className="h-6 w-32 text-xs">
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
