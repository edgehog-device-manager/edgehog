import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import eslint from "vite-plugin-eslint";
import viteTsconfigPaths from "vite-tsconfig-paths";
import relay from "vite-plugin-relay-lite";

export default defineConfig((env) => {
  return {
    server: {
      open: env.mode !== "test",
      port: 3000,
    },
    build: {
      outDir: "build",
    },
    plugins: [
      react(),
      viteTsconfigPaths(),
      relay(),
      {
        ...eslint({
          failOnWarning: false,
          failOnError: false,
        }),
        apply: "serve",
        enforce: "post",
      },
    ],
    test: {
      environment: "jsdom",
      setupFiles: "./src/setupTests.tsx",
      coverage: {
        provider: "v8",
        reporter: ["lcov", "text", "text-summary"],
        exclude: ["src/api/__generated__/**"],
      },
    },
  };
});
