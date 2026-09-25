import Image from "next/image";
import { cn } from "@/lib/utils";

// Brand logos from public/. The horizontal one has a negative version (without
// the dark purple background of the original, so it sits on any panel) that
// is shown only in dark mode.
export function LogoHorizontal({ className, priority }: { className?: string; priority?: boolean }) {
  return (
    <span className={cn("inline-flex", className)}>
      <Image
        src="/logo-horizontal.svg"
        alt="Hackboard"
        width={789}
        height={200}
        priority={priority}
        unoptimized
        className="h-full w-auto dark:hidden"
      />
      <Image
        src="/logo-horizontal-negativo-transparente.svg"
        alt="Hackboard"
        width={789}
        height={200}
        priority={priority}
        unoptimized
        className="hidden h-full w-auto dark:block"
      />
    </span>
  );
}

export function LogoIcon({ className }: { className?: string }) {
  return (
    <Image src="/logo-icono.svg" alt="Hackboard" width={400} height={400} unoptimized className={className} />
  );
}
