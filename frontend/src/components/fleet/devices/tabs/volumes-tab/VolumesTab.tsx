/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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
import { Card } from "react-bootstrap";

import type { VolumesTab_volumeDeployments$key } from "@/api/__generated__/VolumesTab_volumeDeployments.graphql";

import VolumesTable from "@/components/fleet/devices/volumes-table/VolumesTable";
import { Tab } from "@/components/ui/tabs/Tabs";

const DEVICE_VOLUMES_FRAGMENT = graphql`
  fragment VolumesTab_volumeDeployments on Device {
    capabilities
    ...VolumesTable_volumeDeployments
  }
`;

interface DeviceVolumesTabProps {
  deviceRef: VolumesTab_volumeDeployments$key;
}

const DeviceVolumesTab = ({ deviceRef }: DeviceVolumesTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_VOLUMES_FRAGMENT, deviceRef);

  if (!device.capabilities.includes("CONTAINER_MANAGEMENT")) {
    return null;
  }

  return (
    <Tab
      className="pt-3 d-flex flex-column flex-grow-1"
      eventKey="device-volumes-tab"
      title={intl.formatMessage({
        id: "components.fleet.devices.tabs.volumes-tab.VolumesTab.title",
        defaultMessage: "Volumes",
      })}
    >
      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <VolumesTable deviceRef={device} />
      </Card>
    </Tab>
  );
};

export default DeviceVolumesTab;
