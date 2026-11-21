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

import compact from "lodash/compact";
import { useCallback, useMemo, useState } from "react";
import { FormattedMessage, useIntl, type IntlShape } from "react-intl";
import { graphql, useMutation, usePaginationFragment } from "react-relay/hooks";

import type { VolumesTable_PaginationQuery } from "@/api/__generated__/VolumesTable_PaginationQuery.graphql";
import type {
  VolumesTable_volumeDeployments$data,
  VolumesTable_volumeDeployments$key,
} from "@/api/__generated__/VolumesTable_volumeDeployments.graphql";
import type { VolumesTable_sendVolumeCommand_Mutation } from "@/api/__generated__/VolumesTable_sendVolumeCommand_Mutation.graphql";

import { Link, Route } from "@/Navigation";
import ResourceState from "@/components/apps/resource-state/ResourceState";
import Alert from "@/components/ui/alert/Alert";
import Button from "@/components/ui/button/Button";
import DeleteModal from "@/components/ui/delete-modal/DeleteModal";
import Icon from "@/components/ui/icon/Icon";
import Result from "@/components/ui/result/Result";
import Table, { createColumnHelper } from "@/components/ui/table/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const VOLUMES_TABLE_FRAGMENT = graphql`
  fragment VolumesTable_volumeDeployments on Device
  @refetchable(queryName: "VolumesTable_PaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    id
    online
    volumeDeployments(first: $first, after: $after)
      @connection(key: "VolumesTable_volumeDeployments") {
      edges {
        node {
          id
          state
          isReady
          volume {
            id
            label
            driver
            reclaimPolicy
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
  }
`;

const SEND_VOLUME_COMMAND_MUTATION = graphql`
  mutation VolumesTable_sendVolumeCommand_Mutation(
    $id: ID!
    $command: VolumeCommand!
  ) {
    sendVolumeCommand(id: $id, command: $command) {
      result {
        id
        state
      }
      errors {
        message
      }
    }
  }
`;

type VolumeDeploymentNode = NonNullable<
  NonNullable<VolumesTable_volumeDeployments$data["volumeDeployments"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<VolumeDeploymentNode>();
const getColumnsDefinition = (
  onDeleteClick: (volumeDeployment: VolumeDeploymentNode) => void,
  isOnline: boolean,
  intl: IntlShape,
) => [
  columnHelper.accessor((row) => row.volume?.label, {
    id: "label",
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.volumes-table.VolumesTable.labelTitle"
        defaultMessage="Label"
        description="Title for the Label column of the device volumes table"
      />
    ),
    cell: ({ row, getValue }) => {
      const label = getValue();
      const volumeId = row.original.volume?.id;
      if (!label) return "";
      if (!volumeId) return label;
      return (
        <Link route={Route.volumeEdit} params={{ volumeId }}>
          {label}
        </Link>
      );
    },
  }),
  columnHelper.accessor((row) => row.volume?.driver, {
    id: "driver",
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.volumes-table.VolumesTable.driverTitle"
        defaultMessage="Driver"
        description="Title for the Driver column of the device volumes table"
      />
    ),
    cell: ({ getValue }) => getValue() ?? "",
  }),
  columnHelper.accessor((row) => row.volume?.containerVolumes, {
    id: "mountpoints",
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.volumes-table.VolumesTable.mountpointsTitle"
        defaultMessage="Mountpoints"
        description="Title for the Mountpoints column of the device volumes table"
      />
    ),
    cell: ({ getValue }) => {
      const containerVolumes = compact(
        getValue()?.edges?.map((edge) => edge?.node),
      );
      if (!containerVolumes.length) return "";
      return (
        <span className="d-flex flex-wrap gap-1">
          {containerVolumes.map(({ id, target, container }) => (
            <span
              key={id}
              className="badge text-bg-light text-nowrap fw-normal border d-inline-flex align-items-center gap-1"
            >
              <Link
                route={Route.containersEdit}
                params={{ containerId: container.id }}
              >
                {container.name}
              </Link>
              <span className="text-muted">:</span>
              <span className="font-monospace">{target}</span>
            </span>
          ))}
        </span>
      );
    },
  }),
  columnHelper.accessor((row) => row.volume?.reclaimPolicy, {
    id: "reclaimPolicy",
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.volumes-table.VolumesTable.reclaimPolicyTitle"
        defaultMessage="Reclaim Policy"
        description="Title for the Reclaim Policy column of the device volumes table"
      />
    ),
    cell: ({ getValue }) => getValue() ?? "",
  }),
  columnHelper.accessor("state", {
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.volumes-table.VolumesTable.stateTitle"
        defaultMessage="State"
        description="Title for the State column of the device volumes table"
      />
    ),
    cell: ({ row }) => (
      <ResourceState
        state={row.original.state}
        isReady={row.original.isReady}
      />
    ),
  }),
  columnHelper.accessor((row) => row, {
    id: "actions",
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.volumes-table.VolumesTable.actionsTitle"
        defaultMessage="Actions"
        description="Title for the Actions column of the device volumes table"
      />
    ),
    meta: {
      label: "Actions",
    },
    cell: ({ row }) => {
      const volumeDeployment = row.original;
      return (
        <Button
          className="btn p-0 border-0 bg-transparent icon-click"
          disabled={!isOnline}
          aria-label={intl.formatMessage({
            id: "components.fleet.devices.volumes-table.VolumesTable.deleteButtonTitle",
            defaultMessage: "Delete Volume on Device",
          })}
          title={
            !isOnline
              ? intl.formatMessage({
                  id: "components.fleet.devices.volumes-table.VolumesTable.deviceOfflineTooltip",
                  defaultMessage:
                    "The device is offline. You cannot delete volumes while it is disconnected.",
                })
              : intl.formatMessage({
                  id: "components.fleet.devices.volumes-table.VolumesTable.deleteButtonTitle",
                  defaultMessage: "Delete Volume on Device",
                })
          }
          onClick={() => onDeleteClick(volumeDeployment)}
        >
          <Icon
            className={isOnline ? "text-danger" : "text-muted"}
            icon="delete"
          />
        </Button>
      );
    },
  }),
];

type Props = {
  className?: string;
  deviceRef: VolumesTable_volumeDeployments$key;
};

const VolumesTable = ({ className, deviceRef }: Props) => {
  const intl = useIntl();
  const { data } = usePaginationFragment<
    VolumesTable_PaginationQuery,
    VolumesTable_volumeDeployments$key
  >(VOLUMES_TABLE_FRAGMENT, deviceRef);

  const { online, volumeDeployments } = data;
  const isOnline = Boolean(online);

  const [volumeToDelete, setVolumeToDelete] =
    useState<VolumeDeploymentNode | null>(null);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [sendCommand, isSendingCommand] =
    useMutation<VolumesTable_sendVolumeCommand_Mutation>(
      SEND_VOLUME_COMMAND_MUTATION,
    );

  const handleDeleteVolume = useCallback(
    (deploymentId: string) => {
      sendCommand({
        variables: {
          id: deploymentId,
          command: "DELETE",
        },
        onCompleted(data, errors) {
          if (errors && errors.length > 0) {
            const errorMsg = errors
              .map(({ fields, message }) =>
                fields && fields.length
                  ? `${fields.join(" ")} ${message}`
                  : message,
              )
              .join(". \n");
            setErrorFeedback(errorMsg);
          } else if (
            data.sendVolumeCommand?.errors &&
            data.sendVolumeCommand.errors.length > 0
          ) {
            const errorMsg = data.sendVolumeCommand.errors
              .map(({ message }) => message)
              .join(". \n");
            setErrorFeedback(errorMsg);
          } else {
            setErrorFeedback(null);
          }
          setVolumeToDelete(null);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="components.fleet.devices.volumes-table.VolumesTable.deleteErrorFeedback"
              defaultMessage="Could not delete the Volume, please try again."
            />,
          );
          setVolumeToDelete(null);
        },
      });
    },
    [sendCommand],
  );

  const columns = useMemo(
    () => getColumnsDefinition(setVolumeToDelete, isOnline, intl),
    [isOnline, intl],
  );

  const volumes = useMemo<VolumeDeploymentNode[]>(
    () => compact(volumeDeployments?.edges?.map((edge) => edge?.node)) ?? [],
    [volumeDeployments],
  );

  if (!volumes.length) {
    return (
      <Result.EmptyList
        title={
          <FormattedMessage
            id="components.fleet.devices.volumes-table.VolumesTable.noVolumes.title"
            defaultMessage="No volumes"
          />
        }
      >
        <FormattedMessage
          id="components.fleet.devices.volumes-table.VolumesTable.noVolumes.message"
          defaultMessage="The device has no volumes."
        />
      </Result.EmptyList>
    );
  }

  return (
    <>
      <Alert
        className="mb-3"
        show={!!errorFeedback}
        variant="danger"
        onClose={() => setErrorFeedback(null)}
        dismissible
      >
        {errorFeedback}
      </Alert>
      <Table
        className={className}
        columns={columns}
        data={volumes}
        hideSearch
        columnVisibilityKey="device-volumes-table"
      />
      {volumeToDelete && (
        <DeleteModal
          confirmText={volumeToDelete.volume?.label || ""}
          onCancel={() => setVolumeToDelete(null)}
          onConfirm={() => {
            if (volumeToDelete?.id) {
              handleDeleteVolume(volumeToDelete.id);
            }
          }}
          isDeleting={isSendingCommand}
          title={
            <FormattedMessage
              id="components.fleet.devices.volumes-table.VolumesTable.deleteModal.title"
              defaultMessage="Delete Volume on Device"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.fleet.devices.volumes-table.VolumesTable.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete and wipe the volume <bold>{volume}</bold> from this device."
              values={{
                volume: volumeToDelete.volume?.label,
                bold: (chunks) => <strong>{chunks}</strong>,
              }}
            />
          </p>
        </DeleteModal>
      )}
    </>
  );
};

export default VolumesTable;
