/*
  This file is part of Edgehog.

  Copyright 2021-2022 SECO Mind Srl

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

import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay";

import type {
  DevicesTable_DeviceFragment$data,
  DevicesTable_DeviceFragment$key,
} from "api/__generated__/DevicesTable_DeviceFragment.graphql";

import LastSeen from "components/LastSeen";
import Table from "components/Table";
import type { Column, Row } from "components/Table";
import ConnectionStatus from "components/ConnectionStatus";
import Tag from "components/Tag";
import { Link, Route } from "Navigation";

const DEVICES_TABLE_FRAGMENT = graphql`
  fragment DevicesTable_DeviceFragment on Device @relay(plural: true) {
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
    tags
  }
`;

type TableRecord = DevicesTable_DeviceFragment$data[0];

const columns: Column<TableRecord>[] = [
  {
    id: "status",
    accessor: (device) => Boolean(device.online),
    Header: (
      <FormattedMessage
        id="components.DevicesTable.statusTitle"
        defaultMessage="Status"
        description="Title for the Status column of the devices table"
      />
    ),
    Cell: ({ value }: { value: boolean }) => (
      <ConnectionStatus connected={value} />
    ),
    sortType: "basic",
  },
  {
    accessor: "name",
    Header: (
      <FormattedMessage
        id="components.DevicesTable.nameTitle"
        defaultMessage="Device Name"
        description="Title for the Name column of the devices table"
      />
    ),
    Cell: ({ row, value }) => (
      <Link route={Route.devicesEdit} params={{ deviceId: row.original.id }}>
        {value}
      </Link>
    ),
  },
  {
    id: "deviceId",
    accessor: (device) => device.deviceId,
    Header: (
      <FormattedMessage
        id="components.DevicesTable.deviceIdTitle"
        defaultMessage="Device ID"
        description="Title for the Device ID column of the devices table"
      />
    ),
    sortType: "basic",
  },
  {
    id: "systemModel",
    accessor: (device) => device.systemModel?.name,
    Header: (
      <FormattedMessage id="Device.systemModel" defaultMessage="System Model" />
    ),
  },
  {
    id: "hardwareType",
    accessor: (device) => device.systemModel?.hardwareType.name,
    Header: (
      <FormattedMessage
        id="Device.hardwareType"
        defaultMessage="Hardware Type"
      />
    ),
  },
  {
    id: "lastSeen",
    accessor: (device) => {
      if (device.online) {
        return "now";
      } else {
        return device.lastDisconnection || "never";
      }
    },
    Header: (
      <FormattedMessage
        id="components.DevicesTable.lastSeenTitle"
        defaultMessage="Last Seen"
        description="Title for the Last Seen column of the devices table"
      />
    ),
    Cell: ({ row }: { row: Row<TableRecord> }) => (
      <LastSeen
        lastConnection={row.original.lastConnection}
        lastDisconnection={row.original.lastDisconnection}
        online={row.original.online}
      />
    ),
  },
  {
    accessor: "tags",
    disableSortBy: true,
    Header: (
      <FormattedMessage
        id="components.DevicesTable.tagsTitle"
        defaultMessage="Tags"
        description="Title for the Tags column of the devices table"
      />
    ),
    Cell: ({ value }) => (
      <>
        {value.map((tag) => (
          <Tag key={tag} className="me-2">
            {tag}
          </Tag>
        ))}
      </>
    ),
  },
];

interface Props {
  className?: string;
  devicesRef: DevicesTable_DeviceFragment$key;
}

const DevicesTable = ({ className, devicesRef }: Props) => {
  const devicesData = useFragment(DEVICES_TABLE_FRAGMENT, devicesRef);

  // TODO: handle readonly type without mapping to mutable type
  const devices = useMemo(
    () => devicesData.map((device) => ({ ...device, tags: [...device.tags] })),
    [devicesData]
  );

  return <Table className={className} columns={columns} data={devices} />;
};

export default DevicesTable;
