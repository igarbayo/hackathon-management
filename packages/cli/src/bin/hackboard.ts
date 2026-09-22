#!/usr/bin/env node
import { CLI_NAME, CLI_VERSION } from "../index";
import { runInit } from "../commands/init";
import { runStatus } from "../commands/status";
import { runPauseResume } from "../commands/pause-resume";
import { runPrivacy } from "../commands/privacy";
import { runTest } from "../commands/test";
import { runUninstall } from "../commands/uninstall";
import { runHook } from "../commands/hook";
import { runFlush } from "../commands/flush";
import { log } from "../log";

function printHelp(): void {
  process.stdout.write(`${CLI_NAME} ${CLI_VERSION}\n`);
  process.stdout.write("Comandos: init, status, pause, resume, privacy <metadata|summaries|off>, test, uninstall [--purge]\n");
}

async function main(argv: string[]): Promise<void> {
  const [command, ...rest] = argv;

  // RNF-CC-001: hook y flush nunca bloquean ni rompen Claude Code, nunca
  // escriben en stdout, y siempre salen con código 0. Los errores van al log.
  if (command === "hook") {
    try {
      runHook(rest[0]);
    } catch (error) {
      log(`error en hook ${rest[0]}: ${(error as Error).message}`);
    }
    return;
  }

  if (command === "flush") {
    try {
      await runFlush();
    } catch (error) {
      log(`error en flush: ${(error as Error).message}`);
    }
    return;
  }

  switch (command) {
    case "init":
      await runInit(rest);
      break;
    case "status":
      runStatus();
      break;
    case "pause":
      await runPauseResume(true);
      break;
    case "resume":
      await runPauseResume(false);
      break;
    case "privacy":
      await runPrivacy(rest[0]);
      break;
    case "test":
      await runTest();
      break;
    case "uninstall":
      await runUninstall(rest);
      break;
    case "--version":
    case "-v":
      process.stdout.write(`${CLI_NAME} ${CLI_VERSION}\n`);
      break;
    default:
      printHelp();
  }
}

main(process.argv.slice(2)).catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
