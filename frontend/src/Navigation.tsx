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

import { useCallback } from "react";
import type { MessageDescriptor } from "react-intl";
import { defineMessages } from "react-intl";
import type { ParamParseKey } from "react-router";
import {
  matchPath,
  generatePath as routerGeneratePath,
  useNavigate as useRouterNavigate,
} from "react-router";
import type { LinkProps as RouterLinkProps } from "react-router-dom";
import { Link as RouterLink } from "react-router-dom";

enum Route {
  devices = "/devices",
  devicesEdit = "/devices/:deviceId/edit",
  deviceGroups = "/device-groups",
  deviceGroupsEdit = "/device-groups/:deviceGroupId/edit",
  deviceGroupsNew = "/device-groups/new",
  systemModels = "/system-models",
  systemModelsNew = "/system-models/new",
  systemModelsEdit = "/system-models/:systemModelId/edit",
  hardwareTypes = "/hardware-types",
  hardwareTypesNew = "/hardware-types/new",
  hardwareTypesEdit = "/hardware-types/:hardwareTypeId/edit",
  baseImageCollections = "/base-image-collections",
  baseImageCollectionsNew = "/base-image-collections/new",
  baseImageCollectionsEdit = "/base-image-collections/:baseImageCollectionId/edit",
  baseImagesNew = "/base-image-collections/:baseImageCollectionId/base-images/new",
  baseImagesEdit = "/base-image-collections/:baseImageCollectionId/base-images/:baseImageId/edit",
  channels = "/channels",
  channelsEdit = "/channels/:channelId/edit",
  channelsNew = "/channels/new",
  updateCampaigns = "/update-campaigns",
  updateCampaignsNew = "/update-campaigns/new",
  updateCampaignsEdit = "/update-campaigns/:updateCampaignId",
  applications = "/applications",
  applicationNew = "/applications/new",
  application = "/applications/:applicationId",
  release = "/applications/:applicationId/release/:releaseId",
  releaseNew = "/applications/:applicationId/release/new",
  imageCredentials = "/image-credentials",
  imageCredentialsEdit = "/image-credentials/:imageCredentialId/edit",
  imageCredentialsNew = "/image-credentials/new",
  volumes = "/volumes",
  volumeEdit = "/volumes/:volumeId",
  volumesNew = "/volumes/new",
  networks = "/networks",
  networksEdit = "/networks/:networkId",
  networksNew = "/networks/new",
  deployments = "/deployments",
  deploymentEdit = "/devices/:deviceId/deployment/:deploymentId",
  deploymentCampaigns = "/deployment-campaigns",
  deploymentCampaignsNew = "/deployment-campaigns/new",
  deploymentCampaignsEdit = "/deployment-campaigns/:deploymentCampaignId",
  login = "/login",
  logout = "/logout",
}

const matchPaths = (routes: Route | Route[], path: string) => {
  const r = Array.isArray(routes) ? routes : [routes];
  return r.some((route: Route) => matchPath(route, path) != null);
};

const matchingRoute = (path: string) => {
  return Object.values(Route).find((route) => matchPath(route, path) != null);
};

type RouteKeys = keyof typeof Route;
type RouteWithParams<T extends string> =
  T extends ParamParseKey<T>
    ? { route: T }
    : { route: T; params: { [P in ParamParseKey<T>]: string } };

type ParametricRoute = {
  [K in RouteKeys]: RouteWithParams<(typeof Route)[K]>;
}[RouteKeys];

const matchingParametricRoute = (
  path: string,
): ParametricRoute | null | undefined => {
  const route = matchingRoute(path);
  if (!route) {
    return null;
  }

  const params = matchPath(route, path)?.params;
  switch (route) {
    case Route.devices:
    case Route.deviceGroups:
    case Route.deviceGroupsNew:
    case Route.systemModels:
    case Route.systemModelsNew:
    case Route.hardwareTypes:
    case Route.hardwareTypesNew:
    case Route.baseImageCollections:
    case Route.baseImageCollectionsNew:
    case Route.channels:
    case Route.channelsNew:
    case Route.updateCampaigns:
    case Route.updateCampaignsNew:
    case Route.applications:
    case Route.applicationNew:
    case Route.imageCredentials:
    case Route.imageCredentialsNew:
    case Route.volumes:
    case Route.volumesNew:
    case Route.networks:
    case Route.networksNew:
    case Route.deployments:
    case Route.deploymentCampaigns:
    case Route.deploymentCampaignsNew:
    case Route.login:
    case Route.logout:
      return { route } as ParametricRoute;

    case Route.devicesEdit:
      return params && typeof params["deviceId"] === "string"
        ? {
            route,
            params: { deviceId: params.deviceId },
          }
        : null;
    case Route.deploymentEdit:
      return params &&
        typeof params["deploymentId"] === "string" &&
        typeof params["deviceId"] === "string"
        ? {
            route,
            params: {
              deploymentId: params.deploymentId,
              deviceId: params.deviceId,
            },
          }
        : null;

    case Route.deviceGroupsEdit:
      return params && typeof params["deviceGroupId"] === "string"
        ? {
            route,
            params: { deviceGroupId: params.deviceGroupId },
          }
        : null;

    case Route.systemModelsEdit:
      return params && typeof params["systemModelId"] === "string"
        ? {
            route,
            params: { systemModelId: params.systemModelId },
          }
        : null;

    case Route.hardwareTypesEdit:
      return params && typeof params["hardwareTypeId"] === "string"
        ? {
            route,
            params: { hardwareTypeId: params.hardwareTypeId },
          }
        : null;

    case Route.baseImagesNew:
      return params && typeof params["baseImageCollectionId"] === "string"
        ? {
            route,
            params: { baseImageCollectionId: params.baseImageCollectionId },
          }
        : null;

    case Route.baseImageCollectionsEdit:
      return params && typeof params["baseImageCollectionId"] === "string"
        ? {
            route,
            params: { baseImageCollectionId: params.baseImageCollectionId },
          }
        : null;

    case Route.baseImagesEdit:
      return params &&
        typeof params["baseImageCollectionId"] === "string" &&
        typeof params["baseImageId"] === "string"
        ? {
            route,
            params: {
              baseImageCollectionId: params.baseImageCollectionId,
              baseImageId: params.baseImageId,
            },
          }
        : null;

    case Route.channelsEdit:
      return params && typeof params["channelId"] === "string"
        ? {
            route,
            params: { channelId: params.channelId },
          }
        : null;

    case Route.updateCampaignsEdit:
      return params && typeof params["updateCampaignId"] === "string"
        ? {
            route,
            params: { updateCampaignId: params.updateCampaignId },
          }
        : null;

    case Route.application:
      return params && typeof params["applicationId"] === "string"
        ? {
            route,
            params: { applicationId: params.applicationId },
          }
        : null;

    case Route.release:
      return params &&
        typeof params["applicationId"] === "string" &&
        typeof params["releaseId"] === "string"
        ? {
            route,
            params: {
              applicationId: params.applicationId,
              releaseId: params.releaseId,
            },
          }
        : null;

    case Route.releaseNew:
      return params && typeof params["applicationId"] === "string"
        ? {
            route,
            params: {
              applicationId: params.applicationId,
            },
          }
        : null;
    case Route.imageCredentialsEdit:
      return params && typeof params["imageCredentialId"] === "string"
        ? {
            route,
            params: { imageCredentialId: params.imageCredentialId },
          }
        : null;
    case Route.volumeEdit:
      return params && typeof params["volumeId"] === "string"
        ? {
            route,
            params: { volumeId: params.volumeId },
          }
        : null;

    case Route.networksEdit:
      return params && typeof params["networkId"] === "string"
        ? {
            route,
            params: { networkId: params.networkId },
          }
        : null;
    case Route.deploymentCampaignsEdit:
      return params && typeof params["deploymentCampaignId"] === "string"
        ? {
            route,
            params: { deploymentCampaignId: params.deploymentCampaignId },
          }
        : null;
  }
};

type LinkProps = Omit<RouterLinkProps, "to"> & ParametricRoute;

type RouteParams<Path extends string> = Parameters<
  typeof routerGeneratePath<Path>
>[1];

const generatePath = (route: ParametricRoute): string => {
  if ("params" in route && route.params) {
    return routerGeneratePath(
      route.route,
      route.params as RouteParams<typeof route.route>,
    );
  }
  return route.route;
};

const Link = (props: LinkProps) => {
  const to = generatePath(props);
  const forwardProps =
    "params" in props
      ? (({ route: _route, params: _params, ...rest }) => rest)(props)
      : (({ route: _route, ...rest }) => rest)(props);

  return <RouterLink to={to} {...forwardProps} />;
};

const useNavigate = () => {
  const routerNavigate = useRouterNavigate();
  const navigate = useCallback(
    (route: ParametricRoute | `${Route}`) => {
      const path = typeof route === "string" ? route : generatePath(route);
      routerNavigate(path);
    },
    [routerNavigate],
  );
  return navigate;
};

const routeTitles: Record<Route, MessageDescriptor> = defineMessages({
  [Route.devices]: {
    id: "navigation.routeTitle.Devices",
    defaultMessage: "Devices",
  },
  [Route.devicesEdit]: {
    id: "navigation.routeTitle.DevicesEdit",
    defaultMessage: "Device Details",
  },
  [Route.deploymentEdit]: {
    id: "navigation.routeTitle.DeploymentEdit",
    defaultMessage: "Deployment Details",
  },
  [Route.deviceGroups]: {
    id: "navigation.routeTitle.DeviceGroups",
    defaultMessage: "Groups",
  },
  [Route.deviceGroupsEdit]: {
    id: "navigation.routeTitle.DeviceGroupsEdit",
    defaultMessage: "Group Details",
  },
  [Route.deviceGroupsNew]: {
    id: "navigation.routeTitle.DeviceGroupsNew",
    defaultMessage: "Create Group",
  },
  [Route.systemModels]: {
    id: "navigation.routeTitle.SystemModels",
    defaultMessage: "System Models",
  },
  [Route.systemModelsNew]: {
    id: "navigation.routeTitle.SystemModelsNew",
    defaultMessage: "Create System Model",
  },
  [Route.systemModelsEdit]: {
    id: "navigation.routeTitle.SystemModelsEdit",
    defaultMessage: "System Model Details",
  },
  [Route.hardwareTypes]: {
    id: "navigation.routeTitle.HardwareTypes",
    defaultMessage: "Hardware Types",
  },
  [Route.hardwareTypesNew]: {
    id: "navigation.routeTitle.HardwareTypesNew",
    defaultMessage: "Create Hardware Type",
  },
  [Route.hardwareTypesEdit]: {
    id: "navigation.routeTitle.HardwareTypesEdit",
    defaultMessage: "Hardware Type Details",
  },
  [Route.baseImageCollections]: {
    id: "navigation.routeTitle.BaseImageCollections",
    defaultMessage: "Base Image Collections",
  },
  [Route.baseImageCollectionsNew]: {
    id: "navigation.routeTitle.BaseImageCollectionsNew",
    defaultMessage: "Create Base Image Collection",
  },
  [Route.baseImageCollectionsEdit]: {
    id: "navigation.routeTitle.BaseImageCollectionsEdit",
    defaultMessage: "Base Image Collection Details",
  },
  [Route.baseImagesNew]: {
    id: "navigation.routeTitle.BaseImagesNew",
    defaultMessage: "Create Base Image",
  },
  [Route.baseImagesEdit]: {
    id: "navigation.routeTitle.BaseImagesEdit",
    defaultMessage: "Base Image Details",
  },
  [Route.channels]: {
    id: "navigation.routeTitle.Channels",
    defaultMessage: "Channels",
  },
  [Route.channelsNew]: {
    id: "navigation.routeTitle.ChannelsNew",
    defaultMessage: "Create Channel",
  },
  [Route.channelsEdit]: {
    id: "navigation.routeTitle.ChannelsEdit",
    defaultMessage: "Channel Details",
  },
  [Route.updateCampaigns]: {
    id: "navigation.routeTitle.UpdateCampaigns",
    defaultMessage: "Update Campaigns",
  },
  [Route.updateCampaignsNew]: {
    id: "navigation.routeTitle.UpdateCampaignsNew",
    defaultMessage: "Create Update Campaign",
  },
  [Route.updateCampaignsEdit]: {
    id: "navigation.routeTitle.UpdateCampaignsEdit",
    defaultMessage: "Update Campaign Details",
  },
  [Route.applications]: {
    id: "navigation.routeTitle.Applications",
    defaultMessage: "Applications",
  },
  [Route.applicationNew]: {
    id: "navigation.routeTitle.ApplicationNew",
    defaultMessage: "Create Application",
  },
  [Route.application]: {
    id: "navigation.routeTitle.Application",
    defaultMessage: "Application",
  },
  [Route.release]: {
    id: "navigation.routeTitle.Release",
    defaultMessage: "Release",
  },
  [Route.releaseNew]: {
    id: "navigation.routeTitle.ReleaseNew",
    defaultMessage: "Create Release",
  },
  [Route.imageCredentials]: {
    id: "navigation.routeTitle.ImageCredentials",
    defaultMessage: "Image Credentials",
  },
  [Route.imageCredentialsNew]: {
    id: "navigation.routeTitle.ImageCredentialNew",
    defaultMessage: "Create Image Credentials",
  },
  [Route.imageCredentialsEdit]: {
    id: "navigation.routeTitle.ImageCredentialEdit",
    defaultMessage: "Image Credentials Details",
  },
  [Route.login]: {
    id: "navigation.routeTitle.Login",
    defaultMessage: "Login",
  },
  [Route.logout]: {
    id: "navigation.routeTitle.Logout",
    defaultMessage: "Logout",
  },
  [Route.volumes]: {
    id: "navigation.routeTitle.Volumes",
    defaultMessage: "Volumes",
  },
  [Route.volumeEdit]: {
    id: "navigation.routeTitle.VolumeEdit",
    defaultMessage: "Volume Details",
  },
  [Route.volumesNew]: {
    id: "navigation.routeTitle.VolumesNew",
    defaultMessage: "Create Volumes",
  },
  [Route.networks]: {
    id: "navigation.routeTitle.Networks",
    defaultMessage: "Networks",
  },
  [Route.networksEdit]: {
    id: "navigation.routeTitle.NetworksEdit",
    defaultMessage: "Network Details",
  },
  [Route.networksNew]: {
    id: "navigation.routeTitle.NetworksNew",
    defaultMessage: "Create Networks",
  },
  [Route.deployments]: {
    id: "navigation.routeTitle.Deployments",
    defaultMessage: "Deployments",
  },
  [Route.deploymentCampaigns]: {
    id: "navigation.routeTitle.DeploymentCampaigns",
    defaultMessage: "Campaigns",
  },
  [Route.deploymentCampaignsNew]: {
    id: "navigation.routeTitle.DeploymentCampaignsNew",
    defaultMessage: "Create Campaign",
  },
  [Route.deploymentCampaignsEdit]: {
    id: "navigation.routeTitle.DeploymentCampaignsEdit",
    defaultMessage: "Edit Campaign",
  },
});

export {
  Link,
  matchingParametricRoute,
  matchingRoute,
  matchPaths,
  Route,
  routeTitles,
  useNavigate,
};
export type { LinkProps, ParametricRoute };
