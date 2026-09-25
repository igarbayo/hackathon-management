import { randomUUID } from "node:crypto";
import { CLI_VERSION } from "../index";
import { readCredentials } from "../credentials";
import { readConfigCache } from "../config-cache";
import { getRemote } from "../git";
import { ingestBatch } from "../api-client";

// `hackboard test`: sends a system_test event and shows the result
// (08-integracion-claude-code.md#comandos).
export async function runTest(): Promise<void> {
  const creds = readCredentials();
  if (!creds) {
    console.error("Not connected. Run `hackboard init`.");
    process.exitCode = 1;
    return;
  }

  const remote = getRemote(process.cwd()) ?? readConfigCache()?.repos[0];
  if (!remote) {
    console.error("There is no linked repo to test with. Link one from the team settings.");
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
    console.error(result.revoked ? "The token has been revoked. Run `hackboard init` again." : "Could not reach the server.");
    process.exitCode = 1;
    return;
  }

  if (result.rejected.length > 0) {
    console.error(`Rechazado: ${result.rejected[0].reason}`);
    process.exitCode = 1;
    return;
  }

  console.log("Test sent. Check your team's activity feed.");
}
