import React from "react";
import { FormattedMessage } from "react-intl";

import Table from "components/Table";
import type { Column } from "components/Table";
import ConnectionStatus from "components/ConnectionStatus";
import { Link, Route } from "Navigation";

type DeviceProps = {
  deviceId: string;
  id: string;
  name: string;
  online: boolean;
};

const columns: Column<DeviceProps>[] = [
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
];

interface Props {
  className?: string;
  data: DeviceProps[];
}

const DevicesTable = ({ className, data }: Props) => {
  return <Table className={className} columns={columns} data={data} />;
};

export type { DeviceProps };

export default DevicesTable;
