/*
  This file is part of Edgehog.

  Copyright 2022-2025 SECO Mind Srl

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

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import { useSession, Session } from "contexts/Session";
import type { FetchGraphQL } from "api";
import Spinner from "components/Spinner";

// Use a lightweight query at startup to test if authentication is valid
const authQuery = `
  query Auth_getTenantInfo_Query {
    tenantInfo {
      __typename
    }
  }
`;

type AuthContextValue = {
  isAuthenticated: boolean;
  login: (session: Session, persistConfig?: boolean) => Promise<boolean>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

const hasRequiredValues = (session: Session): boolean => session !== null;

interface AuthProviderProps {
  children: React.ReactNode;
  fetchGraphQL: FetchGraphQL;
}

const AuthProvider = ({ children, fetchGraphQL }: AuthProviderProps) => {
  const { session, updateSession } = useSession();
  const [isValidatingInitialConfig, setIsValidatingInitialConfig] = useState(
    hasRequiredValues(session),
  );

  const validateSession = useCallback(
    (session: Session): Promise<boolean> => {
      if (!hasRequiredValues(session)) {
        return Promise.resolve(false);
      }
      return fetchGraphQL(
        authQuery,
        {},
        session!.tenantSlug,
        session!.authToken,
      )
        .then((response) => (response.errors ? false : true))
        .catch(() => false);
    },
    [fetchGraphQL],
  );

  const login = useCallback(
    async (newSession: Session, persistConfig: boolean = false) => {
      const isValid = await validateSession(newSession);
      if (isValid) {
        updateSession(newSession, persistConfig);
      }
      return isValid;
    },
    [updateSession, validateSession],
  );

  const logout = useCallback(() => {
    updateSession(null);
  }, [updateSession]);

  const isAuthenticated = useMemo(
    () => hasRequiredValues(session) && !isValidatingInitialConfig,
    [session, isValidatingInitialConfig],
  );

  const contextValue = useMemo(
    () => ({ isAuthenticated, login, logout }),
    [isAuthenticated, login, logout],
  );

  useEffect(() => {
    let mounted = true;
    if (isValidatingInitialConfig) {
      validateSession(session).then((isValid) => {
        if (!mounted) {
          return;
        }
        if (!isValid) {
          updateSession(null);
        }
        setIsValidatingInitialConfig(false);
      });
    }
    return () => {
      mounted = false;
    };
  }, [session, isValidatingInitialConfig, updateSession, validateSession]);

  if (isValidatingInitialConfig) {
    return (
      <div
        className="vh-100 d-flex justify-content-center align-items-center"
        data-testid="initial-auth-check"
      >
        <Spinner />
      </div>
    );
  }
  return (
    <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>
  );
};

const useAuth = (): AuthContextValue => {
  const contextValue = useContext(AuthContext);
  if (contextValue == null) {
    throw new Error("AuthContext has not been Provided");
  }
  return contextValue;
};

export { useAuth };
export default AuthProvider;
