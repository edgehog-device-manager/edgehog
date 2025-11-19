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

import type { BatteryTab_batteryStatus$key } from "api/__generated__/BatteryTab_batteryStatus.graphql";

import { Tab } from "components/Tabs";
import BatteryTable from "components/BatteryTable";

const DEVICE_BATTERY_STATUS_FRAGMENT = graphql`
  fragment BatteryTab_batteryStatus on Device {
    capabilities
    ...BatteryTable_batteryStatus
  }
`;

interface DeviceBatteryTabProps {
  deviceRef: BatteryTab_batteryStatus$key;
}

const DeviceBatteryTab = ({ deviceRef }: DeviceBatteryTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_BATTERY_STATUS_FRAGMENT, deviceRef);
  if (!device.capabilities.includes("BATTERY_STATUS")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-battery-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.BatteryTab",
        defaultMessage: "Battery",
      })}
    >
      <div className="mt-3">
        <BatteryTable deviceRef={device} />
      </div>
    </Tab>
  );
};

export default DeviceBatteryTab;
