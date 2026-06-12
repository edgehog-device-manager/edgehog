/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useMemo } from "react";
import {
  ConnectionHandler,
  graphql,
  useRefetchableFragment,
  useSubscription,
} from "react-relay/hooks";
import { FormattedMessage, useIntl } from "react-intl";

import type { ApplicationsTab_deployedApplications$key } from "@/api/__generated__/ApplicationsTab_deployedApplications.graphql";
import type { ApplicationsTab_deployedApplications_RefetchQuery } from "@/api/__generated__/ApplicationsTab_deployedApplications_RefetchQuery.graphql";

import AddAvailableApplications from "@/components/AddAvailableApplications";
import DeployedApplicationsTable from "@/components/DeployedApplicationsTable";
import Alert from "@/components/Alert";
import { Tab } from "@/components/Tabs";

// TODO: the fragment is defined on the RootQueryType so it can specify
// which query to run, otherwise Relay would automatically use the `node`
// query when refetching the fragment. However, the backend doesn't currently
// support loading relationships (the device's deployments) through the `node`
// query.
// See also: https://github.com/ash-project/ash_graphql/issues/99
const DEVICE_DEPLOYED_APPLICATIONS_FRAGMENT = graphql`
  fragment ApplicationsTab_deployedApplications on RootQueryType
  @refetchable(queryName: "ApplicationsTab_deployedApplications_RefetchQuery") {
    device(id: $id) {
      id
      online
      capabilities
      systemModel {
        name
      }
      ...DeployedApplicationsTable_deployedApplications
    }
  }
`;

const APPLICATION_DEPLOYMENT_UPDATED_SUBSCRIPTION = graphql`
  subscription ApplicationsTab_deploymentsUpdated_Subscription($deviceId: ID!) {
    deploymentsByDevice(deviceId: $deviceId) {
      updated {
        id
        state
      }
    }
  }
`;

const APPLICATION_DEPLOYMENT_CREATED_SUBSCRIPTION = graphql`
  subscription ApplicationsTab_deploymentsCreated_Subscription($deviceId: ID!) {
    deploymentsByDevice(deviceId: $deviceId) {
      created {
        id
        state
      }
    }
  }
`;

interface DeviceApplicationsTabProps {
  deviceRef: ApplicationsTab_deployedApplications$key;
}

const DeviceApplicationsTab = ({ deviceRef }: DeviceApplicationsTabProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const intl = useIntl();

  const [{ device }] = useRefetchableFragment<
    ApplicationsTab_deployedApplications_RefetchQuery,
    ApplicationsTab_deployedApplications$key
  >(DEVICE_DEPLOYED_APPLICATIONS_FRAGMENT, deviceRef);

  const deviceId = device?.id || "";

  useSubscription(
    useMemo(
      () => ({
        subscription: APPLICATION_DEPLOYMENT_UPDATED_SUBSCRIPTION,
        variables: { deviceId },
      }),
      [deviceId],
    ),
  );

  useSubscription(
    useMemo(
      () => ({
        subscription: APPLICATION_DEPLOYMENT_CREATED_SUBSCRIPTION,
        variables: {
          deviceId,
        },
        updater: (store) => {
          const deploymentsByDevice = store.getRootField("deploymentsByDevice");

          const newDeployment = deploymentsByDevice?.getLinkedRecord("created");

          if (!newDeployment) {
            return;
          }

          const device = store.get(deviceId);

          if (!device) {
            return;
          }

          const connection = ConnectionHandler.getConnection(
            device,
            "DeployedApplicationsTable_applicationDeployments",
          );

          if (!connection) {
            return;
          }

          const newDeploymentId = newDeployment.getDataID();

          const alreadyPresent = (
            connection.getLinkedRecords("edges") ?? []
          ).some(
            (edge) =>
              edge.getLinkedRecord("node")?.getDataID() === newDeploymentId,
          );

          if (alreadyPresent) {
            return;
          }

          const edge = ConnectionHandler.createEdge(
            store,
            connection,
            newDeployment,
            "DeploymentEdge",
          );

          ConnectionHandler.insertEdgeBefore(connection, edge);
        },
      }),
      [deviceId],
    ),
  );

  const isOnline = useMemo(() => device?.online ?? false, [device]);

  if (!device || !device.capabilities.includes("CONTAINER_MANAGEMENT")) {
    return null;
  }

  return (
    <Tab
      eventKey="applications-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.ApplicationsTab.title",
        defaultMessage: "Applications",
      })}
    >
      <Alert
        className="mt-3"
        show={!!errorFeedback}
        variant="danger"
        onClose={() => setErrorFeedback(null)}
        dismissible
      >
        {errorFeedback}
      </Alert>
      <div className="mt-3">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.ApplicationsTab.InstallNewApp"
            defaultMessage="Install Applications"
          />
        </h5>
        <AddAvailableApplications
          deviceId={device.id}
          systemModelName={device.systemModel?.name}
          isOnline={isOnline}
          setErrorFeedback={setErrorFeedback}
        />
        <h5 className="mt-4">
          <FormattedMessage
            id="components.DeviceTabs.ApplicationsTab.DeployedApplications"
            defaultMessage="Deployed Applications"
          />
        </h5>
        <DeployedApplicationsTable deviceRef={device} />
      </div>
    </Tab>
  );
};

export default DeviceApplicationsTab;
