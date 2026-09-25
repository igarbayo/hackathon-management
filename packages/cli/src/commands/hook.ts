import { readFileSync } from "node:fs";
import { createHash, randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { readCredentials } from "../credentials";
import { readConfigCache } from "../config-cache";
import { getBranch, getHeadSha, getRemote, toRepoRelativePath } from "../git";
import { DEFAULT_EXCLUDE_GLOBS, isExcluded } from "../exclusions";
import { enqueue } from "../queue";
import { addToolUse, closeTurn, openTurn } from "../turn-state";

function readStdinJson(): Record<string, unknown> {
  try {
    const raw = readFileSync(0, "utf-8");
    return raw ? (JSON.parse(raw) as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function sessionRef(sessionId: string, memberId: string): string {
  return createHash("sha256").update(`${sessionId}${memberId}`).digest("hex").slice(0, 16);
}

function triggerFlush(): void {
  try {
    const child = spawn(process.execPath, [process.argv[1], "flush"], { detached: true, stdio: "ignore" });
    child.unref();
  } catch {
    // best-effort: if it cannot be started, the next hook will retry it
  }
}

function baseEvent(kind: string, ref: string, remote: string, branch: string | null, headSha: string | null, data: Record<string, unknown>) {
  return {
    client_event_id: randomUUID(),
    kind,
    occurred_at: new Date().toISOString(),
    session_ref: ref,
    repo: { remote, branch: branch ?? undefined, head_sha: headSha ?? undefined },
    data,
  };
}

// RNF-CC-001: never throws, never writes to stdout. bin/hackboard.ts wraps this
// function in try/catch and always exits with 0.
export function runHook(event: string | undefined): void {
  const creds = readCredentials();
  if (!creds || creds.connected === false || creds.paused || creds.privacy_level === "off") return;
  if (!event) return;

  const input = readStdinJson();
  const cwd = typeof input.cwd === "string" ? input.cwd : process.cwd();
  const sessionId = typeof input.session_id === "string" ? input.session_id : "unknown";

  const remote = getRemote(cwd);
  const cache = readConfigCache();
  // Repository filter: if it does not match a linked repo, the event is dropped locally
  // (08-integracion-claude-code.md#comportamiento-de-hackboard-hook).
  if (!remote || !cache || !cache.repos.includes(remote)) return;

  const branch = getBranch(cwd);
  const headSha = getHeadSha(cwd);
  const ref = sessionRef(sessionId, creds.member_id);
  const excludeGlobs = cache.exclude_globs.length > 0 ? cache.exclude_globs : DEFAULT_EXCLUDE_GLOBS;

  switch (event) {
    case "session-start":
      enqueue(baseEvent("cc_session_start", ref, remote, branch, headSha, {}));
      break;

    case "prompt": {
      const prompt = typeof input.prompt === "string" ? input.prompt : "";
      openTurn(sessionId, prompt.length);
      break;
    }

    case "tool": {
      const toolInput = input.tool_input as Record<string, unknown> | undefined;
      const filePath = typeof toolInput?.file_path === "string" ? toolInput.file_path : undefined;
      const toolName = typeof input.tool_name === "string" ? input.tool_name : "unknown";

      let file: { path: string; tool: string } | null = null;
      if (filePath) {
        const relPath = toRepoRelativePath(cwd, filePath);
        if (relPath && !isExcluded(relPath, excludeGlobs)) file = { path: relPath, tool: toolName };
      }
      addToolUse(sessionId, file);
      break;
    }

    case "stop": {
      const turn = closeTurn(sessionId);
      enqueue(
        baseEvent("cc_turn", ref, remote, branch, headSha, {
          files: turn?.files ?? [],
          tool_uses: turn?.tool_uses ?? 0,
          prompt_chars: turn?.prompt_chars,
          duration_ms: turn ? Date.now() - Date.parse(turn.started_at) : undefined,
        })
      );
      triggerFlush();
      break;
    }

    case "session-end": {
      const reason = typeof input.reason === "string" ? input.reason : undefined;
      enqueue(baseEvent("cc_session_end", ref, remote, branch, headSha, { reason }));
      triggerFlush();
      break;
    }

    default:
      break;
  }
}
