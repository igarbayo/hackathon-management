import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";
import { log } from "./log";

// Cap of 5000 events in the local queue (08-integracion-claude-code.md#envío-flush).
// Each `hackboard hook` is a new process that calls enqueue() only once, so the real
// cost per hook is one read of the queue (to check the cap) plus an append: for a
// file of a few thousand lines, on the order of milliseconds, well inside the
// RNF-CC-001 budget. There is no need to optimize further for that usage pattern.
export const MAX_QUEUE_EVENTS = 5000;

export interface QueuedEvent {
  client_event_id: string;
  [key: string]: unknown;
}

export function enqueue(event: QueuedEvent): void {
  ensureConfigDir();
  appendFileSync(paths.queue(), `${JSON.stringify(event)}\n`);
  trimIfNeeded();
}

function readLines(): string[] {
  try {
    return readFileSync(paths.queue(), "utf-8")
      .split("\n")
      .filter((line) => line.trim().length > 0);
  } catch {
    return [];
  }
}

export function readQueueEvents(): QueuedEvent[] {
  const events: QueuedEvent[] = [];
  for (const line of readLines()) {
    try {
      events.push(JSON.parse(line) as QueuedEvent);
    } catch {
      // corrupt line: dropped silently, it cannot break the flush
    }
  }
  return events;
}

export function removeFromQueue(clientEventIds: ReadonlySet<string>): void {
  const remaining = readQueueEvents().filter((event) => !clientEventIds.has(event.client_event_id));
  writeQueue(remaining);
}

export function clearQueue(): void {
  writeQueue([]);
}

function writeQueue(events: QueuedEvent[]): void {
  ensureConfigDir();
  const body = events.map((event) => JSON.stringify(event)).join("\n");
  writeFileSync(paths.queue(), events.length ? `${body}\n` : "");
}

function trimIfNeeded(): void {
  const lines = readLines();
  if (lines.length <= MAX_QUEUE_EVENTS) return;

  const dropped = lines.length - MAX_QUEUE_EVENTS;
  const kept = lines.slice(dropped);
  writeFileSync(paths.queue(), `${kept.join("\n")}\n`);
  log(`queue full: dropped ${dropped} old events`);
}
