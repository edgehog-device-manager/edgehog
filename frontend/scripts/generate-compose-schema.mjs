/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

// Generates composeSpecSchema.generated.ts from the vendored official Compose
// Specification JSON schema (schema/compose-spec.json).
//
// json-schema-to-zod does not resolve $ref, so every local reference is first
// inlined (the Compose Specification schema has no recursive definitions).

import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { jsonSchemaToZod } from "json-schema-to-zod";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const inputPath = path.join(
  scriptDir,
  "../src/components/apps/releases/release-composer/compose-spec.json",
);
const outputPath = path.join(
  scriptDir,
  "../src/components/apps/releases/release-composer/composeSpecSchema.generated.ts",
);

const header = `/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * This file is generated from schema/compose-spec.json (Compose Specification,
 * https://github.com/compose-spec/compose-spec) by scripts/generate-compose-schema.mjs.
 * Do not edit it manually; run \`npm run compose-schema:generate\` instead.
 */

`;

const resolveRef = (ref, root) => {
  if (!ref.startsWith("#/")) {
    throw new Error(`Unsupported non-local $ref: ${ref}`);
  }

  let node = root;

  for (const segment of ref.slice(2).split("/")) {
    node = node[segment];

    if (node == null) {
      throw new Error(`Unresolvable $ref: ${ref}`);
    }
  }

  return node;
};

const inlineRefs = (node, root, seen = new Set()) => {
  if (Array.isArray(node)) {
    return node.map((item) => inlineRefs(item, root, seen));
  }

  if (node == null || typeof node !== "object") {
    return node;
  }

  // guard against pathological self-references even though the spec has none
  const marker = JSON.stringify(Object.keys(node).sort());

  if (marker === '["$ref"]') {
    const ref = node.$ref;

    if (seen.has(ref)) {
      throw new Error(`Recursive $ref chain at ${ref}`);
    }

    seen.add(ref);

    try {
      return inlineRefs(resolveRef(ref, root), root, new Set(seen));
    } finally {
      seen.delete(ref);
    }
  }

  return Object.fromEntries(
    Object.entries(node).map(([key, value]) => [
      key,
      inlineRefs(value, root, seen),
    ]),
  );
};

const source = JSON.parse(readFileSync(inputPath, "utf8"));
delete source.$id;

const inlined = inlineRefs(source, source);

const generated = jsonSchemaToZod(inlined, {
  name: "composeSpecSchema",
  module: "esm",
  zodVersion: "v4",
  noImport: true,
});

if (!generated.includes("export const composeSpecSchema = ")) {
  throw new Error("Unexpected generator output");
}

writeFileSync(
  outputPath,
  `${header}import { z } from "zod";\n\n${generated}\n`,
);

console.log(`Wrote ${path.relative(path.join(scriptDir, ".."), outputPath)}`);
