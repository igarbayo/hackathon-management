import { describe, expect, it } from "vitest";
import { actorAvatarUrl, actorInitials } from "@/lib/actor-avatar";
import type { Member } from "@/types/api";

const member: Member = {
  id: "m1",
  user_id: "u1",
  role: "member",
  display_name: "Ada Lovelace",
  avatar_url: "https://lh3.googleusercontent.com/ada",
  git_identities: [],
  claude_code: null,
};

describe("actorAvatarUrl (RF-ACT-010)", () => {
  it("uses the member's profile photo", () => {
    expect(actorAvatarUrl({ membership_id: "m1", github_login: "ada" }, [member])).toBe(member.avatar_url);
  });

  it("falls back to the GitHub avatar of the login", () => {
    expect(actorAvatarUrl({ membership_id: null, github_login: "octo-cat" }, [member])).toBe(
      "https://github.com/octo-cat.png?size=48",
    );
    expect(actorAvatarUrl({ membership_id: "m1", github_login: "ada" }, [{ ...member, avatar_url: null }])).toBe(
      "https://github.com/ada.png?size=48",
    );
  });

  it("returns null without photo or login", () => {
    expect(actorAvatarUrl({ membership_id: null, github_login: null }, [])).toBeNull();
  });
});

describe("actorInitials", () => {
  it("takes up to two initials", () => {
    expect(actorInitials("Ada  King Lovelace")).toBe("AK");
    expect(actorInitials("")).toBe("");
  });
});
