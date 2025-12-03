/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import React, { useCallback, useEffect, useState, useMemo } from "react";
import { graphql, useRefetchableFragment } from "react-relay/hooks";
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
      systemModel {
        name
      }
      ...DeployedApplicationsTable_deployedApplications
    }
  }
`;

interface DeviceApplicationsTabProps {
  deviceRef: ApplicationsTab_deployedApplications$key;
}

const DeviceApplicationsTab = ({ deviceRef }: DeviceApplicationsTabProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const intl = useIntl();

  const [{ device }, refetch] = useRefetchableFragment<
    ApplicationsTab_deployedApplications_RefetchQuery,
    ApplicationsTab_deployedApplications$key
  >(DEVICE_DEPLOYED_APPLICATIONS_FRAGMENT, deviceRef);

  const isOnline = useMemo(() => device?.online ?? false, [device]);

  const handleRefetch = useCallback(() => {
    refetch({ id: device?.id }, { fetchPolicy: "store-and-network" });
  }, [refetch, device?.id]);

  useEffect(() => {
    const intervalId = setInterval(handleRefetch, 5000);
    return () => {
      clearInterval(intervalId);
    };
  }, [handleRefetch]);

  if (!device) {
    return null;
  }

  return (
    <Tab
      eventKey="applications-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.ApplicationsTab",
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
            defaultMessage="Add Available Applications"
          />
        </h5>
        <AddAvailableApplications
          deviceId={device.id}
          systemModelName={device.systemModel?.name}
          isOnline={isOnline}
          setErrorFeedback={setErrorFeedback}
          onDeployComplete={handleRefetch}
        />
        <h5 className="mt-4">
          <FormattedMessage
            id="components.DeviceTabs.ApplicationsTab.DeployedApplications"
            defaultMessage="Deployed Applications"
          />
        </h5>
        <DeployedApplicationsTable
          deviceRef={device}
          isOnline={isOnline}
          systemModelName={device.systemModel?.name}
          setErrorFeedback={setErrorFeedback}
          onDeploymentChange={handleRefetch}
        />
      </div>
    </Tab>
  );
};

export default DeviceApplicationsTab;
