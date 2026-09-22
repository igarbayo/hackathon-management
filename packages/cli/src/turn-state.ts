import { mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { paths } from "./paths";

// La cola agrega por turno, de UserPromptSubmit a Stop
// (08-integracion-claude-code.md#qué-recoge-cada-hook). Cada hook es un
// proceso nuevo, así que el estado del turno en curso vive en disco,
// indexado por session_id.
export interface TurnState {
  prompt_chars?: number;
  files: { path: string; tool: string }[];
  tool_uses: number;
  started_at: string;
}

function statePath(sessionId: string): string {
  return join(paths.turnsDir(), `${sessionId}.json`);
}

export function openTurn(sessionId: string, promptChars: number): void {
  mkdirSync(paths.turnsDir(), { recursive: true });
  const state: TurnState = { prompt_chars: promptChars, files: [], tool_uses: 0, started_at: new Date().toISOString() };
  writeFileSync(statePath(sessionId), JSON.stringify(state));
}

export function readTurn(sessionId: string): TurnState | null {
  try {
    return JSON.parse(readFileSync(statePath(sessionId), "utf-8")) as TurnState;
  } catch {
    return null;
  }
}

export function addToolUse(sessionId: string, file: { path: string; tool: string } | null): void {
  const state = readTurn(sessionId) ?? { files: [], tool_uses: 0, started_at: new Date().toISOString() };
  state.tool_uses += 1;
  if (file) state.files.push(file);

  mkdirSync(paths.turnsDir(), { recursive: true });
  writeFileSync(statePath(sessionId), JSON.stringify(state));
}

export function closeTurn(sessionId: string): TurnState | null {
  const state = readTurn(sessionId);
  try {
    unlinkSync(statePath(sessionId));
  } catch {
    // no-op: puede que Stop llegue sin UserPromptSubmit previo
  }
  return state;
}
