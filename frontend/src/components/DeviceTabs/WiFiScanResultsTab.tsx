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

import { graphql, useFragment } from "react-relay/hooks";
import { useIntl } from "react-intl";

import type { WiFiScanResultsTab_wifiScanResults$key } from "@/api/__generated__/WiFiScanResultsTab_wifiScanResults.graphql";

import { Tab } from "@/components/Tabs";
import WiFiScanResultsTable from "@/components/WiFiScanResultsTable";

const DEVICE_WIFI_SCAN_RESULTS_FRAGMENT = graphql`
  fragment WiFiScanResultsTab_wifiScanResults on Device {
    capabilities
    ...WiFiScanResultsTable_wifiScanResults
  }
`;

interface DeviceWiFiScanResultsTabProps {
  deviceRef: WiFiScanResultsTab_wifiScanResults$key;
}

const DeviceWiFiScanResultsTab = ({
  deviceRef,
}: DeviceWiFiScanResultsTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_WIFI_SCAN_RESULTS_FRAGMENT, deviceRef);
  if (!device.capabilities.includes("WIFI")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-wifi-scan-results-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.WiFiScanResultsTab",
        defaultMessage: "WiFi APs",
      })}
    >
      <div className="mt-3">
        <WiFiScanResultsTable deviceRef={device} />
      </div>
    </Tab>
  );
};

export default DeviceWiFiScanResultsTab;
