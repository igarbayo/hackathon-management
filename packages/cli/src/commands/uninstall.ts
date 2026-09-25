import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { clearCredentials, readCredentials } from "../credentials";
import { clearQueue } from "../queue";
import { revokeMyLink } from "../api-client";
import { readSettingsFile, removeHooksFromSettings, settingsPathFor, writeSettingsFile } from "../settings-merge";

// RF-CC-023: leaves the settings files exactly as they were, except for
// third-party changes made afterwards (only our own entries are removed).
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
      console.error("Could not revoke the token on the server; deleting it locally anyway.");
    }

    try {
      execFileSync("claude", ["mcp", "remove", "hackboard"], { stdio: "ignore" });
    } catch {
      // no MCP server was registered, or `claude` is not in the PATH
    }
  }

  clearCredentials();
  clearQueue();
  console.log(`Hackboard uninstalled.${purge ? " Your events have also been deleted from the server." : ""}`);
}
