import tseslint from "typescript-eslint";

export default tseslint.config(
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
  },
  {
    files: ["**/*.ts"],
    rules: {
      "max-lines": ["error", { max: 250, skipBlankLines: false, skipComments: false }],
      "no-magic-numbers": ["error", { ignore: [0, 1, -1], enforceConst: true, detectObjects: true }],
      "@typescript-eslint/explicit-function-return-type": "error",
      "@typescript-eslint/no-non-null-assertion": "error",
    },
  },
  { ignores: ["dist/**", "vite.config.ts", "eslint.config.js"] },
);
