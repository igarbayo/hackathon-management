import { Activity, CalendarClock, House, KanbanSquare, Scale, Settings, Sparkles, Target, type LucideIcon } from "lucide-react";

export interface NavItem {
  label: string;
  icon: LucideIcon;
  href: string;
}

// RF-UX-001: fixed side menu with Lucide icons and text.
export function navItems(teamId: string): NavItem[] {
  return [
    { label: "Home", icon: House, href: `/t/${teamId}/home` },
    { label: "Objectives", icon: Target, href: `/t/${teamId}/objectives` },
    { label: "Features", icon: KanbanSquare, href: `/t/${teamId}/features` },
    { label: "Pros and cons", icon: Scale, href: `/t/${teamId}/decisions` },
    { label: "Deadlines", icon: CalendarClock, href: `/t/${teamId}/deadlines` },
    { label: "Activity", icon: Activity, href: `/t/${teamId}/activity` },
    { label: "AI analysis", icon: Sparkles, href: `/t/${teamId}/analysis` },
    { label: "Team and settings", icon: Settings, href: `/t/${teamId}/settings` },
  ];
}
