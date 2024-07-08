/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import * as RelayRuntime from "relay-runtime";

RelayRuntime.RelayFeatureFlags.ENABLE_RELAY_RESOLVERS = true;

export const readFragment =
  RelayRuntime.__internal.ResolverFragments.readFragment;

declare module "relay-runtime" {
  export interface PayloadError {
    message: string;
    locations?: Array<{
      line: number;
      column: number;
    }>;
    code: string;
    path?: Array<string | number>;
    fields: string[];
    short_message: string;
  }
}
