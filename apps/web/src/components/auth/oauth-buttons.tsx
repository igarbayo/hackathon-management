import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { GitHubLogo, GoogleLogo } from "./provider-logos";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

// RF-AUTH-010: "Continue with Google" and "Continue with GitHub" above the
// email form. It is a full page navigation (not fetch): the server has to see
// the request to set the signed state.
// The <a> is styled directly instead of wrapping it in Button: Base UI advises
// against rendering links through the button (they have their own semantics).
// Each button shows the provider logo before the text, as usual.
export function OAuthButtons() {
  return (
    <div className="flex flex-col gap-2">
      <a href={`${API_URL}/api/v1/auth/google`} className={cn(buttonVariants({ variant: "outline" }))}>
        <GoogleLogo />
        Continue with Google
      </a>
      <a href={`${API_URL}/api/v1/auth/github`} className={cn(buttonVariants({ variant: "outline" }))}>
        <GitHubLogo />
        Continue with GitHub
      </a>
    </div>
  );
}
