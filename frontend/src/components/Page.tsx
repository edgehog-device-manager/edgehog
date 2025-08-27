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

import React, { useMemo } from "react";
import Breadcrumb from "react-bootstrap/Breadcrumb";
import { FormattedMessage } from "react-intl";
import { useLocation } from "react-router-dom";

import Button from "components/Button";
import {
  Link,
  matchingParametricRoute,
  ParametricRoute,
  Route,
  routeTitles,
} from "Navigation";
import "./Page.scss";

type PageProps = {
  children?: React.ReactNode;
};

const Page = ({ children }: PageProps) => {
  return (
    <div data-testid="page" className="p-4">
      {children}
    </div>
  );
};

type PageHeaderProps = {
  children?: React.ReactNode;
  title?: React.ReactNode;
};

const PageHeader = ({ children, title }: PageHeaderProps) => {
  return (
    <header className="d-flex justify-content-between align-items-center">
      <BreadcrumbItems pageTitle={title} />
      {children}
    </header>
  );
};

type PageMainProps = {
  children?: React.ReactNode;
};

const PageMain = ({ children }: PageMainProps) => {
  return <main className="mt-4">{children}</main>;
};

type PageLoadingErrorProps = {
  onRetry?: () => void;
};

type BreadcrumbItem = {
  label: React.ReactNode;
  link?: ParametricRoute;
};

const useBreadcrumbItems = (): BreadcrumbItem[] => {
  const location = useLocation();
  const currentRoute = matchingParametricRoute(location.pathname);

  const breadcrumbRoutes: ParametricRoute[] = useMemo(() => {
    switch (currentRoute?.route) {
      case Route.devices:
      case Route.deviceGroups:
      case Route.systemModels:
      case Route.hardwareTypes:
      case Route.baseImageCollections:
      case Route.updateChannels:
      case Route.updateCampaigns:
      case Route.applications:
      case Route.imageCredentials:
      case Route.volumes:
      case Route.networks:
      case Route.deployments:
      case Route.login:
      case Route.logout:
        return [currentRoute];

      case Route.devicesEdit:
        return [{ route: Route.devices }, currentRoute];

      case Route.deviceGroupsEdit:
      case Route.deviceGroupsNew:
        return [{ route: Route.deviceGroups }, currentRoute];

      case Route.systemModelsEdit:
      case Route.systemModelsNew:
        return [{ route: Route.systemModels }, currentRoute];

      case Route.hardwareTypesEdit:
      case Route.hardwareTypesNew:
        return [{ route: Route.hardwareTypes }, currentRoute];

      case Route.baseImageCollectionsEdit:
      case Route.baseImageCollectionsNew:
        return [{ route: Route.baseImageCollections }, currentRoute];

      case Route.baseImagesEdit:
      case Route.baseImagesNew:
        return [
          { route: Route.baseImageCollections },
          {
            route: Route.baseImageCollectionsEdit,
            params: {
              baseImageCollectionId: currentRoute.params?.baseImageCollectionId,
            },
          },
          currentRoute,
        ];

      case Route.updateChannelsEdit:
      case Route.updateChannelsNew:
        return [{ route: Route.updateChannels }, currentRoute];

      case Route.updateCampaignsEdit:
      case Route.updateCampaignsNew:
        return [{ route: Route.updateCampaigns }, currentRoute];

      case Route.application:
      case Route.applicationNew:
        return [{ route: Route.applications }, currentRoute];

      case Route.release:
      case Route.releaseNew:
        return [
          { route: Route.applications },
          {
            route: Route.application,
            params: {
              applicationId: currentRoute.params?.applicationId,
            },
          },
          currentRoute,
        ];
      case Route.imageCredentialsEdit:
      case Route.imageCredentialsNew:
        return [{ route: Route.imageCredentials }, currentRoute];

      case Route.volumeEdit:
      case Route.volumesNew:
        return [{ route: Route.volumes }, currentRoute];

      case Route.networksEdit:
      case Route.networksNew:
        return [{ route: Route.networks }, currentRoute];

      default:
        return [];
    }
  }, [currentRoute]);

  const breadcrumbItems = breadcrumbRoutes.map((parametricRoute) => ({
    label: <FormattedMessage id={routeTitles[parametricRoute.route].id} />,
    link: parametricRoute,
  }));

  return breadcrumbItems;
};

type BreadcrumbItemsProps = {
  pageTitle?: React.ReactNode;
};

const BreadcrumbItems = ({ pageTitle }: BreadcrumbItemsProps) => {
  const breadcrumbItems = useBreadcrumbItems();

  return (
    <Breadcrumb>
      {breadcrumbItems.map((item, index) => {
        const isLastItem = index === breadcrumbItems.length - 1;
        const linkProps =
          item.link && !isLastItem
            ? { linkAs: Link, linkProps: item.link }
            : {};
        const active = isLastItem;
        const label = isLastItem && pageTitle ? pageTitle : item.label;

        return (
          <Breadcrumb.Item
            {...linkProps}
            key={index}
            active={active}
            className={active ? "fw-bold" : ""}
          >
            {label}
          </Breadcrumb.Item>
        );
      })}
    </Breadcrumb>
  );
};

const PageLoadingError = ({ onRetry }: PageLoadingErrorProps) => {
  return (
    <div className="d-flex flex-column">
      <FormattedMessage
        id="components.Page.loadingError.feedback"
        defaultMessage="The page couldn't load."
      />
      {onRetry && (
        <Button onClick={onRetry} className="mt-3 m-auto">
          <FormattedMessage
            id="components.Page.loadingError.retryButton"
            defaultMessage="Try Again"
          />
        </Button>
      )}
    </div>
  );
};

Page.Header = PageHeader;
Page.Main = PageMain;
Page.LoadingError = PageLoadingError;

export default Page;
