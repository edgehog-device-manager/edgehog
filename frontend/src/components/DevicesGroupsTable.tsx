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

import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  DevicesGroupsTable_DeviceFragment$data,
  DevicesGroupsTable_DeviceFragment$key,
} from "api/__generated__/DevicesGroupsTable_DeviceFragment.graphql";

import LastSeen from "components/LastSeen";
import Table, { createColumnHelper } from "components/Table";
import ConnectionStatus from "components/ConnectionStatus";
import Tag from "components/Tag";
import { Link, Route } from "Navigation";

// TODO This component is being temporarily used in DeviceGroup.tsx
// to display devices in a group. It should be removed once the
// backend returns DeviceConnection objects in the group query.

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICES_TABLE_FRAGMENT = graphql`
  fragment DevicesGroupsTable_DeviceFragment on Device @relay(plural: true) {
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
`;

type TableRecord = DevicesGroupsTable_DeviceFragment$data[0];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("online", {
    header: () => (
      <FormattedMessage
        id="components.DevicesGroupsTable.statusTitle"
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
        id="components.DevicesGroupsTable.nameTitle"
        defaultMessage="Device Name"
        description="Title for the Name column of the devices table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.devicesEdit} params={{ deviceId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("deviceId", {
    header: () => (
      <FormattedMessage
        id="components.DevicesGroupsTable.deviceIdTitle"
        defaultMessage="Device ID"
        description="Title for the Device ID column of the devices table"
      />
    ),
    sortingFn: "basic",
  }),
  columnHelper.accessor((device) => device.systemModel?.name, {
    id: "systemModel",
    header: () => (
      <FormattedMessage id="Device.systemModel" defaultMessage="System Model" />
    ),
  }),
  columnHelper.accessor((device) => device.systemModel?.hardwareType?.name, {
    id: "hardwareType",
    header: () => (
      <FormattedMessage
        id="Device.hardwareType"
        defaultMessage="Hardware Type"
      />
    ),
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
          id="components.DevicesGroupsTable.lastSeenTitle"
          defaultMessage="Last Seen"
          description="Title for the Last Seen column of the devices table"
        />
      ),
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
        id="components.DevicesGroupsTable.tagsTitle"
        defaultMessage="Tags"
        description="Title for the Tags column of the devices table"
      />
    ),
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
  devicesRef: DevicesGroupsTable_DeviceFragment$key;
  hideSearch?: boolean;
};

const DevicesGroupsTable = ({
  className,
  devicesRef,
  hideSearch = false,
}: Props) => {
  const devices = useFragment(DEVICES_TABLE_FRAGMENT, devicesRef);

  return (
    <Table
      className={className}
      columns={columns}
      data={devices}
      hideSearch={hideSearch}
    />
  );
};

export default DevicesGroupsTable;
