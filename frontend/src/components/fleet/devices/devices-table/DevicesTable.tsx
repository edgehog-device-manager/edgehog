/*
 * This file is part of Edgehog.
 *
 * Copyright 2021 - 2026 SECO Mind Srl
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
import { graphql, useFragment } from "react-relay/hooks";

import type {
  DevicesTable_DeviceEdgeFragment$data,
  DevicesTable_DeviceEdgeFragment$key,
} from "@/api/__generated__/DevicesTable_DeviceEdgeFragment.graphql";

import ConnectionStatus from "@/components/fleet/devices/connection-status/ConnectionStatus";
import LastSeen from "@/components/fleet/devices/last-seen/LastSeen";
import { createColumnHelper } from "@/components/ui/table/Table";
import Tag from "@/components/ui/tag/Tag";
import { Link, Route } from "@/Navigation";
import InfiniteTable from "@/components/ui/infinite-table/InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICES_TABLE_FRAGMENT = graphql`
  fragment DevicesTable_DeviceEdgeFragment on DeviceConnection {
    edges {
      node {
        id
        deviceId
        lastConnection
        lastDisconnection
        name
        online
        systemModel {
          name
          hardwareType {
            name
          }
        }
        tags {
          edges {
            node {
              name
            }
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<DevicesTable_DeviceEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("online", {
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.devices-table.DevicesTable.statusTitle"
        defaultMessage="Status"
        description="Title for the Status column of the devices table"
      />
    ),
    cell: ({ getValue }) => <ConnectionStatus connected={getValue()} />,
    sortingFn: "basic",
  }),
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.devices-table.DevicesTable.nameTitle"
        defaultMessage="Device Name"
        description="Title for the Name column of the devices table"
      />
    ),
    meta: {
      label: "Device Name",
      isPrimaryLink: true,
      getLink: (row, children) => (
        <Link
          route={Route.devicesEdit}
          params={{ deviceId: row.original.id }}
          className="row-link"
          onClick={(e) => e.stopPropagation()}
        >
          {children}
        </Link>
      ),
    },
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("deviceId", {
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.devices-table.DevicesTable.deviceIdTitle"
        defaultMessage="Device ID"
        description="Title for the Device ID column of the devices table"
      />
    ),
    meta: {
      label: "Device ID",
    },
    sortingFn: "basic",
  }),
  columnHelper.accessor((device) => device.systemModel?.name, {
    id: "systemModel",
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.devices-table.DevicesTable.systemModel"
        defaultMessage="System Model"
      />
    ),
    meta: {
      label: "System Model",
    },
  }),
  columnHelper.accessor((device) => device.systemModel?.hardwareType?.name, {
    id: "hardwareType",
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.devices-table.DevicesTable.hardwareType"
        defaultMessage="Hardware Type"
      />
    ),
    meta: {
      label: "Hardware Type",
    },
  }),
  columnHelper.accessor(
    (device) => {
      if (device.online) {
        return "now";
      } else {
        return device.lastDisconnection || "never";
      }
    },
    {
      id: "lastSeen",
      header: () => (
        <FormattedMessage
          id="components.fleet.devices.devices-table.DevicesTable.lastSeenTitle"
          defaultMessage="Last Seen"
          description="Title for the Last Seen column of the devices table"
        />
      ),
      meta: {
        label: "Last Seen",
      },
      cell: ({ row }) => (
        <LastSeen
          lastConnection={row.original.lastConnection}
          lastDisconnection={row.original.lastDisconnection}
          online={row.original.online}
        />
      ),
    },
  ),
  columnHelper.accessor("tags", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.fleet.devices.devices-table.DevicesTable.tagsTitle"
        defaultMessage="Tags"
        description="Title for the Tags column of the devices table"
      />
    ),
    meta: {
      label: "Tags",
    },
    cell: ({ getValue }) => (
      <>
        {getValue().edges?.map(({ node: { name: tag } }) => (
          <Tag key={tag} className="me-2">
            {tag}
          </Tag>
        ))}
      </>
    ),
  }),
];

type Props = {
  className?: string;
  devicesRef: DevicesTable_DeviceEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onSearchChange?: (text: string) => void;
  searchText?: string;
};

const DevicesTable = ({
  className,
  devicesRef,
  loading = false,
  onLoadMore,
  onSearchChange,
  searchText,
}: Props) => {
  const devicesFragment = useFragment(
    DEVICES_TABLE_FRAGMENT,
    devicesRef || null,
  );

  const devices = useMemo<TableRecord[]>(() => {
    return compact(devicesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [devicesFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={devices}
      loading={loading}
      onLoadMore={onLoadMore}
      columnVisibilityKey="devices-table"
      onSearchChange={onSearchChange}
      searchText={searchText}
    />
  );
};

export default DevicesTable;
