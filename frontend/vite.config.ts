import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import checker from "vite-plugin-checker";
import { fileURLToPath } from "node:url";

// monaco-vim imports monaco-editor internals through subpaths that are
// not exposed by monaco-editor's package exports map; point them to the
// physical files.
const monacoAlias = (relativePath: string) =>
  fileURLToPath(
    new URL(`./node_modules/monaco-editor/esm/vs/${relativePath}`, import.meta.url),
  );

export default defineConfig(({ mode }) => {
  return {
    resolve: {
      tsconfigPaths: true,
      alias: {
        "monaco-editor/esm/vs/editor/editor.api": monacoAlias(
          "editor/editor.api.js",
        ),
        "monaco-editor/esm/vs/editor/common/commands/shiftCommand":
          monacoAlias("editor/common/commands/shiftCommand.js"),
      },
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
      server: {
        deps: {
          // monaco-vim must go through the vite resolution pipeline so the
          // monaco-editor aliases above are applied
          inline: ["monaco-vim"],
        },
      },
      coverage: {
        provider: "v8",
        reporter: ["lcov", "text", "text-summary"],
        exclude: ["src/api/__generated__/**"],
      },
    },
  };
});
