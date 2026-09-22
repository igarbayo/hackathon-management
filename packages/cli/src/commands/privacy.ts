import { readCredentials, writeCredentials } from "../credentials";
import { updateMyLink } from "../api-client";

const VALID_LEVELS = ["metadata", "summaries", "off"];

export async function runPrivacy(level: string | undefined): Promise<void> {
  if (!level || !VALID_LEVELS.includes(level)) {
    console.error(`Uso: hackboard privacy <${VALID_LEVELS.join("|")}>`);
    process.exitCode = 1;
    return;
  }

  const creds = readCredentials();
  if (!creds) {
    console.error("No conectado. Ejecuta `hackboard init`.");
    process.exitCode = 1;
    return;
  }

  await updateMyLink(creds.token, { privacy_level: level });
  writeCredentials({ ...creds, privacy_level: level });
  console.log(`Nivel de privacidad: ${level}`);
}
