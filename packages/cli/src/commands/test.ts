import { randomUUID } from "node:crypto";
import { CLI_VERSION } from "../index";
import { readCredentials } from "../credentials";
import { readConfigCache } from "../config-cache";
import { getRemote } from "../git";
import { ingestBatch } from "../api-client";

// `hackboard test`: envía un evento system_test y muestra el resultado
// (08-integracion-claude-code.md#comandos).
export async function runTest(): Promise<void> {
  const creds = readCredentials();
  if (!creds) {
    console.error("No conectado. Ejecuta `hackboard init`.");
    process.exitCode = 1;
    return;
  }

  const remote = getRemote(process.cwd()) ?? readConfigCache()?.repos[0];
  if (!remote) {
    console.error("No hay ningún repo vinculado para probar. Vincula uno desde los ajustes del equipo.");
    process.exitCode = 1;
    return;
  }

  const event = {
    client_event_id: randomUUID(),
    kind: "system_test",
    occurred_at: new Date().toISOString(),
    session_ref: "cli-test",
    repo: { remote },
    data: {},
  };

  const result = await ingestBatch(creds.token, CLI_VERSION, [event]);

  if (!result.ok) {
    console.error(result.revoked ? "El token ha sido revocado. Ejecuta `hackboard init` de nuevo." : "No se ha podido contactar con el servidor.");
    process.exitCode = 1;
    return;
  }

  if (result.rejected.length > 0) {
    console.error(`Rechazado: ${result.rejected[0].reason}`);
    process.exitCode = 1;
    return;
  }

  console.log("Prueba enviada correctamente. Revisa el feed de actividad de tu equipo.");
}
