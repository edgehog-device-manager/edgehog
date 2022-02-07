/*
  This file is part of Edgehog.

  Copyright 2021-2022 SECO Mind Srl

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

// jest-dom adds custom jest matchers for asserting on DOM nodes.
// allows you to do things like:
// expect(element).toHaveTextContent(/react/i)
// learn more: https://github.com/testing-library/jest-dom
import "@testing-library/jest-dom";
import React from "react";
import { render } from "@testing-library/react";
import {
  MemoryRouter as RouterProvider,
  Route,
  Routes,
} from "react-router-dom";
import { RelayEnvironmentProvider } from "react-relay/hooks";
import { createMockEnvironment, RelayMockEnvironment } from "relay-test-utils";

import type { fetchGraphQL } from "api";
import AuthProvider from "contexts/Auth";
import I18nProvider from "i18n";

const fetchGraphQLMock = jest
  .fn()
  .mockReturnValue(Promise.resolve({ data: {} }));

type ProvidersParams = {
  fetchGraphQL?: typeof fetchGraphQL;
  relayEnvironment?: RelayMockEnvironment;
  path?: string;
  route?: string;
};

const renderWithProviders = (
  ui: React.ReactElement,
  params: ProvidersParams = {}
) => {
  const {
    relayEnvironment = createMockEnvironment(),
    path = "/",
    route = "*",
    fetchGraphQL = fetchGraphQLMock,
  } = params;

  const ProvidersWrapper = (props: { children?: React.ReactNode }) => {
    return (
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
    );
  };

  const result = render(ui, { wrapper: ProvidersWrapper });

  return result;
};

export { renderWithProviders };
