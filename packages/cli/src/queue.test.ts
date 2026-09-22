import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

let dir: string;

vi.mock("./paths", () => ({
  ensureConfigDir: () => dir,
  paths: {
    queue: () => join(dir, "queue.jsonl"),
    log: () => join(dir, "hook.log"),
  },
}));

describe("queue", () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "hackboard-queue-"));
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
    vi.resetModules();
  });

  it("encola y relee eventos en orden", async () => {
    const { enqueue, readQueueEvents } = await import("./queue");

    enqueue({ client_event_id: "a" });
    enqueue({ client_event_id: "b" });

    expect(readQueueEvents().map((e) => e.client_event_id)).toEqual(["a", "b"]);
  });

  it("quita solo los eventos indicados", async () => {
    const { enqueue, readQueueEvents, removeFromQueue } = await import("./queue");

    enqueue({ client_event_id: "a" });
    enqueue({ client_event_id: "b" });
    removeFromQueue(new Set(["a"]));

    expect(readQueueEvents().map((e) => e.client_event_id)).toEqual(["b"]);
  });

  it("vacía la cola", async () => {
    const { enqueue, readQueueEvents, clearQueue } = await import("./queue");

    enqueue({ client_event_id: "a" });
    clearQueue();

    expect(readQueueEvents()).toEqual([]);
  });

  it("descarta los eventos más antiguos al superar el tope", async () => {
    const { writeFileSync } = await import("node:fs");
    const { join } = await import("node:path");
    const { enqueue, readQueueEvents, MAX_QUEUE_EVENTS } = await import("./queue");

    // Precarga la cola justo al límite sin pasar por enqueue() (que solo se
    // llama una vez por proceso en uso real): así se prueba el límite sin
    // depender de miles de llamadas síncronas en un solo test.
    const seeded = Array.from({ length: MAX_QUEUE_EVENTS }, (_, i) => JSON.stringify({ client_event_id: `e${i}` })).join("\n");
    writeFileSync(join(dir, "queue.jsonl"), `${seeded}\n`);

    enqueue({ client_event_id: `e${MAX_QUEUE_EVENTS}` });
    enqueue({ client_event_id: `e${MAX_QUEUE_EVENTS + 1}` });

    const events = readQueueEvents();
    expect(events).toHaveLength(MAX_QUEUE_EVENTS);
    expect(events[0].client_event_id).toBe("e2");
    expect(events[events.length - 1].client_event_id).toBe(`e${MAX_QUEUE_EVENTS + 1}`);
  });
});
