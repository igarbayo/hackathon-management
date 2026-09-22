import { execFileSync, spawn } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createDevice, apiBaseUrl, pollDeviceToken } from "../api-client";
import { writeCredentials } from "../credentials";
import { getRemote } from "../git";
import { mergeHooksIntoSettings, readSettingsFile, settingsPathFor, writeSettingsFile } from "../settings-merge";
import { runTest } from "./test";

interface InitOptions {
  team?: string;
  scope: "local" | "user";
  mcp?: boolean;
}

function parseArgs(argv: string[]): InitOptions {
  const options: InitOptions = { scope: "local" };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--team") options.team = argv[++i];
    else if (argv[i] === "--scope") options.scope = argv[++i] === "user" ? "user" : "local";
    else if (argv[i] === "--mcp") options.mcp = true;
    else if (argv[i] === "--no-mcp") options.mcp = false;
  }
  return options;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function tryOpenBrowser(url: string): Promise<void> {
  try {
    if (process.platform === "darwin") spawn("open", [url], { stdio: "ignore" }).unref();
    else if (process.platform === "win32") spawn("cmd", ["/c", "start", "", url], { stdio: "ignore" }).unref();
    else spawn("xdg-open", [url], { stdio: "ignore" }).unref();
  } catch {
    // no-op: la URL ya se ha mostrado en la terminal
  }
}

async function pollForToken(deviceCode: string, intervalSeconds: number, expiresInSeconds: number) {
  const deadline = Date.now() + expiresInSeconds * 1000;
  let delayMs = intervalSeconds * 1000;

  while (Date.now() < deadline) {
    await sleep(delayMs);
    const result = await pollDeviceToken(deviceCode);
    if (result.ok) return result;
    if (result.error === "slow_down") {
      delayMs += 5000;
      continue;
    }
    if (result.error === "authorization_pending") continue;
    return null; // access_denied, expired_token o invalid_grant
  }
  return null;
}

function ensureGitignored(cwd: string): void {
  const gitignorePath = join(cwd, ".gitignore");
  const entry = ".claude/settings.local.json";
  const content = existsSync(gitignorePath) ? readFileSync(gitignorePath, "utf-8") : "";
  const alreadyIgnored = content.split("\n").some((line) => {
    const trimmed = line.trim();
    return trimmed === entry || trimmed === ".claude/" || trimmed === ".claude";
  });
  if (alreadyIgnored) return;

  writeFileSync(gitignorePath, `${content.replace(/\n?$/, "\n")}${entry}\n`);
}

async function maybeRegisterMcp(scope: "local" | "user", token: string): Promise<void> {
  const mcpUrl = `${apiBaseUrl()}/api/v1/mcp`;
  const manualCommand = `claude mcp add --transport http --scope ${scope} hackboard ${mcpUrl} --header "Authorization: Bearer ${token}"`;

  let existing: string;
  try {
    existing = execFileSync("claude", ["mcp", "list"], { encoding: "utf-8" });
  } catch {
    console.log(`\n\`claude\` no está en el PATH. Para registrar el MCP a mano:\n  ${manualCommand}`);
    return;
  }

  if (existing.includes("hackboard")) {
    console.log("\nYa existe un servidor MCP \"hackboard\" registrado: no se toca.");
    return;
  }

  try {
    execFileSync("claude", ["mcp", "add", "--transport", "http", "--scope", scope, "hackboard", mcpUrl, "--header", `Authorization: Bearer ${token}`], {
      stdio: "ignore",
    });
    console.log("\nMCP de Hackboard registrado en Claude Code.");
  } catch (error) {
    console.log(`\nNo se ha podido registrar el MCP automáticamente (${(error as Error).message}). Cópialo a mano:\n  ${manualCommand}`);
  }
}

export async function runInit(argv: string[]): Promise<void> {
  const options = parseArgs(argv);
  const cwd = process.cwd();

  if (!getRemote(cwd)) {
    console.log("No se ha detectado un repo git con remote de GitHub en este directorio. Se continúa con scope \"user\".");
    options.scope = "user";
  }

  console.log("Conectando con Hackboard…");
  const device = await createDevice(options.team);
  console.log(`\nEntra en: ${device.verification_url}`);
  console.log(`Código: ${device.user_code}\n`);
  console.log("Esperando a que apruebes el acceso desde el navegador…");
  await tryOpenBrowser(device.verification_url);

  const result = await pollForToken(device.device_code, device.interval, device.expires_in);
  if (!result) {
    console.error("El código ha caducado o se ha rechazado. Vuelve a intentarlo con `hackboard init`.");
    process.exitCode = 1;
    return;
  }

  writeCredentials({
    token: result.token,
    api_url: apiBaseUrl(),
    team_id: result.team.id,
    team_name: result.team.name,
    member_id: result.member.id,
    connected: true,
    paused: false,
    privacy_level: "metadata",
  });
  console.log(`Conectado al equipo "${result.team.name}".`);

  const settingsPath = settingsPathFor(options.scope, cwd);
  writeSettingsFile(settingsPath, mergeHooksIntoSettings(readSettingsFile(settingsPath)));
  console.log(`Hooks instalados en ${settingsPath}`);

  if (options.scope === "local") ensureGitignored(cwd);

  if (options.mcp !== false) await maybeRegisterMcp(options.scope, result.token);

  await runTest();
  console.log(`\nListo. Tus eventos aparecerán en ${(process.env.APP_URL ?? "http://localhost:3000")}/activity`);
}
