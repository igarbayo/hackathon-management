import { readCredentials, writeCredentials } from "../credentials";
import { updateMyLink } from "../api-client";

const VALID_LEVELS = ["metadata", "summaries", "off"];

export async function runPrivacy(level: string | undefined): Promise<void> {
  if (!level || !VALID_LEVELS.includes(level)) {
    console.error(`Usage: hackboard privacy <${VALID_LEVELS.join("|")}>`);
    process.exitCode = 1;
    return;
  }

  const creds = readCredentials();
  if (!creds) {
    console.error("Not connected. Run `hackboard init`.");
    process.exitCode = 1;
    return;
  }

  await updateMyLink(creds.token, { privacy_level: level });
  writeCredentials({ ...creds, privacy_level: level });
  console.log(`Privacy level: ${level}`);
}
