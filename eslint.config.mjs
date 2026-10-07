import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// Lints application source, configuration files and JavaScript tests/scripts.
export default defineConfig([
  ...nextVitals,
  ...nextTs,
  globalIgnores([
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    ".agent-out/**",
    ".specify/**",
    ".claude/**",
    ".agents/**",
    ".grok/**",
  ]),
]);
