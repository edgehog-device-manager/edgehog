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

import type { ContainerInputData } from "@/forms/validation";

export type ComposeServiceExtras = {
  /** Service keys that are not supported by Edgehog, preserved verbatim. */
  keys: Record<string, unknown>;
  /** Original map-form depends_on, restored when the extracted names did not change. */
  dependsOnRaw?: Record<string, unknown>;
  /** Service names extracted from dependsOnRaw. */
  dependsOnExtracted?: string[];
  /** Original map-form networks, restored when the matched networks did not change. */
  networksRaw?: Record<string, unknown>;
  /** Network labels that matched an Edgehog network at parse time. */
  networksMatchedLabels?: string[];
};

export type ComposeServiceData = {
  name: string;
  dependsOn: string[];
  container: ContainerInputData;
  extras?: ComposeServiceExtras;
};

export type ReleaseComposeData = {
  services: ComposeServiceData[];
};

export type LabelOption = {
  label: string;
  value: string;
};

export type DeviceMappingData = {
  pathOnHost: string;
  pathInContainer: string;
  cgroupPermissions: string;
};

export type MappingContext = {
  networkOptions?: LabelOption[];
  volumeOptions?: LabelOption[];
};

export type ComposeMappingResult =
  | {
      ok: true;
      data: ReleaseComposeData;
      topLevelExtras: Record<string, unknown>;
      warnings: string[];
    }
  | { ok: false; error: string };

export type SerializeResult = {
  text: string;
  warnings: string[];
};

export type SerializeOptions = {
  /** Unsupported top-level keys preserved from the original document. */
  topLevelExtras?: Record<string, unknown>;
};
