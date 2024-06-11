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

import { readFragment } from "api/relay";
import { graphql } from "relay-runtime";
import type { BaseImageNameResolver$key } from "api/__generated__/BaseImageNameResolver.graphql";

/**
 * @RelayResolver BaseImage.name: String
 * @rootFragment BaseImageNameResolver
 *
 * Base Image name
 */
function name(baseImageKey: BaseImageNameResolver$key): string {
  const { localizedReleaseDisplayNames, version } = readFragment(
    graphql`
      fragment BaseImageNameResolver on BaseImage {
        version
        localizedReleaseDisplayNames {
          value
        }
      }
    `,
    baseImageKey,
  );

  // TODO: for now, only one translation can be present so we take it directly.
  // We can use fragment argument to filter on localizedReleaseDisplayNames on backend
  // and runtime argument to filter by user's language preference on frontend
  // https://relay.dev/docs/guides/relay-resolvers/#defining-resolver-field-with-combined-arguments
  if (localizedReleaseDisplayNames?.length) {
    return `${version} (${localizedReleaseDisplayNames[0].value})`;
  }
  return version;
}

export { name };
