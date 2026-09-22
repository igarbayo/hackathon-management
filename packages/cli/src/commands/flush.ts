import { CLI_VERSION } from "../index";
import { readCredentials, markDisconnected } from "../credentials";
import { readConfigCache, writeConfigCache, isStale } from "../config-cache";
import { readQueueEvents, removeFromQueue } from "../queue";
import { fetchConfig, ingestBatch } from "../api-client";
import { recordFailure, recordSuccess, shouldSkip } from "../backoff";
import { acquireLock, releaseLock } from "../lock";
import { log } from "../log";

const BATCH_SIZE = 200;

// Uso interno (RNF-CC-001): nunca lanza, nunca escribe en stdout. Lo invocan
// los hooks Stop/SessionEnd como proceso detached, o el usuario a mano.
export async function runFlush(): Promise<void> {
  const creds = readCredentials();
  if (!creds || creds.connected === false) return;
  if (shouldSkip()) return;
  if (!acquireLock()) return;

  try {
    await maybeRefreshConfig(creds.token);
    await sendQueue(creds.token);
  } finally {
    releaseLock();
  }
}

async function maybeRefreshConfig(token: string): Promise<void> {
  try {
    if (!isStale(readConfigCache())) return;
    const fresh = await fetchConfig(token);
    writeConfigCache({ ...fresh, fetched_at: new Date().toISOString() });
  } catch (error) {
    log(`no se ha podido refrescar /cli/config: ${(error as Error).message}`);
  }
}

async function sendQueue(token: string): Promise<void> {
  const events = readQueueEvents();
  if (events.length === 0) {
    recordSuccess();
    return;
  }

  const batch = events.slice(0, BATCH_SIZE);
  const result = await ingestBatch(token, CLI_VERSION, batch);

  if (!result.ok) {
    if (result.revoked) {
      markDisconnected();
      log("token revocado (401): se marca como desconectado y se deja de encolar");
      return;
    }
    recordFailure();
    log("fallo al enviar el lote a /api/v1/ingest/claude_code, se reintentará con backoff");
    return;
  }

  recordSuccess();
  removeFromQueue(new Set(batch.map((event) => event.client_event_id)));
  log(`lote enviado: ${result.accepted} aceptados, ${result.duplicates} duplicados, ${result.rejected.length} rechazados`);
}
