import { Activity, CalendarClock, House, KanbanSquare, Scale, Settings, Sparkles, Target, type LucideIcon } from "lucide-react";

export interface NavItem {
  label: string;
  icon: LucideIcon;
  href: string;
}

// RF-UX-001: menú lateral fijo con iconos de Lucide y texto.
export function navItems(teamId: string): NavItem[] {
  return [
    { label: "Inicio", icon: House, href: `/t/${teamId}/home` },
    { label: "Objetivos", icon: Target, href: `/t/${teamId}/objectives` },
    { label: "Features", icon: KanbanSquare, href: `/t/${teamId}/features` },
    { label: "Pros y contras", icon: Scale, href: `/t/${teamId}/decisions` },
    { label: "Deadlines", icon: CalendarClock, href: `/t/${teamId}/deadlines` },
    { label: "Actividad", icon: Activity, href: `/t/${teamId}/activity` },
    { label: "Análisis IA", icon: Sparkles, href: `/t/${teamId}/analysis` },
    { label: "Equipo y ajustes", icon: Settings, href: `/t/${teamId}/settings` },
  ];
}
