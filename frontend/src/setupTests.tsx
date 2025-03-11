/*
  This file is part of Edgehog.

  Copyright 2021-2025 SECO Mind Srl

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

import "@testing-library/jest-dom/vitest";
import React from "react";
import { vi, afterEach } from "vitest";
import { render, cleanup } from "@testing-library/react";

import {
  MemoryRouter as RouterProvider,
  Route,
  Routes,
} from "react-router-dom";
import { RelayEnvironmentProvider } from "react-relay/hooks";
import { createMockEnvironment } from "relay-test-utils";
import type { MockEnvironment } from "relay-test-utils";

import type { FetchGraphQL } from "api";
import SessionProvider from "contexts/Session";
import AuthProvider from "contexts/Auth";
import I18nProvider from "i18n";

// relay-test-utils expect to have a jest global https://github.com/facebook/relay/issues/4228
declare global {
  /* eslint-disable no-var */
  var jest: typeof vi;
}
global.jest = vi;
// runs a cleanup after each test case (e.g. clearing jsdom)
afterEach(() => {
  cleanup();
});

const fetchGraphQLMock = vi.fn().mockReturnValue(Promise.resolve({ data: {} }));

type ProvidersParams = {
  fetchGraphQL?: FetchGraphQL;
  relayEnvironment?: MockEnvironment;
  path?: string;
  route?: string;
};

const renderWithProviders = (
  ui: React.ReactElement,
  params: ProvidersParams = {},
) => {
  const {
    relayEnvironment = createMockEnvironment(),
    path = "/",
    route = "*",
    fetchGraphQL = fetchGraphQLMock,
  } = params;

  const ProvidersWrapper = (props: { children?: React.ReactNode }) => {
    return (
      <SessionProvider>
        <RelayEnvironmentProvider environment={relayEnvironment}>
          <AuthProvider fetchGraphQL={fetchGraphQL}>
            <RouterProvider initialEntries={[path]}>
              <Routes>
                <Route
                  path={route}
                  element={<I18nProvider>{props.children}</I18nProvider>}
                ></Route>
              </Routes>
            </RouterProvider>
          </AuthProvider>
        </RelayEnvironmentProvider>
      </SessionProvider>
    );
  };

  return render(ui, { wrapper: ProvidersWrapper });
};

export { renderWithProviders };
