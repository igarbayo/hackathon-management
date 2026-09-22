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
      router.replace(me.last_team_id ? `/t/${me.last_team_id}/home` : "/onboarding");
    }
  }, [me, isError, router]);

  return (
    <div className="p-6">
      <LoadingState />
    </div>
  );
}
