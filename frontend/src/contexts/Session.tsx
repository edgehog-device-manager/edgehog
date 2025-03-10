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
  authToken: string;
} | null;

const SESSION_CONFIG_VERSION = 1;

function saveSession(session: Session, persistConfig: boolean = false): void {
  // If expires is undefined, closing the browser/session will delete the cookie.
  const cookieOptions = {
    secure: window.location.protocol === "https:",
    expires: persistConfig ? 365 : undefined,
    sameSite: "strict",
  } as const;

  if (!session) {
    Cookies.remove("session", cookieOptions);
  } else {
    Cookies.set(
      "session",
      JSON.stringify({ ...session, _version: SESSION_CONFIG_VERSION }),
      cookieOptions,
    );
  }
}

const loadSession = (): Session => {
  let session: Session = null;
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

type SessionContextValue = {
  session: Session;
  updateSession: (session: Session, persist?: boolean) => void;
};

const SessionContext = createContext<SessionContextValue | null>(null);

const SessionProvider = ({ children }: { children: React.ReactNode }) => {
  const [session, setSession] = useState<Session>(() => loadSession());

  const updateSession = useCallback(
    (sessionData: Session, persist: boolean = false) => {
      saveSession(sessionData ? sessionData : null, persist);
      setSession(sessionData);
    },
    [],
  );

  return (
    <SessionContext.Provider value={{ session, updateSession }}>
      {children}
    </SessionContext.Provider>
  );
};

const useSession = () => {
  const context = useContext(SessionContext);
  if (context === null) {
    throw new Error("Session context is missing.");
  }
  return context;
};

export type { Session };
export { useSession, loadSession, saveSession };

export default SessionProvider;
