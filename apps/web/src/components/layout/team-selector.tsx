"use client";

import { useRouter } from "next/navigation";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Membership } from "@/types/api";

// RF-UX-002: selector de equipo solo si el usuario tiene más de uno.
export function TeamSelector({
  memberships,
  currentTeamId,
  onNavigate,
}: {
  memberships: Membership[];
  currentTeamId: string;
  onNavigate?: () => void;
}) {
  const router = useRouter();

  if (memberships.length <= 1) {
    return <p className="truncate text-base font-semibold text-f1-foreground">{memberships[0]?.team_name}</p>;
  }

  // Base UI pinta el `value` tal cual en SelectValue salvo que Root reciba
  // `items`; sin esto el trigger mostraba el id del equipo en vez del nombre.
  const items = memberships.map((membership) => ({
    value: membership.team_id,
    label: membership.team_name ?? membership.team_id,
  }));

  const handleChange = (teamId: string | null) => {
    if (!teamId) return;
    onNavigate?.();
    router.push(`/t/${teamId}/home`);
  };

  return (
    <Select items={items} value={currentTeamId} onValueChange={handleChange}>
      <SelectTrigger className="w-full border-none bg-transparent px-0 font-semibold hover:bg-transparent" aria-label="Seleccionar equipo">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {items.map((item) => (
          <SelectItem key={item.value} value={item.value}>
            {item.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
