/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import _ from "lodash";
import Cookies from "js-cookie";

import type { fetchGraphQL } from "api";
import Spinner from "components/Spinner";

type AuthConfig = {
  tenantSlug: string;
  authToken: string | null;
};

// Use a lightweight query at startup to test if authentication is valid
const authQuery = `
query Auth_getSystemModels_Query {
    systemModels {
        __typename
    }
  }
`;

const AUTH_CONFIG_VERSION = 1;

function saveAuthConfig(
  authConfig?: AuthConfig | null,
  persistConfig: boolean = false
): void {
  // If expires is undefined, closing the browser/session will delete the cookie
  const cookieOptions = {
    secure: true,
    expires: persistConfig ? 365 : undefined,
  } as const;

  if (!authConfig) {
    Cookies.remove("authConfig", cookieOptions);
  } else {
    Cookies.set(
      "authConfig",
      JSON.stringify({ ...authConfig, _version: AUTH_CONFIG_VERSION }),
      cookieOptions
    );
  }
}

function loadAuthConfig(): AuthConfig | null {
  let authConfig: AuthConfig | null = null;
  try {
    authConfig = JSON.parse(Cookies.get("authConfig") || "");
  } catch {
    authConfig = null;
  }
  if (_.get(authConfig, "_version") === AUTH_CONFIG_VERSION) {
    return _.omit(authConfig, "_version");
  }
  return null;
}

type AuthContextValue = {
  isAuthenticated: boolean;
  login: (authConfig: AuthConfig, persistConfig?: boolean) => Promise<boolean>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

const hasRequiredValues = (
  authConfig?: AuthConfig | null
): authConfig is AuthConfig =>
  authConfig != null &&
  authConfig.tenantSlug != null &&
  authConfig.authToken != null;

interface AuthProviderProps {
  children: React.ReactNode;
  fetchGraphQL: typeof fetchGraphQL;
}

const AuthProvider = ({ children, fetchGraphQL }: AuthProviderProps) => {
  const [authConfig, setAuthConfig] = useState(loadAuthConfig());
  const [isValidatingInitialConfig, setIsValidatingInitialConfig] = useState(
    hasRequiredValues(authConfig)
  );

  const updateAuthConfig = useCallback(
    (newAuthConfig: AuthConfig | null, persistConfig: boolean = false) => {
      saveAuthConfig(newAuthConfig, persistConfig);
      setAuthConfig(newAuthConfig);
    },
    []
  );

  const validateAuthConfig = useCallback(
    (authConfig: AuthConfig | null): Promise<boolean> => {
      if (!hasRequiredValues(authConfig)) {
        return Promise.resolve(false);
      }
      return fetchGraphQL(authQuery, {}, authConfig)
        .then((response) => (response.errors ? false : true))
        .catch(() => false);
    },
    [fetchGraphQL]
  );

  const login = useCallback(
    async (newAuthConfig: AuthConfig, persistConfig: boolean = false) => {
      const isValid = await validateAuthConfig(newAuthConfig);
      if (isValid) {
        updateAuthConfig(newAuthConfig, persistConfig);
      }
      return isValid;
    },
    [updateAuthConfig, validateAuthConfig]
  );

  const logout = useCallback(() => {
    updateAuthConfig(null);
  }, [updateAuthConfig]);

  const isAuthenticated = useMemo(
    () => hasRequiredValues(authConfig) && !isValidatingInitialConfig,
    [authConfig, isValidatingInitialConfig]
  );

  const contextValue = useMemo(
    () => ({ isAuthenticated, login, logout }),
    [isAuthenticated, login, logout]
  );

  useEffect(() => {
    if (isValidatingInitialConfig) {
      validateAuthConfig(authConfig).then((isValid) => {
        if (!isValid) {
          updateAuthConfig(null);
          // TODO: the initial config is invalid, meaning the authToken is
          // probably expired. We could improve UX here by persisting just the
          // tenantSlug for the next login, or redirect to /login?tenanSlug=...
        }
        setIsValidatingInitialConfig(false);
      });
    }
  }, [
    authConfig,
    isValidatingInitialConfig,
    updateAuthConfig,
    validateAuthConfig,
  ]);

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

export type { AuthConfig };

export { loadAuthConfig, useAuth };

export default AuthProvider;
