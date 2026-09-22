import { Activity } from "lucide-react";
import { EmptyState } from "@/components/states";

// El feed real llega con la integración de GitHub y Claude Code
// (specs 05, 07, 08). De momento, placeholder honesto.
export default function ActivityPage() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-2xl font-semibold">Actividad</h1>
      <EmptyState
        icon={Activity}
        title="Todavía no hay actividad que mostrar"
        description="El feed se llena en cuanto conectéis GitHub o Claude Code."
      />
    </div>
  );
}
