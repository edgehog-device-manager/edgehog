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

import { useCallback } from "react";
import {
  generatePath as routerGeneratePath,
  matchPath,
  useNavigate as useRouterNavigate,
} from "react-router";
import type { ParamParseKey } from "react-router";
import { Link as RouterLink } from "react-router-dom";
import type { LinkProps as RouterLinkProps } from "react-router-dom";

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
  updateChannels = "/update-channels",
  updateChannelsEdit = "/update-channels/:updateChannelId/edit",
  updateChannelsNew = "/update-channels/new",
  updateCampaigns = "/update-campaigns",
  updateCampaignsNew = "/update-campaigns/new",
  updateCampaignsEdit = "/update-campaigns/:updateCampaignId",
  applications = "/applications",
  applicationNew = "/applications/new",
  application = "/applications/:applicationId",
  release = "/applications/:applicationId/release/:releaseId",
  releaseNew = "/applications/:applicationId/release/new",
  login = "/login",
  logout = "/logout",
}

const matchPaths = (routes: Route | Route[], path: string) => {
  const r = Array.isArray(routes) ? routes : [routes];
  return r.some((route: Route) => matchPath(route, path) != null);
};

type RouteKeys = keyof typeof Route;
type RouteWithParams<T extends string> =
  T extends ParamParseKey<T>
    ? { route: T }
    : { route: T; params: { [P in ParamParseKey<T>]: string } };

type ParametricRoute = {
  [K in RouteKeys]: RouteWithParams<(typeof Route)[K]>;
}[RouteKeys];

type LinkProps = Omit<RouterLinkProps, "to"> & ParametricRoute;

const generatePath = (route: ParametricRoute): string => {
  switch (route.route) {
    case Route.devicesEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.deviceGroupsEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.systemModelsEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.hardwareTypesEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.baseImageCollectionsEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.baseImagesNew:
      return routerGeneratePath(route.route, route.params);
    case Route.baseImagesEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.updateChannelsEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.updateCampaignsEdit:
      return routerGeneratePath(route.route, route.params);
    case Route.application:
      return routerGeneratePath(route.route, route.params);
    case Route.release:
      return routerGeneratePath(route.route, route.params);
    case Route.releaseNew:
      return routerGeneratePath(route.route, route.params);

    case Route.devices:
    case Route.deviceGroups:
    case Route.deviceGroupsNew:
    case Route.systemModels:
    case Route.systemModelsNew:
    case Route.hardwareTypes:
    case Route.hardwareTypesNew:
    case Route.baseImageCollections:
    case Route.baseImageCollectionsNew:
    case Route.updateChannels:
    case Route.updateChannelsNew:
    case Route.updateCampaigns:
    case Route.updateCampaignsNew:
    case Route.login:
    case Route.logout:
    case Route.applications:
    case Route.applicationNew:
      return route.route;
  }
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

export { Link, Route, matchPaths, useNavigate };
export type { LinkProps, ParametricRoute };
