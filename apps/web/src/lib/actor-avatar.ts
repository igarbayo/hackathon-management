import type { ActivityEvent } from "@/types/activity";
import type { Member } from "@/types/api";

// RF-ACT-010: photo next to the actor in the feed. A member's is their Google
// or GitHub photo; a GitHub author who is not a member (or a member without a
// photo) gets their GitHub avatar from the login. Without either, initials.
export function actorAvatarUrl(actor: ActivityEvent["actor"], members: Member[]): string | null {
  const member = actor.membership_id ? members.find((m) => m.id === actor.membership_id) : undefined;
  if (member?.avatar_url) return member.avatar_url;
  if (actor.github_login) return `https://github.com/${encodeURIComponent(actor.github_login)}.png?size=48`;
  return null;
}

export function actorInitials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0]?.toUpperCase())
    .join("");
}
