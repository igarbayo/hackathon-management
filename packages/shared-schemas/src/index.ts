import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const SCHEMAS_DIR = join(__dirname, "..", "schemas");

export function listSchemaNames(): string[] {
  return readdirSync(SCHEMAS_DIR)
    .filter((file) => file.endsWith(".schema.json"))
    .map((file) => file.replace(/\.schema\.json$/, ""));
}

export function getSchema(name: string): Record<string, unknown> {
  const path = join(SCHEMAS_DIR, `${name}.schema.json`);
  try {
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error(`There is no schema "${name}" in packages/shared-schemas/schemas`);
    }
    throw error;
  }
}
