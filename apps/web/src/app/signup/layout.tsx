import type { Metadata } from "next";
import { publicPageMetadata } from "@/lib/site";

export const metadata: Metadata = publicPageMetadata({
  title: "Sign up",
  description:
    "Create your free Hackboard account and set up your hackathon team's board in under 2 minutes.",
  path: "/signup",
});

export default function SignupLayout({ children }: { children: React.ReactNode }) {
  return children;
}
