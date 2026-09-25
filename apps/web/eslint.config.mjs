import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// RNF-UI-001 (specs/13-sistema-diseno.md): the web app follows the F0
// design system with semantic tokens (`f1-*` and the shadcn aliases already
// mapped to them in globals.css). Raw Tailwind palette colors and hex values
// inside `className` are not allowed.
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
            "Use an f1-* token (or its shadcn alias) instead of a raw Tailwind palette color — RNF-UI-001, see specs/13-sistema-diseno.md.",
        },
        {
          selector: hexColorSelector,
          message:
            "Hex colors are not allowed in className — use an f1-* token — RNF-UI-001, see specs/13-sistema-diseno.md.",
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
