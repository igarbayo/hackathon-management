import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// RNF-UI-001 (specs/13-sistema-diseno.md): la web sigue el sistema de
// diseño F0 con tokens semánticos (`f1-*` y los alias de shadcn ya
// mapeados a ellos en globals.css). Prohibido colar un color de la paleta
// de Tailwind en crudo o un hex dentro de `className`.
const PALETTE_COLORS =
  "slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose";
const rawPaletteSelector = `JSXAttribute[name.name='className'] Literal[value=/\\b(bg|text|border|ring|from|via|to|fill|stroke|decoration|outline|divide|accent|caret)-(${PALETTE_COLORS})-[0-9]{2,3}\\b/]`;
const hexColorSelector =
  "JSXAttribute[name.name='className'] Literal[value=/#[0-9a-fA-F]{3}([0-9a-fA-F]{3}){0,2}\\b/]";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    rules: {
      "no-restricted-syntax": [
        "error",
        {
          selector: rawPaletteSelector,
          message:
            "Usa un token f1-* (o su alias shadcn) en vez de un color de la paleta Tailwind en crudo — RNF-UI-001, ver specs/13-sistema-diseno.md.",
        },
        {
          selector: hexColorSelector,
          message:
            "No se permiten colores hexadecimales en className — usa un token f1-* — RNF-UI-001, ver specs/13-sistema-diseno.md.",
        },
      ],
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
