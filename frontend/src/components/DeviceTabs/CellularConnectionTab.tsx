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

import type { CellularConnectionTab_cellularConnection$key } from "api/__generated__/CellularConnectionTab_cellularConnection.graphql";

import CellularConnectionTabs from "components/CellularConnectionTabs";
import { Tab } from "components/Tabs";

const DEVICE_CELLULAR_CONNECTION_FRAGMENT = graphql`
  fragment CellularConnectionTab_cellularConnection on Device {
    capabilities
    ...CellularConnectionTabs_cellularConnection
  }
`;

interface DeviceCellularConnectionTabProps {
  deviceRef: CellularConnectionTab_cellularConnection$key;
}

const DeviceCellularConnectionTab = ({
  deviceRef,
}: DeviceCellularConnectionTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_CELLULAR_CONNECTION_FRAGMENT, deviceRef);

  if (!device.capabilities.includes("CELLULAR_CONNECTION")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-cellular-connection-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.CellularConnectionTab",
        defaultMessage: "Cellular Connection",
      })}
    >
      <div className="mt-3">
        <CellularConnectionTabs deviceRef={device} />
      </div>
    </Tab>
  );
};

export default DeviceCellularConnectionTab;
