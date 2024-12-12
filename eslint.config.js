export default [
  {
    ignores: ["node_modules/**"],
  },
  {
    env: {
      browser: true,
      es2021: true,
      node: true
    },
    files: ["**/*.js", "**/*.jsx", "**/*.ts", "**/*.tsx", "**/*.vue"],
    languageOptions: {
      ecmaVersion: 2021,
      sourceType: "module",
    },
    rules: {
      "indent": ["error", 2],
      "linebreak-style": ["error", "unix"],
      "quotes": ["error", "single"],
      "semi": ["error", "always"]
    },
  },
];
