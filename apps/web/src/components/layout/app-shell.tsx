"use client";

import { useState } from "react";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { ThemeToggle } from "@/components/theme-toggle";
import { useMe } from "@/hooks/use-me";
import { useTeam } from "@/hooks/use-teams";
import { SidebarNav } from "./sidebar-nav";
import { TeamSelector } from "./team-selector";

export function AppShell({ teamId, children }: { teamId: string; children: React.ReactNode }) {
  const { data: me } = useMe();
  const { data: team } = useTeam(teamId);
  const [drawerOpen, setDrawerOpen] = useState(false);

  return (
    <div className="flex min-h-screen">
      {/* RF-UX-001: colapsa a solo iconos en <1024px, drawer en <768px */}
      <aside className="hidden w-56 flex-col border-r lg:flex">
        <SidebarHeader teamId={teamId} memberships={me?.memberships} hackathonName={team?.hackathon?.name} />
        <SidebarNav teamId={teamId} />
      </aside>
      <aside className="hidden w-16 flex-col border-r md:flex lg:hidden">
        <SidebarNav teamId={teamId} iconOnly />
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center gap-3 border-b px-4 py-3">
          <Sheet open={drawerOpen} onOpenChange={setDrawerOpen}>
            <SheetTrigger
              render={<Button variant="ghost" size="icon" className="md:hidden" aria-label="Abrir menú" />}
            >
              <Menu className="size-5" />
            </SheetTrigger>
            <SheetContent side="left" className="w-64 p-0">
              <SheetTitle className="sr-only">Menú</SheetTitle>
              <SidebarHeader teamId={teamId} memberships={me?.memberships} hackathonName={team?.hackathon?.name} />
              <SidebarNav teamId={teamId} />
            </SheetContent>
          </Sheet>

          <div className="flex-1" />
          <ThemeToggle />
        </header>

        <main className="min-w-0 flex-1 p-4 md:p-6">{children}</main>
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
    <div className="flex flex-col gap-1 border-b p-3">
      {memberships && <TeamSelector memberships={memberships} currentTeamId={teamId} />}
      {hackathonName && <p className="text-muted-foreground truncate text-xs">{hackathonName}</p>}
    </div>
  );
}
