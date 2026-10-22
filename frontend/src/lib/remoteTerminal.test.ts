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

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  FORWARDER_SESSION_QUERY_PARAM,
  TTYD_PORT,
  openRemoteTerminal,
} from "./remoteTerminal";

describe("remoteTerminal", () => {
  describe("openRemoteTerminal", () => {
    const originalOpen = window.open;

    beforeEach(() => {
      window.open = vi.fn();
    });

    afterEach(() => {
      window.open = originalOpen;
      vi.restoreAllMocks();
    });

    it("opens legacy path for 0.1.x forwarder", () => {
      openRemoteTerminal({
        forwarderVersion: "0.1.0",
        forwarderHostname: "localhost",
        forwarderPort: 4001,
        secure: false,
        sessionToken: "session-123",
      });

      expect(window.open).toHaveBeenCalledWith(
        `http://localhost:4001/session-123/http/${TTYD_PORT}`,
        "_blank",
      );
    });

    it("opens query-param path for 0.2.x forwarder", () => {
      openRemoteTerminal({
        forwarderVersion: "0.2.0",
        forwarderHostname: "localhost",
        forwarderPort: 4001,
        secure: true,
        sessionToken: "session-123",
      });

      expect(window.open).toHaveBeenCalledWith(
        `https://localhost:4001/?session=session-123&protocol=http&port=${TTYD_PORT}`,
        "_blank",
      );
    });

    it("throws an error for 0.3.x forwarder if token is missing", () => {
      expect(() =>
        openRemoteTerminal({
          forwarderVersion: "0.3.0",
          forwarderHostname: "localhost",
          forwarderPort: 4001,
          secure: false,
          sessionToken: "session-123",
        }),
      ).toThrow("Missing forwarder session JWT token.");
    });

    it("passes the JWT as query parameter for 0.3.x forwarder", () => {
      openRemoteTerminal({
        forwarderVersion: "0.3.0",
        forwarderHostname: "localhost",
        forwarderPort: 4001,
        secure: true,
        sessionToken: "session-123",
        token: "signed-jwt-token",
      });

      expect(window.open).toHaveBeenCalledWith(
        `https://localhost:4001/?${FORWARDER_SESSION_QUERY_PARAM}=signed-jwt-token`,
        "_blank",
      );
    });

    it("encodes the JWT in the query parameter for 0.3.x forwarder", () => {
      openRemoteTerminal({
        forwarderVersion: "0.3.0",
        forwarderHostname: "device-forwarder.edgehog.localhost",
        forwarderPort: 4001,
        secure: false,
        sessionToken: "session-123",
        token: "signed.jwt+token=/with?chars",
      });

      expect(window.open).toHaveBeenCalledWith(
        `http://device-forwarder.edgehog.localhost:4001/?${FORWARDER_SESSION_QUERY_PARAM}=signed.jwt%2Btoken%3D%2Fwith%3Fchars`,
        "_blank",
      );
    });
  });
});
