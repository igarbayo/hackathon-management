import Link from "next/link";
import { GitBranchIcon } from "lucide-react";
import { cn } from "@/lib/utils";

// RF-GH-026: rama de un commit o de una feature, como F0TagRaw neutro. Con
// `href`, lleva a Actividad filtrada por esa rama.
export function BranchTag({ name, href, title, className }: { name: string; href?: string; title?: string; className?: string }) {
  const classes = cn(
    "inline-flex max-w-48 items-center gap-1 rounded-full bg-f1-background-secondary px-2 py-0.5 text-sm text-f1-foreground-secondary",
    href && "hover:bg-f1-background-secondary-hover focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-f1-special-ring focus-visible:ring-offset-1",
    className,
  );
  const content = (
    <>
      <GitBranchIcon className="size-3 shrink-0 text-f1-icon" aria-hidden />
      <span className="truncate font-mono">{name}</span>
    </>
  );

  if (href) {
    return (
      <Link href={href} className={classes} title={title ?? `Ver actividad de ${name}`}>
        {content}
      </Link>
    );
  }
  return (
    <span className={classes} title={title}>
      {content}
    </span>
  );
}
