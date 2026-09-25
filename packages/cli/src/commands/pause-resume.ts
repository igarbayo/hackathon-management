import { readCredentials, writeCredentials } from "../credentials";
import { updateMyLink } from "../api-client";

export async function runPauseResume(paused: boolean): Promise<void> {
  const creds = readCredentials();
  if (!creds) {
    console.error("Not connected. Run `hackboard init`.");
    process.exitCode = 1;
    return;
  }

  await updateMyLink(creds.token, { paused });
  writeCredentials({ ...creds, paused });
  console.log(paused ? "Paused." : "Resumed.");
}
