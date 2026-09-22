"use client";

import { useState } from "react";
import { MenuIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { useMe } from "@/hooks/use-me";
import { useTeam } from "@/hooks/use-teams";
import { SidebarFooter } from "./sidebar-footer";
import { SidebarNav } from "./sidebar-nav";
import { TeamSelector } from "./team-selector";

// Calcado de ApplicationFrame/Sidebar de F0: la página vive sobre un fondo
// f1-special-page, y tanto el sidebar como el contenido son paneles
// flotantes (borde, radio y sombra), separados por un margen de 8px.
// RF-UX-001: sidebar completo a partir de 1024px, solo iconos entre 768 y
// 1023px, y drawer por debajo de 768px.
export function AppShell({ teamId, children }: { teamId: string; children: React.ReactNode }) {
  const { data: me } = useMe();
  const { data: team } = useTeam(teamId);
  const [drawerOpen, setDrawerOpen] = useState(false);

  return (
    <div className="min-h-screen bg-f1-special-page">
      <div className="flex min-h-screen gap-2 p-2">
        <aside className="hidden w-56 shrink-0 flex-col rounded-xl border border-f1-border-secondary bg-f1-background shadow-lg lg:flex">
          <SidebarHeader teamId={teamId} memberships={me?.memberships} hackathonName={team?.hackathon?.name} />
          <div className="flex-1 overflow-y-auto">
            <SidebarNav teamId={teamId} />
          </div>
          <SidebarFooter me={me} />
        </aside>

        <aside className="hidden w-14 shrink-0 flex-col items-center rounded-xl border border-f1-border-secondary bg-f1-background shadow-lg md:flex lg:hidden">
          <div className="flex-1 overflow-y-auto">
            <SidebarNav teamId={teamId} iconOnly />
          </div>
          <SidebarFooter me={me} iconOnly />
        </aside>

        <div className="flex min-w-0 flex-1 flex-col gap-2">
          <header className="flex items-center gap-3 rounded-xl border border-f1-border-secondary bg-f1-background px-3 py-2.5 shadow-sm lg:hidden">
            <Sheet open={drawerOpen} onOpenChange={setDrawerOpen}>
              <SheetTrigger
                render={<Button variant="ghost" size="icon" aria-label="Abrir menú" />}
              >
                <MenuIcon />
              </SheetTrigger>
              <SheetContent side="left" className="w-64 p-0">
                <SheetTitle className="sr-only">Menú</SheetTitle>
                <div className="flex h-full flex-col">
                  <SidebarHeader teamId={teamId} memberships={me?.memberships} hackathonName={team?.hackathon?.name} />
                  <div className="flex-1 overflow-y-auto">
                    <SidebarNav teamId={teamId} />
                  </div>
                  <SidebarFooter me={me} />
                </div>
              </SheetContent>
            </Sheet>
            <span className="truncate text-base font-semibold text-f1-foreground">{team?.hackathon?.name}</span>
          </header>

          <main className="min-w-0 flex-1 rounded-xl border border-f1-border-secondary bg-f1-background p-4 shadow md:p-6">
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}

function SidebarHeader({
  teamId,
  memberships,
  hackathonName,
}: {
  teamId: string;
  memberships: { team_id: string; team_name: string | null; role: "owner" | "member" }[] | undefined;
  hackathonName: string | null | undefined;
}) {
  return (
    <div className="flex flex-col gap-1 border-b border-f1-border-secondary p-3">
      {memberships && <TeamSelector memberships={memberships} currentTeamId={teamId} />}
      {hackathonName && <p className="truncate text-sm text-f1-foreground-secondary">{hackathonName}</p>}
    </div>
  );
}
