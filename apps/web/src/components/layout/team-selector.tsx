"use client";

import { useRouter } from "next/navigation";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Membership } from "@/types/api";

// RF-UX-002: selector de equipo solo si el usuario tiene más de uno.
export function TeamSelector({ memberships, currentTeamId }: { memberships: Membership[]; currentTeamId: string }) {
  const router = useRouter();

  if (memberships.length <= 1) {
    return <p className="truncate text-sm font-semibold">{memberships[0]?.team_name}</p>;
  }

  return (
    <Select value={currentTeamId} onValueChange={(teamId) => teamId && router.push(`/t/${teamId}/home`)}>
      <SelectTrigger className="w-full" aria-label="Seleccionar equipo">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {memberships.map((membership) => (
          <SelectItem key={membership.team_id} value={membership.team_id}>
            {membership.team_name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
