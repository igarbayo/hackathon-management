import { readCredentials } from "../credentials";
import { readConfigCache } from "../config-cache";
import { readQueueEvents } from "../queue";

export function runStatus(): void {
  const creds = readCredentials();
  if (!creds) {
    console.log("Not connected. Run `hackboard init` to get started.");
    return;
  }

  const state = creds.connected === false ? "disconnected (token revoked, run hackboard init again)" : creds.paused ? "paused" : "connected";
  const cache = readConfigCache();

  console.log(`Team: ${creds.team_name}`);
  console.log(`Status: ${state}`);
  console.log(`Privacy level: ${creds.privacy_level}`);
  console.log(`Queued events: ${readQueueEvents().length}`);
  console.log(`Linked repos: ${cache?.repos.join(", ") || "(not downloaded yet, run hackboard flush)"}`);
}
