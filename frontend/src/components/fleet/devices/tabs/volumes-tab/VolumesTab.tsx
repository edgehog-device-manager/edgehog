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

import { useMemo } from "react";
import { graphql, useFragment, useSubscription } from "react-relay/hooks";
import { ConnectionHandler } from "relay-runtime";
import { useIntl } from "react-intl";
import { Card } from "react-bootstrap";

import type { VolumesTab_volumeDeployments$key } from "@/api/__generated__/VolumesTab_volumeDeployments.graphql";

import VolumesTable from "@/components/fleet/devices/volumes-table/VolumesTable";
import { Tab } from "@/components/ui/tabs/Tabs";

const DEVICE_VOLUMES_FRAGMENT = graphql`
  fragment VolumesTab_volumeDeployments on Device {
    id
    capabilities
    ...VolumesTable_volumeDeployments
  }
`;

const VOLUME_DEPLOYMENT_UPDATED_SUBSCRIPTION = graphql`
  subscription VolumesTab_volumeDeploymentsUpdated_Subscription(
    $deviceId: ID!
  ) {
    volumeDeploymentsByDevice(deviceId: $deviceId) {
      updated {
        id
        state
        isReady
      }
    }
  }
`;

const VOLUME_DEPLOYMENT_CREATED_SUBSCRIPTION = graphql`
  subscription VolumesTab_volumeDeploymentsCreated_Subscription(
    $deviceId: ID!
  ) {
    volumeDeploymentsByDevice(deviceId: $deviceId) {
      created {
        id
        state
        isReady
        volume {
          id
          label
          driver
          containerVolumes {
            edges {
              node {
                id
                target
                container {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }
  }
`;

const VOLUME_DEPLOYMENT_DESTROYED_SUBSCRIPTION = graphql`
  subscription VolumesTab_volumeDeploymentsDestroyed_Subscription(
    $deviceId: ID!
  ) {
    volumeDeploymentsByDevice(deviceId: $deviceId) {
      destroyed
    }
  }
`;

interface DeviceVolumesTabProps {
  deviceRef: VolumesTab_volumeDeployments$key;
}

const DeviceVolumesTab = ({ deviceRef }: DeviceVolumesTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_VOLUMES_FRAGMENT, deviceRef);
  const deviceId = device?.id || "";

  useSubscription(
    useMemo(
      () => ({
        subscription: VOLUME_DEPLOYMENT_UPDATED_SUBSCRIPTION,
        variables: { deviceId },
      }),
      [deviceId],
    ),
  );

  useSubscription(
    useMemo(
      () => ({
        subscription: VOLUME_DEPLOYMENT_CREATED_SUBSCRIPTION,
        variables: { deviceId },
        updater: (store) => {
          const payload = store.getRootField("volumeDeploymentsByDevice");
          const newVolumeDeployment = payload?.getLinkedRecord("created");

          if (!newVolumeDeployment) {
            return;
          }

          const deviceRecord = store.get(deviceId);
          if (!deviceRecord) {
            return;
          }

          const connection = ConnectionHandler.getConnection(
            deviceRecord,
            "VolumesTable_volumeDeployments",
          );

          if (!connection) {
            return;
          }

          const newVolumeDeploymentId = newVolumeDeployment.getDataID();

          const alreadyPresent = (
            connection.getLinkedRecords("edges") ?? []
          ).some(
            (edge) =>
              edge.getLinkedRecord("node")?.getDataID() ===
              newVolumeDeploymentId,
          );

          if (alreadyPresent) {
            return;
          }

          const edge = ConnectionHandler.createEdge(
            store,
            connection,
            newVolumeDeployment,
            "VolumeDeploymentEdge",
          );

          ConnectionHandler.insertEdgeBefore(connection, edge);
        },
      }),
      [deviceId],
    ),
  );

  useSubscription(
    useMemo(
      () => ({
        subscription: VOLUME_DEPLOYMENT_DESTROYED_SUBSCRIPTION,
        variables: { deviceId },
        updater: (store) => {
          const payload = store.getRootField("volumeDeploymentsByDevice");
          const destroyedId = payload?.getValue("destroyed");
          if (!destroyedId || typeof destroyedId !== "string") {
            return;
          }

          const deviceRecord = store.get(deviceId);
          if (!deviceRecord) {
            return;
          }

          const connection = ConnectionHandler.getConnection(
            deviceRecord,
            "VolumesTable_volumeDeployments",
          );

          if (!connection) {
            return;
          }

          ConnectionHandler.deleteNode(connection, destroyedId);
        },
      }),
      [deviceId],
    ),
  );

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
