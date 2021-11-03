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
import {
  createMockEnvironment,
  RelayMockEnvironment,
  MockPayloadGenerator,
} from "relay-test-utils";

import I18nProvider from "i18n";

type ProvidersParams = {
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
  } = params;

  const ProvidersWrapper = (props: { children?: React.ReactNode }) => {
    return (
      <RelayEnvironmentProvider environment={relayEnvironment}>
        <RouterProvider initialEntries={[path]}>
          <Routes>
            <Route
              path={route}
              element={<I18nProvider>{props.children}</I18nProvider>}
            ></Route>
          </Routes>
        </RouterProvider>
      </RelayEnvironmentProvider>
    );
  };

  const result = render(ui, { wrapper: ProvidersWrapper });

  return result;
};

const relayMockResolvers: MockPayloadGenerator.MockResolvers = {};

export { relayMockResolvers, renderWithProviders };
