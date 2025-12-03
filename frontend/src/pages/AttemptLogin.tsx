/*
 * This file is part of Edgehog.
 *
 * Copyright 2024, 2025 SECO Mind Srl
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

import { useEffect } from "react";
import { Spinner } from "react-bootstrap";
import { useLocation, useNavigate } from "react-router-dom";
import { commitLocalUpdate, useRelayEnvironment } from "react-relay/hooks";

import { Route } from "@/Navigation";
import type { Session } from "../contexts/Session";
import { useAuth } from "../contexts/Auth";

const AttemptLogin = () => {
  const auth = useAuth();
  const { search } = useLocation();
  const searchParams = new URLSearchParams(search);
  const tenantSlug = searchParams.get("tenantSlug") || "";
  const authToken = searchParams.get("authToken") || "";
  const redirectTo = searchParams.get("redirectTo") || "/";
  const navigate = useNavigate();
  const relayEnvironment = useRelayEnvironment();

  useEffect(() => {
    if (!tenantSlug || !authToken) {
      // Without new credentials, just go to `redirectTo` or default
      // authenticated route
      return navigate(redirectTo, { replace: true });
    }
    const session: Session = {
      tenantSlug: tenantSlug,
      authToken: authToken,
    };
    commitLocalUpdate(relayEnvironment, (store) => store.invalidateStore());
    auth
      .login(session, false)
      .then((isValidLogin) => {
        if (isValidLogin) {
          navigate(redirectTo, { replace: true });
        } else {
          // Logout if credentials were not valid
          auth.logout();
          navigate(Route.login, { replace: true });
        }
      })
      .catch(() => {
        // Logout on generic login error
        auth.logout();
        navigate(Route.login, { replace: true });
      });
  }, []);

  return (
    <div data-testid="app" className="d-flex vh-100 flex-column">
      <div className="d-flex justify-content-center">
        <Spinner />
      </div>
    </div>
  );
};

export default AttemptLogin;
