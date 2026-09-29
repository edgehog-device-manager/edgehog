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
import type { ComposerState } from "./composerTypes";

export const newKey = () =>
  typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2);

export const emptyContainer = (): ContainerInputData => ({
  name: "",
  image: { reference: "" },
  portBindings: [],
  binds: [],
  volumes: [],
  extraHosts: [],
  tmpfs: [],
  capAdd: [],
  capDrop: [],
  storageOpts: [],
  env: [],
  networks: [],
  deviceMappings: [],
  deviceRequests: [],
  fileMounts: [],
});

export const initialComposerState = (): ComposerState => ({
  services: [],
  serviceData: {},
  dependsOnByKey: {},
  extrasByKey: {},
  topLevelExtras: {},
});
