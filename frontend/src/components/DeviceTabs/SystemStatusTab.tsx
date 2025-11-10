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

import { FormattedDate, FormattedMessage, useIntl } from "react-intl";
import dayjs from "dayjs";

import type { SystemStatusTab_systemStatus$key } from "api/__generated__/SystemStatusTab_systemStatus.graphql";

import Form from "components/Form";
import Stack from "components/Stack";
import { Tab } from "components/Tabs";
import { formatBytes, FormRow, FormValue } from "pages/Device";

const DEVICE_SYSTEM_STATUS_FRAGMENT = graphql`
  fragment SystemStatusTab_systemStatus on Device {
    capabilities
    systemStatus {
      memoryFreeBytes
      taskCount
      uptimeMilliseconds
      timestamp
    }
  }
`;

interface DeviceSystemStatusTabProps {
  deviceRef: SystemStatusTab_systemStatus$key;
}

const DeviceSystemStatusTab = ({ deviceRef }: DeviceSystemStatusTabProps) => {
  const intl = useIntl();
  const { systemStatus, capabilities } = useFragment(
    DEVICE_SYSTEM_STATUS_FRAGMENT,
    deviceRef,
  );
  if (!systemStatus || !capabilities.includes("SYSTEM_STATUS")) {
    return null;
  }
  return (
    <Tab
      eventKey="device-system-status-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.SystemStatusTab",
        defaultMessage: "System Status",
      })}
    >
      <div className="mt-3">
        <p className="text-muted">
          <FormattedMessage
            id="components.DeviceTabs.SystemStatusTab.lastUpdateAt"
            defaultMessage="Last updated at {date}"
            values={{
              date: (
                <FormattedDate
                  value={new Date(systemStatus.timestamp)}
                  year="numeric"
                  month="long"
                  day="numeric"
                  hour="numeric"
                  minute="numeric"
                />
              ),
            }}
          />
        </p>
        <Stack gap={3}>
          {systemStatus.memoryFreeBytes != null && (
            <FormRow
              id="device-system-status-memory-free-bytes"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.SystemStatusTab.memoryFreeBytes"
                  defaultMessage="Free Memory"
                />
              }
            >
              <Form.Control
                type="text"
                value={formatBytes(systemStatus.memoryFreeBytes)}
                readOnly
              />
            </FormRow>
          )}
          {systemStatus.taskCount != null && (
            <FormRow
              id="device-system-status-task-count"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.SystemStatusTab.taskCount"
                  defaultMessage="Active Tasks"
                />
              }
            >
              <Form.Control
                type="text"
                value={systemStatus.taskCount}
                readOnly
              />
            </FormRow>
          )}
          {systemStatus.uptimeMilliseconds != null && (
            <FormRow
              id="device-system-status-uptime"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.SystemStatusTab.uptimeMilliseconds"
                  defaultMessage="Last boot at"
                />
              }
            >
              <FormValue>
                <FormattedDate
                  value={dayjs(systemStatus.timestamp)
                    .subtract(systemStatus.uptimeMilliseconds, "millisecond")
                    .toDate()}
                  year="numeric"
                  month="long"
                  day="numeric"
                  hour="numeric"
                  minute="numeric"
                />
              </FormValue>
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

export default DeviceSystemStatusTab;
