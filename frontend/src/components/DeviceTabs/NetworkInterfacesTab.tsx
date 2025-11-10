/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { graphql, useFragment } from "react-relay/hooks";
import { useIntl } from "react-intl";

import type { NetworkInterfacesTab_networkInterfaces$key } from "api/__generated__/NetworkInterfacesTab_networkInterfaces.graphql";

import { Tab } from "components/Tabs";
import NetworkInterfacesTable from "components/NetworkInterfacesTable";

const DEVICE_NETWORK_INTERFACES__FRAGMENT = graphql`
  fragment NetworkInterfacesTab_networkInterfaces on Device {
    capabilities
    ...NetworkInterfacesTable_networkInterfaces
  }
`;

interface DeviceNetworkInterfacesTabProps {
  deviceRef: NetworkInterfacesTab_networkInterfaces$key;
}

const DeviceNetworkInterfacesTab = ({
  deviceRef,
}: DeviceNetworkInterfacesTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_NETWORK_INTERFACES__FRAGMENT, deviceRef);

  if (!device.capabilities.includes("NETWORK_INTERFACE_INFO")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-network-interfaces-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.NetworkInterfacesTab",
        defaultMessage: "Network Interfaces",
      })}
    >
      <div className="mt-3">
        <NetworkInterfacesTable deviceRef={device} />
      </div>
    </Tab>
  );
};

export default DeviceNetworkInterfacesTab;
