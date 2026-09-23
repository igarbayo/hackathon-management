"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { LoadingState } from "@/components/states";
import { useMe } from "@/hooks/use-me";

export default function RootPage() {
  const router = useRouter();
  const { data: me, isError } = useMe();

  useEffect(() => {
    if (isError) {
      router.replace("/login");
      return;
    }
    if (me) {
      const lastTeamIsValid = me.last_team_id && me.memberships.some((m) => m.team_id === me.last_team_id);
      router.replace(lastTeamIsValid ? `/t/${me.last_team_id}/home` : "/onboarding");
    }
  }, [me, isError, router]);

  return (
    <div className="p-6">
      <LoadingState />
    </div>
  );
}
