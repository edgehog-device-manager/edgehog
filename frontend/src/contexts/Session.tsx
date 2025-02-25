/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import React, { createContext, useCallback, useContext, useState } from "react";
import Cookies from "js-cookie";
import _ from "lodash";

type Session = {
  tenantSlug: string;
  authToken: string | null;
};

const SESSION_CONFIG_VERSION = 1;

type SessionContextValue = {
  session: Session | null;
  saveSession: (session: Session | null, persist?: boolean) => void;
};

const SessionContext = createContext<SessionContextValue | undefined>(
  undefined,
);

const loadSession = (): Session | null => {
  let session: Session | null = null;
  try {
    session = JSON.parse(Cookies.get("session") || "");
  } catch {
    session = null;
  }
  if (_.get(session, "_version") === SESSION_CONFIG_VERSION) {
    return _.omit(session, "_version") as Session;
  }
  return null;
};

const SessionProvider = ({ children }: { children: React.ReactNode }) => {
  const [session, setSession] = useState<Session | null>(loadSession());

  const saveSession = useCallback(
    (sessionData: Session | null, persist: boolean = false) => {
      const cookieOptions = {
        secure: window.location.protocol === "https:",
        expires: persist ? 365 : undefined,
        sameSite: "strict",
      } as const;

      if (!sessionData) {
        Cookies.remove("session", cookieOptions);
      } else {
        Cookies.set(
          "session",
          JSON.stringify({ ...sessionData, _version: SESSION_CONFIG_VERSION }),
          cookieOptions,
        );
      }
      setSession(sessionData);
    },
    [],
  );

  return (
    <SessionContext.Provider value={{ session, saveSession }}>
      {children}
    </SessionContext.Provider>
  );
};

const useSession = () => {
  const context = useContext(SessionContext);
  if (context === undefined) {
    throw new Error("Session context is missing.");
  }
  return context;
};

export type { Session };
export { useSession, loadSession };

export default SessionProvider;
