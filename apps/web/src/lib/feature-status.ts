import type { FeatureStatus } from "@/types/api";
import type { badgeVariants } from "@/components/ui/badge";
import type { VariantProps } from "class-variance-authority";

type BadgeTone = NonNullable<VariantProps<typeof badgeVariants>["variant"]>;

/**
 * Etiqueta en español y tono F0 (badgeVariants) de cada estado de feature,
 * compartido entre el kanban, objetivos (conteos por estado) y decisiones.
 */
export const FEATURE_STATUS_META: Record<FeatureStatus, { label: string; tone: BadgeTone; dot: string }> = {
  idea: { label: "Idea", tone: "secondary", dot: "bg-f1-icon" },
  in_progress: { label: "En curso", tone: "info", dot: "bg-f1-icon-info" },
  done: { label: "Hecha", tone: "positive", dot: "bg-f1-icon-positive" },
  discarded: { label: "Descartada", tone: "warning", dot: "bg-f1-icon-warning" },
};
