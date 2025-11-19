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
import { FormattedMessage, useIntl } from "react-intl";

import type { RuntimeInfoTab_runtimeInfo$key } from "api/__generated__/RuntimeInfoTab_runtimeInfo.graphql";

import Form from "components/Form";
import Stack from "components/Stack";
import { Tab } from "components/Tabs";
import { FormRow } from "pages/Device";

const DEVICE_RUNTIME_INFO_FRAGMENT = graphql`
  fragment RuntimeInfoTab_runtimeInfo on Device {
    capabilities
    runtimeInfo {
      name
      version
      environment
      url
    }
  }
`;

interface DeviceRuntimeInfoTabProps {
  deviceRef: RuntimeInfoTab_runtimeInfo$key;
}

const DeviceRuntimeInfoTab = ({ deviceRef }: DeviceRuntimeInfoTabProps) => {
  const intl = useIntl();
  const { runtimeInfo, capabilities } = useFragment(
    DEVICE_RUNTIME_INFO_FRAGMENT,
    deviceRef,
  );
  if (
    !runtimeInfo ||
    Object.values(runtimeInfo).every((value) => value === null) ||
    !capabilities.includes("RUNTIME_INFO")
  ) {
    return null;
  }
  return (
    <Tab
      eventKey="device-runtime-info-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.RuntimeInfoTab",
        defaultMessage: "Runtime",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {runtimeInfo.name !== null && (
            <FormRow
              id="device-runtime-info-name"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.RuntimeInfoTab.name"
                  defaultMessage="Name"
                />
              }
            >
              <Form.Control type="text" value={runtimeInfo.name} readOnly />
            </FormRow>
          )}
          {runtimeInfo.version !== null && (
            <FormRow
              id="device-runtime-info-version"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.RuntimeInfoTab.version"
                  defaultMessage="Version"
                />
              }
            >
              <Form.Control type="text" value={runtimeInfo.version} readOnly />
            </FormRow>
          )}
          {runtimeInfo.environment !== null && (
            <FormRow
              id="device-runtime-info-environment"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.RuntimeInfoTab.environment"
                  defaultMessage="Environment"
                />
              }
            >
              <Form.Control
                type="text"
                value={runtimeInfo.environment}
                readOnly
              />
            </FormRow>
          )}
          {runtimeInfo.url !== null && (
            <FormRow
              id="device-runtime-info-url"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.RuntimeInfoTab.url"
                  defaultMessage="URL"
                />
              }
            >
              <Form.Control type="text" value={runtimeInfo.url} readOnly />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

export default DeviceRuntimeInfoTab;
