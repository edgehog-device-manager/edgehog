/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

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

import { Navigate, useRoutes } from "react-router-dom";

import Footer from "components/Footer";
import Sidebar from "components/Sidebar";
import Topbar from "components/Topbar";
import { useAuth } from "contexts/Auth";
import { Route } from "Navigation";
import Application from "pages/Application";
import ApplicationCreatePage from "pages/ApplicationCreate";
import Applications from "pages/Applications";
import AttemptLogin from "pages/AttemptLogin";
import BaseImage from "pages/BaseImage";
import BaseImageCollection from "pages/BaseImageCollection";
import BaseImageCollectionCreate from "pages/BaseImageCollectionCreate";
import BaseImageCollections from "pages/BaseImageCollections";
import BaseImageCreate from "pages/BaseImageCreate";
import Device from "pages/Device";
import DeviceGroup from "pages/DeviceGroup";
import DeviceGroupsNew from "pages/DeviceGroupCreate";
import DeviceGroups from "pages/DeviceGroups";
import Devices from "pages/Devices";
import HardwareType from "pages/HardwareType";
import HardwareTypeCreate from "pages/HardwareTypeCreate";
import HardwareTypes from "pages/HardwareTypes";
import ImageCredential from "pages/ImageCredential";
import ImageCredentialCreate from "pages/ImageCredentialCreate";
import ImageCredentials from "pages/ImageCredentials";
import Login from "pages/Login";
import Logout from "pages/Logout";
import Release from "pages/Release";
import ReleaseCreatePage from "pages/ReleaseCreate";
import SystemModel from "pages/SystemModel";
import SystemModelCreate from "pages/SystemModelCreate";
import SystemModels from "pages/SystemModels";
import UpdateCampaign from "pages/UpdateCampaign";
import UpdateCampaignCreate from "pages/UpdateCampaignCreate";
import UpdateCampaigns from "pages/UpdateCampaigns";
import UpdateChannelsEdit from "pages/UpdateChannel";
import UpdateChannelsCreate from "pages/UpdateChannelCreate";
import UpdateChannels from "pages/UpdateChannels";
import Volumes from "pages/Volumes";
import Volume from "pages/Volume";
import VolumeCreatePage from "pages/VolumeCreate";
import Networks from "pages/Networks";
import Network from "pages/Network";
import NetworkCreatePage from "pages/NetworkCreate";

import { bugs, repository, version } from "../package.json";

type RouterRule = {
  path: string;
  element: JSX.Element;
};

const publicRoutes: RouterRule[] = [
  { path: Route.login, element: <Login /> },
  { path: "*", element: <Navigate to={Route.login} replace /> },
];

const authenticatedRoutes: RouterRule[] = [
  { path: Route.login, element: <AttemptLogin /> },
  { path: Route.devices, element: <Devices /> },
  { path: Route.devicesEdit, element: <Device /> },
  { path: Route.deviceGroups, element: <DeviceGroups /> },
  { path: Route.deviceGroupsEdit, element: <DeviceGroup /> },
  { path: Route.deviceGroupsNew, element: <DeviceGroupsNew /> },
  { path: Route.systemModels, element: <SystemModels /> },
  { path: Route.systemModelsEdit, element: <SystemModel /> },
  { path: Route.systemModelsNew, element: <SystemModelCreate /> },
  { path: Route.hardwareTypes, element: <HardwareTypes /> },
  { path: Route.hardwareTypesEdit, element: <HardwareType /> },
  { path: Route.hardwareTypesNew, element: <HardwareTypeCreate /> },
  { path: Route.baseImageCollections, element: <BaseImageCollections /> },
  { path: Route.baseImageCollectionsEdit, element: <BaseImageCollection /> },
  {
    path: Route.baseImageCollectionsNew,
    element: <BaseImageCollectionCreate />,
  },
  { path: Route.baseImagesEdit, element: <BaseImage /> },
  { path: Route.baseImagesNew, element: <BaseImageCreate /> },
  { path: Route.imageCredentials, element: <ImageCredentials /> },
  { path: Route.imageCredentialsEdit, element: <ImageCredential /> },
  { path: Route.imageCredentialsNew, element: <ImageCredentialCreate /> },
  { path: Route.updateChannels, element: <UpdateChannels /> },
  { path: Route.updateChannelsEdit, element: <UpdateChannelsEdit /> },
  { path: Route.updateChannelsNew, element: <UpdateChannelsCreate /> },
  { path: Route.updateCampaigns, element: <UpdateCampaigns /> },
  { path: Route.updateCampaignsNew, element: <UpdateCampaignCreate /> },
  { path: Route.updateCampaignsEdit, element: <UpdateCampaign /> },
  { path: Route.applications, element: <Applications /> },
  { path: Route.applicationNew, element: <ApplicationCreatePage /> },
  { path: Route.application, element: <Application /> },
  { path: Route.release, element: <Release /> },
  { path: Route.releaseNew, element: <ReleaseCreatePage /> },
  { path: Route.volumes, element: <Volumes /> },
  { path: Route.volumeEdit, element: <Volume /> },
  { path: Route.volumesNew, element: <VolumeCreatePage /> },
  { path: Route.networks, element: <Networks /> },
  { path: Route.networksEdit, element: <Network /> },
  { path: Route.networksNew, element: <NetworkCreatePage /> },
  { path: Route.logout, element: <Logout /> },
  { path: "*", element: <Navigate to={Route.devices} replace /> },
];

function App() {
  const auth = useAuth();
  const routes = auth.isAuthenticated ? authenticatedRoutes : publicRoutes;
  const RouterElement = useRoutes(routes);

  return (
    <div data-testid="app" className="d-flex vh-100 flex-column">
      {auth.isAuthenticated && (
        <header className="flex-grow-0">
          <Topbar />
        </header>
      )}
      <main className="vh-100 flex-grow-1 d-flex  overflow-hidden">
        {auth.isAuthenticated && (
          <aside className="flex-grow-0 flex-shrink-0 overflow-auto">
            <Sidebar />
          </aside>
        )}
        <section className="flex-grow-1 overflow-auto">{RouterElement}</section>
      </main>
      {auth.isAuthenticated && (
        <Footer
          appName={"Edgehog Device Manager"}
          appVersion={version}
          homepageUrl={repository.url}
          repoUrl={repository.url}
          issueTrackerUrl={bugs.url}
        />
      )}
    </div>
  );
}

export default App;
