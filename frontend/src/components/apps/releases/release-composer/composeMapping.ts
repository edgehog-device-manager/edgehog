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

// Barrel keeping existing imports stable after the split into
// composeTypes / composeUtils / composeParse / composeSerialize.

export type {
  ComposeMappingResult,
  ComposeServiceData,
  ComposeServiceExtras,
  DeviceMappingData,
  LabelOption,
  MappingContext,
  ReleaseComposeData,
  SerializeOptions,
  SerializeResult,
} from "./composeTypes";
export { composeToFormData } from "./composeParse";
export { formDataToCompose } from "./composeSerialize";
