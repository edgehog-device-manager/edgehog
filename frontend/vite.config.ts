import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import checker from "vite-plugin-checker";

export default defineConfig(({ mode }) => {
  return {
    resolve: {
      tsconfigPaths: true,
    },
    server: {
      open: mode !== "test",
      port: 3000,
    },
    build: {
      outDir: "build",
    },
    css: {
      preprocessorOptions: {
        scss: {
          quietDeps: true,
        },
      },
    },
    plugins: [
      react({
        babel: {
          plugins: ["babel-plugin-relay"],
        },
      }),
      checker({
        eslint: {
          lintCommand: 'eslint "./src/**/*.{ts,tsx}"',
          useFlatConfig: true,
        },
        enableBuild: false,
        overlay: {
          initialIsOpen: false,
        },
      }),
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
