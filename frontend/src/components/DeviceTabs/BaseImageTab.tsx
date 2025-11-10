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

import type { BaseImageTab_baseImage$key } from "api/__generated__/BaseImageTab_baseImage.graphql";

import Form from "components/Form";
import Stack from "components/Stack";
import { Tab } from "components/Tabs";
import { FormRow } from "pages/Device";

const DEVICE_BASE_IMAGE_FRAGMENT = graphql`
  fragment BaseImageTab_baseImage on Device {
    capabilities
    baseImage {
      name
      version
      buildId
      fingerprint
    }
  }
`;

interface DeviceBaseImageTabProps {
  deviceRef: BaseImageTab_baseImage$key;
}

const DeviceBaseImageTab = ({ deviceRef }: DeviceBaseImageTabProps) => {
  const intl = useIntl();
  const { baseImage, capabilities } = useFragment(
    DEVICE_BASE_IMAGE_FRAGMENT,
    deviceRef,
  );
  if (
    !baseImage ||
    Object.values(baseImage).every((value) => value === null) ||
    !capabilities.includes("BASE_IMAGE")
  ) {
    return null;
  }
  return (
    <Tab
      eventKey="device-base-image-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.BaseImageTab",
        defaultMessage: "Base Image",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {baseImage.name !== null && (
            <FormRow
              id="device-base-image-name"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.BaseImageTab.name"
                  defaultMessage="Name"
                />
              }
            >
              <Form.Control type="text" value={baseImage.name} readOnly />
            </FormRow>
          )}
          {baseImage.version !== null && (
            <FormRow
              id="device-base-image-version"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.BaseImageTab.version"
                  defaultMessage="Version"
                />
              }
            >
              <Form.Control type="text" value={baseImage.version} readOnly />
            </FormRow>
          )}
          {baseImage.buildId !== null && (
            <FormRow
              id="device-base-image-buildId"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.BaseImageTab.buildId"
                  defaultMessage="Build identifier"
                />
              }
            >
              <Form.Control type="text" value={baseImage.buildId} readOnly />
            </FormRow>
          )}
          {baseImage.fingerprint !== null && (
            <FormRow
              id="device-base-image-fingerprint"
              label={
                <FormattedMessage
                  id="components.DeviceTabs.BaseImageTab.fingerprint"
                  defaultMessage="Fingerprint"
                />
              }
            >
              <Form.Control
                type="text"
                value={baseImage.fingerprint}
                readOnly
              />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

export default DeviceBaseImageTab;
