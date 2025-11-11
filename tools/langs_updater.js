#!/usr/bin/env node
//
// This file is part of Edgehog.
//
// Copyright 2025 SECO Mind Srl
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
 * This script implements two functionalities for translation files.
 *
 * Usage:
 *   node langs_updater.js --check [directory]
 *   node langs_updater.js --reorder [directory]
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
};

// Get command-line flags and optional directory
const args = process.argv.slice(2);
const checkFlag = args.includes("--check");
const reorderFlag = args.includes("--reorder");

if (!checkFlag && !reorderFlag) {
  console.error(
    `${ansi.red} ${emoji.error} Error: ${ansi.reset} Please provide either the --check or --reorder flag.`
  );
  process.exit(1);
}

if (checkFlag && reorderFlag) {
  console.error(
    `${ansi.red} ${emoji.error} Error: ${ansi.reset} Please provide only one flag at a time (--check or --reorder).`
  );
  process.exit(1);
}

// Determine target directory; if provided as an argument (other than flags), use it.
const potentialDirs = args.filter(
  (arg) => arg !== "--check" && arg !== "--reorder"
);
const targetDir = potentialDirs.length > 0 ? potentialDirs[0] : ".";
const directory = path.resolve(process.cwd(), targetDir);

console.log(
  `${ansi.blue}${emoji.folder} Using directory: ${ansi.reset}${ansi.cyan}${directory}${ansi.reset}`
);

// Define reference file name and path
const refFileName = "en.json";
const refFilePath = path.join(directory, refFileName);

if (!fs.existsSync(refFilePath)) {
  console.error(
    `${ansi.red}${emoji.error} Error: ${ansi.reset} Reference file ${ansi.yellow}${refFileName}${ansi.reset} not found in ${ansi.cyan}${directory}${ansi.reset}`
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
    `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read or parse ${ansi.yellow}${refFileName}${ansi.reset}: ${err.message}`
  );
  process.exit(1);
}
const refKeys = Object.keys(refJSON);
// Count the number of keys in the reference JSON
const refKeyCount = refKeys.length;

// Get all .json files in the directory
const allFiles = fs.readdirSync(directory).filter((f) => f.endsWith(".json"));

if (checkFlag) {
  console.log(
    `${ansi.blue}${emoji.gear} Starting check ${ansi.reset}using ${ansi.yellow}${refFileName}${ansi.reset} as the reference...\n`
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
        `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read or parse ${ansi.yellow}${file}${ansi.reset}: ${err.message}`
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
          line.includes(`"${fileKeys[i]}"`)
        );
        errorLine = errorLine !== -1 ? errorLine + 1 : "unknown";
        console.error(
          `\n${ansi.red}${emoji.error} Key ordering mismatch in ${ansi.yellow}${file}${ansi.reset}:`
        );
        console.error(
          `  At line ${ansi.bold}${errorLine}${ansi.reset}: expected ${
            ansi.green
          }"${refKeys[i]}"${ansi.reset} but found ${ansi.red}"${
            fileKeys[i] || "undefined"
          }"${ansi.reset}\n`
        );
        process.exit(1);
      }
    }

    // Compare key counts: stop if they differ.
    const fileKeyCount = fileKeys.length;
    if (refKeyCount !== fileKeyCount) {
      console.error(
        `\n${ansi.red}${emoji.error} Key count mismatch in ${ansi.yellow}${file}${ansi.reset}:`
      );

      console.error(
        `  Expected ${ansi.green}${refKeyCount}${ansi.reset} keys, got ${ansi.red}${fileKeyCount}${ansi.reset} keys\n`
      );
      process.exit(1);
    }
    console.log(
      `${ansi.green}${emoji.check} OK: ${ansi.reset}${ansi.yellow}${file}${ansi.reset} matches the reference ${ansi.yellow}${refFileName}${ansi.reset}`
    );
  }

  console.log(
    `\n${ansi.green}${emoji.sparkles} Success: ${ansi.reset} All language files in ${ansi.cyan}${directory}${ansi.reset} have identical key ordering and count as ${ansi.yellow}${refFileName}${ansi.reset}!`
  );
}

if (reorderFlag) {
  console.log(
    `${ansi.blue}${emoji.gear} Starting reordering process ${ansi.reset}based on ${ansi.yellow}${refFileName}${ansi.reset}...\n`
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
        `${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to read or parse ${ansi.yellow}${file}${ansi.reset}: ${err.message}`
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
          `${emoji.arrow} ${ansi.green}Added${ansi.reset} missing key ${ansi.yellow}"${key}"${ansi.reset}`
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
            `${emoji.pen} ${ansi.green}Added${ansi.reset} missing description for ${ansi.yellow}"${key}"${ansi.reset}`
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
            `${emoji.warn} ${ansi.yellow}Removed${ansi.reset} unnecessary description for ${ansi.yellow}"${key}"${ansi.reset}`
          );
        }
      }
    }

    // Check for extra keys that are not in the reference file.
    const extraKeys = Object.keys(fileJSON).filter(
      (key) => !refKeys.includes(key)
    );
    if (extraKeys.length > 0) {
      logMessages.push(
        `${emoji.warn} ${ansi.yellow}Removed${
          ansi.reset
        } extra keys: ${extraKeys
          .map((k) => ansi.red + k + ansi.reset)
          .join(", ")}`
      );
    }

    // Overwrite the file with the new ordered JSON, formatted with 2-space indent.
    try {
      fs.writeFileSync(
        filePath,
        JSON.stringify(newJSON, null, 2) + "\n",
        "utf8"
      );
      console.log(
        `\n${ansi.cyan}${emoji.sparkles} Reordered file: ${ansi.reset}${ansi.yellow}${file}${ansi.reset}`
      );
      logMessages.forEach((msg) => console.log("  " + msg));
    } catch (err) {
      console.error(
        `\n${ansi.red}${emoji.error} Error: ${ansi.reset} Failed to write ${ansi.yellow}${file}${ansi.reset}: ${err.message}`
      );
      process.exit(1);
    }
  }

  console.log(
    `\n${ansi.green}${emoji.check} Done: ${ansi.reset} All files reordered and cleaned successfully.`
  );
}
