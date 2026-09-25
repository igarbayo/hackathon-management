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
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useLogOut } from "@/hooks/use-me";
import type { Me } from "@/types/api";

const noopSubscribe = () => () => {};

// Same as ThemeToggle: avoids the hydration mismatch with the theme.
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
 * F0 sidebar footer: the user's avatar (Google/GitHub photo or initials) and name, with a menu that groups
 * the theme (it used to be a separate button in the header) and log out.
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
          aria-label="User menu"
        >
          {/* RF-AUTH-011: Google/GitHub photo; if there is none or it fails to load, initials. */}
          <Avatar className="size-7">
            {me.avatar_url && (
              <AvatarImage src={me.avatar_url} alt="" referrerPolicy="no-referrer" />
            )}
            <AvatarFallback className="bg-f1-background-selected-bold text-sm font-medium text-f1-foreground-inverse">
              {initials(me.name || me.email)}
            </AvatarFallback>
          </Avatar>
          {!iconOnly && (
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-f1-foreground">{me.name}</p>
              <p className="truncate text-sm text-f1-foreground-secondary">{me.email}</p>
            </div>
          )}
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" side="top" className="w-56">
          <DropdownMenuRadioGroup value={mounted ? theme : undefined} onValueChange={setTheme}>
            <DropdownMenuRadioItem value="light" closeOnClick>
              <SunIcon className="size-4" /> Light
            </DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="dark" closeOnClick>
              <MoonIcon className="size-4" /> Dark
            </DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="system" closeOnClick>
              <MonitorIcon className="size-4" /> System
            </DropdownMenuRadioItem>
          </DropdownMenuRadioGroup>
          <DropdownMenuSeparator />
          <DropdownMenuItem variant="destructive" onClick={handleLogOut}>
            <LogOutIcon className="size-4" /> Log out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
