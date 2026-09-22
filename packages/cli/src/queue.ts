import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";
import { log } from "./log";

// Tope de 5000 eventos en la cola local (08-integracion-claude-code.md#envío-flush).
// Cada `hackboard hook` es un proceso nuevo que llama a enqueue() una sola
// vez, así que el coste real por hook es una lectura de la cola (para
// comprobar el tope) más un append: para un fichero de unos pocos miles de
// líneas, del orden de milisegundos, bien dentro del presupuesto de
// RNF-CC-001. No hace falta optimizar más para ese patrón de uso.
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
      // línea corrupta: se descarta en silencio, no puede romper el flush
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
  log(`cola llena: se han descartado ${dropped} eventos antiguos`);
}
