import React from "react";
import ReactDOM from "react-dom";
import { RelayEnvironmentProvider } from "react-relay/hooks";

import { relayEnvironment } from "api";
import I18nProvider from "i18n";
import App from "./App";
import "./index.scss";

ReactDOM.render(
  <React.StrictMode>
    <RelayEnvironmentProvider environment={relayEnvironment}>
      <I18nProvider>
        <App />
      </I18nProvider>
    </RelayEnvironmentProvider>
  </React.StrictMode>,
  document.getElementById("root")
);
