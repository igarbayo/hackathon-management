import { Sparkles } from "lucide-react";
import { EmptyState } from "@/components/states";

// El análisis de cobertura con Gemini llega con la spec 06.
export default function AnalysisPage() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-2xl font-semibold">Análisis IA</h1>
      <EmptyState
        icon={Sparkles}
        title="El análisis de cobertura todavía no está activo"
        description="Cuando esté disponible, verás aquí la matriz de objetivos y features."
      />
    </div>
  );
}
