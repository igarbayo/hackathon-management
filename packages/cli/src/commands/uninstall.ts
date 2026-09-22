import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { clearCredentials, readCredentials } from "../credentials";
import { clearQueue } from "../queue";
import { revokeMyLink } from "../api-client";
import { readSettingsFile, removeHooksFromSettings, settingsPathFor, writeSettingsFile } from "../settings-merge";

// RF-CC-023: deja los ficheros de settings exactamente como estaban, salvo
// cambios de terceros hechos después (solo se quitan las entradas propias).
export async function runUninstall(argv: string[]): Promise<void> {
  const purge = argv.includes("--purge");
  const creds = readCredentials();
  const cwd = process.cwd();

  for (const scope of ["local", "user"] as const) {
    const path = settingsPathFor(scope, cwd);
    if (!existsSync(path)) continue;
    writeSettingsFile(path, removeHooksFromSettings(readSettingsFile(path)));
  }

  if (creds) {
    try {
      await revokeMyLink(creds.token, purge);
    } catch {
      console.error("No se ha podido revocar el token en el servidor; se borra igualmente en local.");
    }

    try {
      execFileSync("claude", ["mcp", "remove", "hackboard"], { stdio: "ignore" });
    } catch {
      // no había MCP registrado, o `claude` no está en el PATH
    }
  }

  clearCredentials();
  clearQueue();
  console.log(`Hackboard desinstalado.${purge ? " Tus eventos también se han borrado del servidor." : ""}`);
}
