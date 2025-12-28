import js from "@eslint/js";
import globals from "globals";
import { FlatCompat } from "@eslint/eslintrc";
import path from "path";
import { fileURLToPath } from "url";
import { createRequire } from "module";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const require = createRequire(import.meta.url);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

// Manually resolve eslint-config-next to avoid resolution errors
// and wrapping it via compat.config if it's legacy (Object)
// or using directly if it's future-proof (Array)
const nextCoreWebVitals = require("eslint-config-next/core-web-vitals");

const nextConfigFlat = Array.isArray(nextCoreWebVitals)
  ? nextCoreWebVitals
  : compat.config(nextCoreWebVitals);

const eslintConfig = [
  {
    ignores: ["**/.next/**", "**/node_modules/**", "**/out/**", "**/dist/**"],
  },
  js.configs.recommended,
  ...nextConfigFlat,
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    rules: {
      "react/no-unescaped-entities": "off",
      "react/react-in-jsx-scope": "off",
      "no-undef": "off", // TypeScript handles this
    },
  },
];

export default eslintConfig;
