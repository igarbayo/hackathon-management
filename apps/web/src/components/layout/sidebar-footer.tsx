"use client";

import { useSyncExternalStore } from "react";
import { useRouter } from "next/navigation";
import { useTheme } from "next-themes";
import { LogOutIcon, MonitorIcon, MoonIcon, SunIcon } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useLogOut } from "@/hooks/use-me";
import type { Me } from "@/types/api";

const noopSubscribe = () => () => {};

// Igual que ThemeToggle: evita el mismatch de hidratación con el tema.
function useMounted() {
  return useSyncExternalStore(
    noopSubscribe,
    () => true,
    () => false,
  );
}

function initials(name: string) {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

/**
 * Pie del sidebar F0: avatar y nombre del usuario, con un menú que agrupa
 * el tema (antes un botón suelto en la cabecera) y cerrar sesión.
 */
export function SidebarFooter({ me, iconOnly = false }: { me: Me | undefined; iconOnly?: boolean }) {
  const { theme, setTheme } = useTheme();
  const mounted = useMounted();
  const router = useRouter();
  const logOut = useLogOut();

  if (!me) return null;

  const handleLogOut = () => {
    logOut.mutate(undefined, { onSuccess: () => router.push("/login") });
  };

  return (
    <div className="border-t border-f1-border-secondary p-2">
      <DropdownMenu>
        <DropdownMenuTrigger
          className="flex w-full items-center gap-2 rounded p-1.5 text-left hover:bg-f1-background-secondary-hover focus-ring"
          aria-label="Menú de usuario"
        >
          <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-f1-background-selected-bold text-sm font-medium text-f1-foreground-inverse">
            {initials(me.name || me.email)}
          </div>
          {!iconOnly && (
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-f1-foreground">{me.name}</p>
              <p className="truncate text-sm text-f1-foreground-secondary">{me.email}</p>
            </div>
          )}
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" side="top" className="w-56">
          <DropdownMenuRadioGroup value={mounted ? theme : undefined} onValueChange={setTheme}>
            <DropdownMenuRadioItem value="light">
              <SunIcon className="size-4" /> Claro
            </DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="dark">
              <MoonIcon className="size-4" /> Oscuro
            </DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="system">
              <MonitorIcon className="size-4" /> Sistema
            </DropdownMenuRadioItem>
          </DropdownMenuRadioGroup>
          <DropdownMenuSeparator />
          <DropdownMenuItem variant="destructive" onClick={handleLogOut}>
            <LogOutIcon className="size-4" /> Cerrar sesión
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
