"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { navItems } from "./nav-items";

export function SidebarNav({ teamId, iconOnly = false }: { teamId: string; iconOnly?: boolean }) {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-1 p-2">
      {navItems(teamId).map((item) => {
        const active = pathname?.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              active ? "bg-secondary text-secondary-foreground" : "text-muted-foreground hover:bg-secondary/60",
              iconOnly && "justify-center px-2",
            )}
            title={iconOnly ? item.label : undefined}
          >
            <item.icon className="size-4 shrink-0" />
            {!iconOnly && <span>{item.label}</span>}
          </Link>
        );
      })}
    </nav>
  );
}
