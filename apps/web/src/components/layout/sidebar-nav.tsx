"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { navItems } from "./nav-items";

// Calcado del item de menú del Sidebar de F0 (Navigation/Sidebar/Menu):
// rounded, 16px de icono, activo en bg-f1-background-secondary.
export function SidebarNav({ teamId, iconOnly = false }: { teamId: string; iconOnly?: boolean }) {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-0.5 p-2">
      {navItems(teamId).map((item) => {
        const active = pathname?.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "focus-ring flex items-center gap-1.5 rounded py-1.5 pl-1.5 pr-2 text-base font-medium no-underline transition-colors",
              active
                ? "bg-f1-background-secondary text-f1-foreground"
                : "text-f1-foreground hover:bg-f1-background-secondary-hover",
              iconOnly && "justify-center px-0",
            )}
            title={iconOnly ? item.label : undefined}
          >
            <item.icon
              className={cn("size-4 shrink-0", active ? "text-f1-icon-bold" : "text-f1-icon")}
            />
            {!iconOnly && <span>{item.label}</span>}
          </Link>
        );
      })}
    </nav>
  );
}
