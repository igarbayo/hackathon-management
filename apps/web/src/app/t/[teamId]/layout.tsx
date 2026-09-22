"use client";

import { use, useEffect } from "react";
import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { LoadingState } from "@/components/states";
import { useMe } from "@/hooks/use-me";

export default function TeamLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ teamId: string }>;
}) {
  const { teamId } = use(params);
  const router = useRouter();
  const { data: me, isLoading, isError } = useMe();

  useEffect(() => {
    if (isError) router.replace("/login");
  }, [isError, router]);

  if (isLoading || !me) {
    return (
      <div className="p-6">
        <LoadingState />
      </div>
    );
  }

  const isMember = me.memberships.some((m) => m.team_id === teamId);
  if (!isMember) {
    return (
      <div className="p-6">
        <p>No eres miembro de este equipo.</p>
      </div>
    );
  }

  return <AppShell teamId={teamId}>{children}</AppShell>;
}
