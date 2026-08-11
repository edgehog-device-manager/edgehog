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
import { FormattedMessage, useIntl } from "react-intl";
import { Card } from "react-bootstrap";

import type { HardwareInfoTab_hardwareInfo$key } from "@/api/__generated__/HardwareInfoTab_hardwareInfo.graphql";

import Form from "@/components/ui/form/Form";
import { FormRow } from "@/components/ui/form-row/FormRow";
import Stack from "@/components/ui/stack/Stack";
import { Tab } from "@/components/ui/tabs/Tabs";
import formatBytes from "@/utils/formatBytes";

const DEVICE_HARDWARE_INFO_FRAGMENT = graphql`
  fragment HardwareInfoTab_hardwareInfo on Device {
    capabilities
    hardwareInfo {
      cpuArchitecture
      cpuModel
      cpuModelName
      cpuVendor
      memoryTotalBytes
    }
  }
`;

interface DeviceHardwareInfoTabProps {
  deviceRef: HardwareInfoTab_hardwareInfo$key;
}

const DeviceHardwareInfoTab = ({ deviceRef }: DeviceHardwareInfoTabProps) => {
  const intl = useIntl();
  const { hardwareInfo, capabilities } = useFragment(
    DEVICE_HARDWARE_INFO_FRAGMENT,
    deviceRef,
  );
  if (!hardwareInfo || !capabilities.includes("HARDWARE_INFO")) {
    return null;
  }
  return (
    <Tab
      className="pt-3 d-flex flex-column flex-grow-1"
      eventKey="device-hardware-info-tab"
      title={intl.formatMessage({
        id: "components.fleet.devices.tabs.hardware-info-tab.HardwareInfoTab.title",
        defaultMessage: "Hardware Info",
      })}
    >
      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <Stack gap={3}>
          {hardwareInfo.cpuArchitecture != null && (
            <FormRow
              labelCol={3}
              valueCol={9}
              id="device-hardware-info-cpu-architecture"
              label={
                <FormattedMessage
                  id="components.fleet.devices.tabs.hardware-info-tab.HardwareInfoTab.cpuArchitecture"
                  defaultMessage="CPU architecture"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuArchitecture}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.cpuModel != null && (
            <FormRow
              labelCol={3}
              valueCol={9}
              id="device-hardware-info-cpu-model"
              label={
                <FormattedMessage
                  id="components.fleet.devices.tabs.hardware-info-tab.HardwareInfoTab.cpuModel"
                  defaultMessage="CPU model code"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuModel}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.cpuModelName != null && (
            <FormRow
              labelCol={3}
              valueCol={9}
              id="device-hardware-info-cpu-model-name"
              label={
                <FormattedMessage
                  id="components.fleet.devices.tabs.hardware-info-tab.HardwareInfoTab.cpuModelName"
                  defaultMessage="CPU model name"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuModelName}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.cpuVendor != null && (
            <FormRow
              labelCol={3}
              valueCol={9}
              id="device-hardware-info-cpu-vendor"
              label={
                <FormattedMessage
                  id="components.fleet.devices.tabs.hardware-info-tab.HardwareInfoTab.cpuVendor"
                  defaultMessage="CPU vendor"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuVendor}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.memoryTotalBytes != null && (
            <FormRow
              labelCol={3}
              valueCol={9}
              id="device-hardware-info-memory-total-bytes"
              label={
                <FormattedMessage
                  id="components.fleet.devices.tabs.hardware-info-tab.HardwareInfoTab.memoryTotalBytes"
                  defaultMessage="Total memory"
                />
              }
            >
              <Form.Control
                type="text"
                value={formatBytes(hardwareInfo.memoryTotalBytes)}
                readOnly
              />
            </FormRow>
          )}
        </Stack>
      </Card>
    </Tab>
  );
};

export default DeviceHardwareInfoTab;
