// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { graphql, useFragment } from "react-relay/hooks";
import { useIntl } from "react-intl";
import { Card } from "react-bootstrap";

import type { StorageUsageTab_storageUsage$key } from "@/api/__generated__/StorageUsageTab_storageUsage.graphql";

import StorageTable from "@/components/StorageTable";
import { Tab } from "@/components/Tabs";

const DEVICE_STORAGE_USAGE_FRAGMENT = graphql`
  fragment StorageUsageTab_storageUsage on Device {
    capabilities
    ...StorageTable_storageUsage
  }
`;

interface DeviceStorageUsageTabProps {
  deviceRef: StorageUsageTab_storageUsage$key;
}

const DeviceStorageUsageTab = ({ deviceRef }: DeviceStorageUsageTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_STORAGE_USAGE_FRAGMENT, deviceRef);
  if (!device.capabilities.includes("STORAGE")) {
    return null;
  }
  return (
    <Tab
      className="pt-3 d-flex flex-column flex-grow-1"
      eventKey="device-storage-usage-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.StorageUsageTab.title",
        defaultMessage: "Storage",
      })}
    >
      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <StorageTable deviceRef={device} />
      </Card>
    </Tab>
  );
};

export default DeviceStorageUsageTab;
