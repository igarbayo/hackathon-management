import type { FeatureStatus } from "@/types/api";
import type { badgeVariants } from "@/components/ui/badge";
import type { VariantProps } from "class-variance-authority";

type BadgeTone = NonNullable<VariantProps<typeof badgeVariants>["variant"]>;

/**
 * Label and F0 tone (badgeVariants) of each feature status, shared by the
 * kanban, objectives (counts by status) and decisions.
 */
export const FEATURE_STATUS_META: Record<FeatureStatus, { label: string; tone: BadgeTone; dot: string }> = {
  idea: { label: "Idea", tone: "secondary", dot: "bg-f1-icon" },
  in_progress: { label: "In progress", tone: "info", dot: "bg-f1-icon-info" },
  done: { label: "Done", tone: "positive", dot: "bg-f1-icon-positive" },
  discarded: { label: "Dropped", tone: "warning", dot: "bg-f1-icon-warning" },
};
