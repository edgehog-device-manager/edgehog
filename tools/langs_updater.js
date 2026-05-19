#!/usr/bin/env node
//
// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
//

/**
 * This script implements multi-mode functionalities for translation files.
 *
 * Usage:
 *   node langs_updater.js --check [directory]
 *   node langs_updater.js --reorder [directory]
 *   node langs_updater.js --check-paths [directory]
 *   node langs_updater.js --fix-paths [directory]
 *
 * If no directory is provided, the script will use the current working directory.
 *
 * --check flag:
 *   - Loads en.json as the reference file.
 *   - For every other .json file in the provided directory, it compares:
 *       • That the keys (and their ordering) match en.json.
 *       • That the number of keys in each file matches en.json.
 *   - The script stops on the first error and displays the actual file line number and error details.
 *
 * --reorder flag:
 *   - Reorders all JSON translation files (except en.json) to match the key order of en.json.
 *   - For each key in en.json:
 *       • If the key is missing in the target file, it copies the key’s content from en.json.
 *       • If the key exists but has no description while en.json does, it copies over the description.
 *       • If the key exists with a description but en.json does not have one, the description is removed.
 *   - Any keys present in the target file that are not in en.json are removed.
 *   - The script prints detailed messages on the changes made.
 *
 * --check-paths flag:
 *  - Scans source files for translation IDs used in `FormattedMessage`, `formatMessage`, and `defineMessages`.
 *  - Ensures every ID follows the prefix derived from the file path:
 *      • `frontend/src/forms/MyForm.tsx` -> `forms.MyForm.<...>`
 *      • `frontend/src/components/MyCmp.tsx` -> `components.MyCmp.<...>`
 *  - Reports any IDs that do not match the expected prefix.
 *
 * --fix-paths flag:
 *  - Performs the exact same scan as --check-paths.
 *  - Automatically modifies the source code files to replace the invalid IDs with the correct ones.
 */

const fs = require("fs");
const path = require("path");

// ANSI color codes
const ansi = {
  reset: "\x1b[0m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
  bold: "\x1b[1m",
};

// Emoji shortcuts
const emoji = {
  info: "ℹ️",
  check: "✅",
  error: "❌",
  warn: "⚠️ ",
  sparkles: "✨",
  arrow: "➡️ ",
  gear: "⚙️ ",
  folder: "📁",
  pen: "✏️ ",
  wrench: "🛠️ ",
};

const knownFlags = new Set([
  "--check",
  "--reorder",
  "--check-paths",
  "--fix-paths",
]);

// Argument Parsing

const args = process.argv.slice(2);
const modeFlags = new Set();
const positionalArgs = [];

for (const arg of args) {
  if (knownFlags.has(arg)) {
    modeFlags.add(arg);
  } else {
    positionalArgs.push(arg);
  }
}

const checkFlag = modeFlags.has("--check");
const reorderFlag = modeFlags.has("--reorder");
const checkPathsFlag = modeFlags.has("--check-paths");
const fixPathsFlag = modeFlags.has("--fix-paths");

if (modeFlags.size !== 1) {
  console.error(
    `${ansi.red}${emoji.error} Error:${ansi.reset} Please provide exactly one mode: --check, --reorder, --check-paths, or --fix-paths.`,
  );
  process.exit(1);
}

// Determine target directory; if provided as an argument (other than flags), use it.
const targetDir = positionalArgs.length > 0 ? positionalArgs[0] : ".";
const directory = path.resolve(process.cwd(), targetDir);

console.log(
  `${ansi.blue}${emoji.folder} Using directory: ${ansi.reset}${ansi.cyan}${directory}${ansi.reset}`,
);

// Define reference file name and path
const refFileName = "en.json";
const refFilePath = path.join(directory, refFileName);

if (!fs.existsSync(refFilePath)) {
  console.error(
    `${ansi.red}${emoji.error} Error: ${ansi.reset} Reference file ${ansi.yellow}${refFileName}${ansi.reset} not found in ${ansi.cyan}${directory}${ansi.reset}`,
  );
  process.exit(1);
}

// Read and parse the reference file
let refContent, refJSON;
try {
  refContent = fs.readFileSync(refFilePath, "utf8");
  refJSON = JSON.parse(refContent);
} catch (err) {
  console.error(
    `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read or parse ${ansi.yellow}${refFileName}${ansi.reset}: ${err.message}`,
  );
  process.exit(1);
}
const refKeys = Object.keys(refJSON);
// Count the number of keys in the reference JSON
const refKeyCount = refKeys.length;

// Get all .json files in the directory
const allFiles = fs.readdirSync(directory).filter((f) => f.endsWith(".json"));

// Helper: Resolve the source code directory
const resolveSourceDirectory = () => {
  const candidates = [
    path.resolve(directory, "..", ".."),
    path.resolve(process.cwd(), "frontend", "src"),
    path.resolve(process.cwd(), "src"),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
      return candidate;
    }
  }
  return null;
};

// Helper: Find valid top-level directories within src
const getPathScopes = (sourceDir) =>
  fs
    .readdirSync(sourceDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
    .map((entry) => entry.name);

// Helper: Walk the tree to find all React/JS/TS files
const getSourceFiles = (rootDir) => {
  const files = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith(".")) continue;

      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (/\.(ts|tsx|js|jsx)$/.test(entry.name)) {
        files.push(fullPath);
      }
    }
  };
  walk(rootDir);
  return files;
};

// Helper: Expand the ID search to find FormattedMessage, formatMessage, defineMessages, and raw objects.
// Returns array of objects with the matched id, line number, and start/end string indices.
const findTranslationIds = (source) => {
  const matches = [];
  let match;

  // 1. FormattedMessage components
  const regexJSX = /<FormattedMessage\b[\s\S]*?\bid\s*=\s*(['"])(.*?)\1/g;
  while ((match = regexJSX.exec(source)) !== null) {
    const idPositionIndex = match.index + match[0].length;
    const line = source.slice(0, idPositionIndex).split("\n").length;
    const endIndex = idPositionIndex - 1; // index of closing quote
    const startIndex = endIndex - match[2].length; // index of first char of ID string
    matches.push({ id: match[2], line, startIndex, endIndex });
  }

  // 2. formatMessage calls (e.g., intl.formatMessage({ id: "..." }))
  const regexFormatMsg =
    /formatMessage\s*\(\s*\{[\s\S]*?\bid\s*:\s*(['"])(.*?)\1/g;
  while ((match = regexFormatMsg.exec(source)) !== null) {
    const idPositionIndex = match.index + match[0].length;
    const line = source.slice(0, idPositionIndex).split("\n").length;
    const endIndex = idPositionIndex - 1;
    const startIndex = endIndex - match[2].length;
    matches.push({ id: match[2], line, startIndex, endIndex });
  }

  // 3. defineMessages blocks
  const regexDefineMsgsBlock = /defineMessages\s*\(\s*\{([\s\S]*?)\}\s*\)/g;
  let blockMatch;
  while ((blockMatch = regexDefineMsgsBlock.exec(source)) !== null) {
    const blockContent = blockMatch[1];
    const blockStartIndex =
      blockMatch.index + blockMatch[0].indexOf(blockMatch[1]);

    const idRegex = /\bid\s*:\s*(['"])(.*?)\1/g;
    let idMatch;
    while ((idMatch = idRegex.exec(blockContent)) !== null) {
      const absoluteIndex = blockStartIndex + idMatch.index + idMatch[0].length;
      const line = source.slice(0, absoluteIndex).split("\n").length;
      const endIndex = absoluteIndex - 1;
      const startIndex = endIndex - idMatch[2].length;
      matches.push({ id: idMatch[2], line, startIndex, endIndex });
    }
  }

  // 4. Raw translation objects (e.g., standard JS objects with id and defaultMessage)
  // We use two regexes to catch both ordering possibilities within a single object block `{ ... }`.
  const rawObjRegexes = [
    // Matches if id comes before defaultMessage: { ..., id: "...", ..., defaultMessage: ...
    /\{\s*[^{}]*?\bid\s*:\s*(['"])(.*?)\1[^{}]*?\bdefaultMessage\s*:/g,
    // Matches if defaultMessage comes before id: { ..., defaultMessage: ..., ..., id: "..." ...
    /\{\s*[^{}]*?\bdefaultMessage\s*:[^{}]*?\bid\s*:\s*(['"])(.*?)\1/g,
  ];

  for (const regex of rawObjRegexes) {
    let rawBlockMatch;
    while ((rawBlockMatch = regex.exec(source)) !== null) {
      const blockContent = rawBlockMatch[0];
      const blockStartIndex = rawBlockMatch.index;

      const idRegex = /\bid\s*:\s*(['"])(.*?)\1/;
      const idMatch = idRegex.exec(blockContent);

      if (idMatch) {
        const absoluteIndex =
          blockStartIndex + idMatch.index + idMatch[0].length;
        const endIndex = absoluteIndex - 1;
        const startIndex = endIndex - idMatch[2].length;

        // Ensure we don't duplicate matches already caught by defineMessages or formatMessage
        const exists = matches.some((m) => m.startIndex === startIndex);
        if (!exists) {
          const line = source.slice(0, absoluteIndex).split("\n").length;
          matches.push({ id: idMatch[2], line, startIndex, endIndex });
        }
      }
    }
  }

  return matches;
};

// Helper: Get expected prefix, gracefully handling `index.tsx` patterns
const getExpectedPrefix = (sourceFilePath, sourceRoot, pathScopes) => {
  const rel = path.relative(sourceRoot, sourceFilePath);
  const segments = rel.split(path.sep);

  if (segments.length < 2) return null;

  const scope = segments[0];
  if (!pathScopes.includes(scope)) return null;

  const directoryParts = segments.slice(0, -1);
  const fileName = path.basename(sourceFilePath, path.extname(sourceFilePath));

  // If the file is 'index.tsx', the prefix shouldn't end in '.index'
  const expectedParts =
    fileName === "index" && directoryParts.length > 0
      ? [...directoryParts]
      : [...directoryParts, fileName];

  return {
    scope,
    fileName,
    expectedParts,
    expectedPrefix: `${expectedParts.join(".")}.`,
  };
};

// CORE FUNCTION: Validates and optionally Fixes Path mismatches in Source Code
const runPathValidation = (isFixMode = false) => {
  const sourceDir = resolveSourceDirectory();
  if (!sourceDir || !fs.existsSync(sourceDir)) {
    console.error(
      `${ansi.red}${emoji.error} Error: ${ansi.reset} Could not resolve source directory automatically. Run the command from the repository root or from the frontend directory.`,
    );
    process.exit(1);
  }

  console.log(
    `${ansi.blue}${emoji.folder} Source directory: ${ansi.reset}${ansi.cyan}${sourceDir}${ansi.reset}`,
  );
  const pathScopes = getPathScopes(sourceDir);

  const sourceFiles = getSourceFiles(sourceDir);
  const mismatches = [];

  // 1. Scan Source Files
  for (const sourceFilePath of sourceFiles) {
    const prefixInfo = getExpectedPrefix(sourceFilePath, sourceDir, pathScopes);
    if (!prefixInfo) continue;

    let sourceContent;
    try {
      sourceContent = fs.readFileSync(sourceFilePath, "utf8");
    } catch (err) {
      console.error(
        `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read ${ansi.yellow}${sourceFilePath}${ansi.reset}: ${err.message}`,
      );
      process.exit(1);
    }

    const ids = findTranslationIds(sourceContent);
    for (const item of ids) {
      const { id, line, startIndex, endIndex } = item;

      if (id.startsWith(prefixInfo.expectedPrefix)) continue;

      const parts = id.split(".");
      let suggested = null;

      // Guess correct structure if they share the tail
      if (
        parts.length > prefixInfo.expectedParts.length &&
        parts.slice(1, prefixInfo.expectedParts.length).join(".") ===
          prefixInfo.expectedParts.slice(1).join(".")
      ) {
        suggested = `${prefixInfo.expectedParts[0]}.${parts.slice(1).join(".")}`;
      }

      // Handle common legacy pattern in forms
      if (!suggested && prefixInfo.scope === "forms" && parts.length > 2) {
        suggested = `${prefixInfo.expectedParts.join(".")}.${parts.slice(2).join(".")}`;
      }

      // Fallback: Append the last segment of the mismatched ID to the expected prefix.
      // Solves mismatches like `validation.required` -> `forms.validation.required`
      // and `components.OldTable.myTitle` -> `components.NewTable.myTitle`
      if (!suggested) {
        suggested = `${prefixInfo.expectedPrefix}${parts[parts.length - 1]}`;
      }

      mismatches.push({
        file: sourceFilePath,
        sourceContent, // passed along to facilitate rewriting
        line,
        id,
        startIndex,
        endIndex,
        expectedPrefix: prefixInfo.expectedPrefix,
        suggested,
      });
    }
  }

  // 2. Report & Resolve
  if (mismatches.length > 0) {
    if (!isFixMode) {
      console.error(
        `\n${ansi.red}${emoji.error} Found ${mismatches.length} translation ID path mismatches:${ansi.reset}`,
      );
      for (const mismatch of mismatches) {
        console.error(
          `  ${ansi.yellow}${mismatch.file}:${mismatch.line}${ansi.reset} -> ${ansi.red}${mismatch.id}${ansi.reset} (expected prefix ${ansi.green}${mismatch.expectedPrefix}${ansi.reset})`,
        );
        if (mismatch.suggested) {
          console.error(
            `    ${emoji.arrow} Suggested fix: ${ansi.green}${mismatch.suggested}${ansi.reset}`,
          );
        }
      }
      process.exit(1);
    } else {
      // Fix mode applies changes back to the source code files
      console.log(
        `\n${ansi.cyan}${emoji.wrench} Applying automated fixes to source files...${ansi.reset}`,
      );

      // Group by file
      const mismatchesByFile = {};
      for (const m of mismatches) {
        if (!mismatchesByFile[m.file]) {
          mismatchesByFile[m.file] = { content: m.sourceContent, fixes: [] };
        }
        mismatchesByFile[m.file].fixes.push(m);
      }

      let totalFixed = 0;
      let totalSkipped = 0;

      for (const [file, data] of Object.entries(mismatchesByFile)) {
        let newContent = data.content;
        let fileModified = false;

        // Sort descending by index so that multiple replacements in one file
        // do not throw off the position mapping for earlier substrings
        data.fixes.sort((a, b) => b.startIndex - a.startIndex);

        for (const fix of data.fixes) {
          if (fix.suggested) {
            newContent =
              newContent.slice(0, fix.startIndex) +
              fix.suggested +
              newContent.slice(fix.endIndex);
            fileModified = true;
            totalFixed++;
          } else {
            console.error(
              `  ${ansi.yellow}${emoji.warn} Could not auto-fix ${ansi.red}${fix.id}${ansi.reset} in ${ansi.cyan}${file}:${fix.line}${ansi.reset}`,
            );
            totalSkipped++;
          }
        }

        if (fileModified) {
          try {
            fs.writeFileSync(file, newContent, "utf8");
          } catch (err) {
            console.error(
              `\n${ansi.red}${emoji.error} Error:${ansi.reset} Failed to write changes to ${ansi.yellow}${file}${ansi.reset}: ${err.message}`,
            );
            process.exit(1);
          }
        }
      }

      console.log(
        `\n${ansi.green}${emoji.sparkles} Fix complete: ${ansi.reset} Automatically fixed ${totalFixed} IDs. Skipped ${totalSkipped} IDs that couldn't be resolved.`,
      );
      if (totalSkipped > 0) {
        process.exit(1); // Exit with error if some files still require manual attention
      }
    }
  } else {
    console.log(
      `\n${ansi.green}${emoji.sparkles} Success: ${ansi.reset} All path-based translation IDs are valid.`,
    );
  }
};

// --- Execution Blocks ---

if (checkFlag) {
  console.log(
    `${ansi.blue}${emoji.gear} Starting check ${ansi.reset}using ${ansi.yellow}${refFileName}${ansi.reset} as the reference...\n`,
  );

  for (const file of allFiles) {
    if (file === refFileName) continue; // Skip reference file

    const filePath = path.join(directory, file);
    let fileContent, fileJSON;
    try {
      fileContent = fs.readFileSync(filePath, "utf8");
      fileJSON = JSON.parse(fileContent);
    } catch (err) {
      console.error(
        `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read or parse ${ansi.yellow}${file}${ansi.reset}: ${err.message}`,
      );
      process.exit(1);
    }

    const fileKeys = Object.keys(fileJSON);

    // Compare key ordering: stop on the first mismatch.
    for (let i = 0; i < refKeys.length; i++) {
      if (refKeys[i] !== fileKeys[i]) {
        // Attempt to compute the actual line number for the key in the file
        const fileLines = fileContent.split("\n");
        let errorLine = fileLines.findIndex((line) =>
          line.includes(`"${fileKeys[i]}"`),
        );
        errorLine = errorLine !== -1 ? errorLine + 1 : "unknown";
        console.error(
          `\n${ansi.red}${emoji.error} Key ordering mismatch in ${ansi.yellow}${file}${ansi.reset}:`,
        );
        console.error(
          `  At line ${ansi.bold}${errorLine}${ansi.reset}: expected ${
            ansi.green
          }"${refKeys[i]}"${ansi.reset} but found ${ansi.red}"${
            fileKeys[i] || "undefined"
          }"${ansi.reset}\n`,
        );
        process.exit(1);
      }
    }

    // Compare key counts: stop if they differ.
    const fileKeyCount = fileKeys.length;
    if (refKeyCount !== fileKeyCount) {
      console.error(
        `\n${ansi.red}${emoji.error} Key count mismatch in ${ansi.yellow}${file}${ansi.reset}:`,
      );

      console.error(
        `  Expected ${ansi.green}${refKeyCount}${ansi.reset} keys, got ${ansi.red}${fileKeyCount}${ansi.reset} keys\n`,
      );
      process.exit(1);
    }
    console.log(
      `${ansi.green}${emoji.check} OK: ${ansi.reset}${ansi.yellow}${file}${ansi.reset} matches the reference ${ansi.yellow}${refFileName}${ansi.reset}`,
    );
  }

  console.log(
    `\n${ansi.green}${emoji.sparkles} Success: ${ansi.reset} All language files in ${ansi.cyan}${directory}${ansi.reset} have identical key ordering and count as ${ansi.yellow}${refFileName}${ansi.reset}!`,
  );
}

if (reorderFlag) {
  console.log(
    `${ansi.blue}${emoji.gear} Starting reordering process ${ansi.reset}based on ${ansi.yellow}${refFileName}${ansi.reset}...\n`,
  );

  for (const file of allFiles) {
    if (file === refFileName) continue; // Do not modify the reference file

    const filePath = path.join(directory, file);
    let fileContent, fileJSON;
    try {
      fileContent = fs.readFileSync(filePath, "utf8");
      fileJSON = JSON.parse(fileContent);
    } catch (err) {
      console.error(
        `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read or parse ${ansi.yellow}${file}${ansi.reset}: ${err.message}`,
      );
      process.exit(1);
    }

    const newJSON = {};
    const logMessages = [];

    // Process keys in the reference order
    for (const key of refKeys) {
      if (!(key in fileJSON)) {
        // Key is missing: copy entire structure from reference.
        newJSON[key] = { ...refJSON[key] };
        logMessages.push(
          `${emoji.arrow} ${ansi.green}Added${ansi.reset} missing key ${ansi.yellow}"${key}"${ansi.reset}`,
        );
      } else {
        // Key exists: copy current value and adjust if needed.
        newJSON[key] = { ...fileJSON[key] };

        // If key exists and has a defaultMessage but no description, and reference has a description, add it.
        if (
          newJSON[key].hasOwnProperty("defaultMessage") &&
          !newJSON[key].hasOwnProperty("description") &&
          refJSON[key].hasOwnProperty("description")
        ) {
          newJSON[key]["description"] = refJSON[key]["description"];
          logMessages.push(
            `${emoji.pen} ${ansi.green}Added${ansi.reset} missing description for ${ansi.yellow}"${key}"${ansi.reset}`,
          );
        }

        // If key exists with both defaultMessage and description,
        // but the reference does not have a description, remove it.
        if (
          newJSON[key].hasOwnProperty("defaultMessage") &&
          newJSON[key].hasOwnProperty("description") &&
          !refJSON[key].hasOwnProperty("description")
        ) {
          delete newJSON[key]["description"];
          logMessages.push(
            `${emoji.warn} ${ansi.yellow}Removed${ansi.reset} unnecessary description for ${ansi.yellow}"${key}"${ansi.reset}`,
          );
        }
      }
    }

    // Check for extra keys that are not in the reference file.
    const extraKeys = Object.keys(fileJSON).filter(
      (key) => !refKeys.includes(key),
    );
    if (extraKeys.length > 0) {
      logMessages.push(
        `${emoji.warn} ${ansi.yellow}Removed${
          ansi.reset
        } extra keys: ${extraKeys
          .map((k) => ansi.red + k + ansi.reset)
          .join(", ")}`,
      );
    }

    // Overwrite the file with the new ordered JSON, formatted with 2-space indent.
    try {
      fs.writeFileSync(
        filePath,
        JSON.stringify(newJSON, null, 2) + "\n",
        "utf8",
      );
      console.log(
        `\n${ansi.cyan}${emoji.sparkles} Reordered file: ${ansi.reset}${ansi.yellow}${file}${ansi.reset}`,
      );
      logMessages.forEach((msg) => console.log("  " + msg));
    } catch (err) {
      console.error(
        `\n${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to write ${ansi.yellow}${file}${ansi.reset}: ${err.message}`,
      );
      process.exit(1);
    }
  }
  console.log(
    `\n${ansi.green}${emoji.check} Done: ${ansi.reset} All files reordered and cleaned successfully.`,
  );
}

if (checkPathsFlag) {
  console.log(
    `${ansi.blue}${emoji.gear} Starting path-based translation check${ansi.reset}...\n`,
  );
  runPathValidation(false);
}

if (fixPathsFlag) {
  console.log(
    `${ansi.blue}${emoji.gear} Starting path-based translation fix${ansi.reset}...\n`,
  );
  runPathValidation(true);
}
