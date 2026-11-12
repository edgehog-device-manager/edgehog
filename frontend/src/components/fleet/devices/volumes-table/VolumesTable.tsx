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
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { VolumesTable_PaginationQuery } from "@/api/__generated__/VolumesTable_PaginationQuery.graphql";
import type {
  VolumesTable_volumeDeployments$data,
  VolumesTable_volumeDeployments$key,
} from "@/api/__generated__/VolumesTable_volumeDeployments.graphql";

import { Link, Route } from "@/Navigation";
import ResourceState from "@/components/apps/resource-state/ResourceState";
import Result from "@/components/ui/result/Result";
import Table, { createColumnHelper } from "@/components/ui/table/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const VOLUMES_TABLE_FRAGMENT = graphql`
  fragment VolumesTable_volumeDeployments on Device
  @refetchable(queryName: "VolumesTable_PaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
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

type VolumeDeploymentNode = NonNullable<
  NonNullable<VolumesTable_volumeDeployments$data["volumeDeployments"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<VolumeDeploymentNode>();
const columns = [
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
];

type Props = {
  className?: string;
  deviceRef: VolumesTable_volumeDeployments$key;
};

const VolumesTable = ({ className, deviceRef }: Props) => {
  const { data } = usePaginationFragment<
    VolumesTable_PaginationQuery,
    VolumesTable_volumeDeployments$key
  >(VOLUMES_TABLE_FRAGMENT, deviceRef);

  const { volumeDeployments } = data;

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
    <Table
      className={className}
      columns={columns}
      data={volumes}
      hideSearch
      columnVisibilityKey="device-volumes-table"
    />
  );
};

export default VolumesTable;
