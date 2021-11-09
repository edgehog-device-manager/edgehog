/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind

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

import { Navigate, useRoutes } from "react-router-dom";

import Sidebar from "components/Sidebar";
import Topbar from "components/Topbar";
import { Route } from "Navigation";
import Device from "pages/Device";
import Devices from "pages/Devices";
import ApplianceModel from "pages/ApplianceModel";
import ApplianceModelCreate from "pages/ApplianceModelCreate";
import ApplianceModels from "pages/ApplianceModels";
import HardwareType from "pages/HardwareType";
import HardwareTypeCreate from "pages/HardwareTypeCreate";
import HardwareTypes from "pages/HardwareTypes";
import Login from "pages/Login";
import Logout from "pages/Logout";

type RouterRule = {
  path: string;
  element: JSX.Element;
};

const publicRoutes: RouterRule[] = [
  { path: Route.login, element: <Login /> },
  { path: "*", element: <Navigate to={Route.login} /> },
];

const authenticatedRoutes: RouterRule[] = [
  { path: Route.devices, element: <Devices /> },
  { path: Route.devicesEdit, element: <Device /> },
  { path: Route.applianceModels, element: <ApplianceModels /> },
  { path: Route.applianceModelsEdit, element: <ApplianceModel /> },
  { path: Route.applianceModelsNew, element: <ApplianceModelCreate /> },
  { path: Route.hardwareTypes, element: <HardwareTypes /> },
  { path: Route.hardwareTypesEdit, element: <HardwareType /> },
  { path: Route.hardwareTypesNew, element: <HardwareTypeCreate /> },
  { path: Route.logout, element: <Logout /> },
  { path: "*", element: <Navigate to={Route.devices} /> },
];

function App() {
  const isAuthenticated = true; // TODO: Implement authentication
  const routes = isAuthenticated ? authenticatedRoutes : publicRoutes;
  const RouterElement = useRoutes(routes);

  return (
    <div data-testid="app" className="d-flex vh-100 flex-column">
      {isAuthenticated && (
        <header className="flex-grow-0">
          <Topbar />
        </header>
      )}
      <main className="vh-100 flex-grow-1 d-flex  overflow-hidden">
        {isAuthenticated && (
          <aside className="flex-grow-0 flex-shrink-0 overflow-auto">
            <Sidebar />
          </aside>
        )}
        <section className="flex-grow-1 overflow-auto">{RouterElement}</section>
      </main>
    </div>
  );
}

export default App;
