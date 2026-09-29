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

import { envJsonSchema } from "@/forms/validation";

export type EnvMode = "none" | "override" | "file";

export type ContainerEnvVar = {
  key: string;
  value: string;
};

export { envJsonSchema };

export const isEnvJsonValid = (envJson: string | null | undefined): boolean =>
  envJsonSchema.safeParse(envJson).success;

export const parseEnvJson = (
  envJson: string | null | undefined,
): ContainerEnvVar[] | undefined => {
  const result = envJsonSchema.safeParse(envJson);
  return result.success ? result.data : undefined;
};

export const getContainerEnvVars = (
  mode: EnvMode | undefined,
  envJson: string | undefined,
): ContainerEnvVar[] | undefined => {
  return mode === "override" ? parseEnvJson(envJson || "{}") : undefined;
};

export const reduceEnv = (env: ContainerEnvVar[]): Record<string, string> =>
  env.reduce<Record<string, string>>((acc, envVar) => {
    acc[envVar.key] = envVar.value;
    return acc;
  }, {});

export const envToString = (env: ContainerEnvVar[]): string =>
  JSON.stringify(reduceEnv(env), null, 2);

export const areAllEnvJsonsValid = (
  containers: ReadonlyArray<{ id: string }>,
  envModes: Record<string, EnvMode>,
  envJsons: Record<string, string>,
): boolean => {
  return containers.every(
    (c) =>
      envModes[c.id] !== "override" || isEnvJsonValid(envJsons[c.id] || "{}"),
  );
};
