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

import semver from "semver";

export const TTYD_PORT = 7681;
export const FORWARDER_SESSION_QUERY_PARAM = "x-edgehog-forwarder-session";

export interface OpenRemoteTerminalOptions {
  forwarderVersion: string;
  forwarderHostname: string;
  forwarderPort: number;
  secure: boolean;
  sessionToken: string;
  token?: string | null;
}

export const openRemoteTerminal = ({
  forwarderVersion,
  forwarderHostname,
  forwarderPort,
  secure,
  sessionToken,
  token,
}: OpenRemoteTerminalOptions): void => {
  const forwarderProtocol = secure ? "https" : "http";

  console.log(forwarderVersion);

  if (semver.satisfies(forwarderVersion, "0.1.x")) {
    window.open(
      `${forwarderProtocol}://${forwarderHostname}:${forwarderPort}/${sessionToken}/http/${TTYD_PORT}`,
      "_blank",
    );
  } else if (semver.satisfies(forwarderVersion, "0.2.x")) {
    window.open(
      `${forwarderProtocol}://${forwarderHostname}:${forwarderPort}/?session=${sessionToken}&protocol=http&port=${TTYD_PORT}`,
      "_blank",
    );
  } else if (semver.satisfies(forwarderVersion, "0.3.x")) {
    if (!token) {
      throw new Error("Missing forwarder session JWT token.");
    }

    window.open(
      `${forwarderProtocol}://${forwarderHostname}:${forwarderPort}/?${FORWARDER_SESSION_QUERY_PARAM}=${encodeURIComponent(token)}`,
      "_blank",
    );
  }
};
