#!/usr/bin/env node
import { CLI_NAME, CLI_VERSION } from "../index";

function main(argv: string[]): void {
  const [command] = argv;

  if (command === "--version" || command === "-v") {
    process.stdout.write(`${CLI_NAME} ${CLI_VERSION}\n`);
    return;
  }

  process.stdout.write(`${CLI_NAME} ${CLI_VERSION}\nComandos disponibles próximamente (ver specs/08-integracion-claude-code.md).\n`);
}

main(process.argv.slice(2));
