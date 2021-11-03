import React from "react";
import ReactDOM from "react-dom";
import { RelayEnvironmentProvider } from "react-relay/hooks";
import { BrowserRouter as RouterProvider } from "react-router-dom";

import { relayEnvironment } from "api";
import I18nProvider from "i18n";
import App from "./App";
import "./index.scss";

ReactDOM.render(
  <React.StrictMode>
    <RelayEnvironmentProvider environment={relayEnvironment}>
      <RouterProvider>
        <I18nProvider>
          <App />
        </I18nProvider>
      </RouterProvider>
    </RelayEnvironmentProvider>
  </React.StrictMode>,
  document.getElementById("root")
);
