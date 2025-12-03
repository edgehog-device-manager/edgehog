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
import { FormattedMessage, useIntl } from "react-intl";

import type { OSInfoTab_osInfo$key } from "@/api/__generated__/OSInfoTab_osInfo.graphql";

import Form from "@/components/Form";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import { FormRow } from "@/pages/Device";

const DEVICE_OS_INFO_FRAGMENT = graphql`
  fragment OSInfoTab_osInfo on Device {
    capabilities
    osInfo {
      name
      version
    }
  }
`;

interface DeviceOSInfoTabProps {
  deviceRef: OSInfoTab_osInfo$key;
}

const DeviceOSInfoTab = ({ deviceRef }: DeviceOSInfoTabProps) => {
  const intl = useIntl();
  const { osInfo, capabilities } = useFragment(
    DEVICE_OS_INFO_FRAGMENT,
    deviceRef,
  );
  if (
    !osInfo ||
    Object.values(osInfo).every((value) => value === null) ||
    !capabilities.includes("OPERATING_SYSTEM")
  ) {
    return null;
  }
  return (
    <Tab
      eventKey="device-os-info-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.OSInfoTab",
        defaultMessage: "Operating System",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {osInfo.name !== null && (
            <FormRow
              id="device-os-info-name"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.OSInfoTab.name"
                  defaultMessage="OS name"
                />
              }
            >
              <Form.Control type="text" value={osInfo.name} readOnly />
            </FormRow>
          )}
          {osInfo.version !== null && (
            <FormRow
              id="device-os-info-version"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.OSInfoTab.version"
                  defaultMessage="OS version"
                />
              }
            >
              <Form.Control type="text" value={osInfo.version} readOnly />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

export default DeviceOSInfoTab;
