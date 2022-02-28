/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import { defineMessages, FormattedDate, FormattedMessage } from "react-intl";
import type { MessageDescriptor } from "react-intl";
import { graphql, useFragment } from "react-relay";

import type {
  OtaOperationStatus,
  OperationTable_otaOperations$data,
  OperationTable_otaOperations$key,
} from "api/__generated__/OperationTable_otaOperations.graphql";

import Icon from "components/Icon";
import Table from "components/Table";
import type { Column } from "components/Table";

const OPERATION_TABLE_FRAGMENT = graphql`
  fragment OperationTable_otaOperations on Device {
    otaOperations {
      baseImageUrl
      createdAt
      status
      updatedAt
    }
  }
`;

const getStatusColor = (status: OtaOperationStatus) => {
  switch (status) {
    case "PENDING":
    case "IN_PROGRESS":
      return "text-warning";

    case "ERROR":
      return "text-danger";

    case "DONE":
      return "text-success";

    default:
      return "text-muted";
  }
};

const messages: Record<string, MessageDescriptor> = defineMessages({
  PENDING: {
    id: "device.otaOperationStatus.Pending",
    defaultMessage: "Pending",
  },
  IN_PROGRESS: {
    id: "device.otaOperationStatus.InProgress",
    defaultMessage: "In progress",
  },
  ERROR: {
    id: "device.otaOperationStatus.Error",
    defaultMessage: "Error",
  },
  DONE: {
    id: "device.otaOperationStatus.Done",
    defaultMessage: "Done",
  },
  UnknownStatus: {
    id: "device.otaOperationStatus.Unknown",
    defaultMessage: "Unknown",
  },
});

const OperationStatus = ({ status }: { status: OtaOperationStatus }) => {
  const color = getStatusColor(status);
  return (
    <div className="d-flex align-items-center">
      <Icon icon="circle" className={`me-2 ${color}`} />
      <span>
        <FormattedMessage
          id={messages[status]?.id || messages.UnknownStatus.id}
        />
      </span>
    </div>
  );
};

type TableRecord = OperationTable_otaOperations$data["otaOperations"][0];

const columns: Column<TableRecord>[] = [
  {
    accessor: "status",
    Header: (
      <FormattedMessage
        id="components.OperationTable.operationStatus"
        defaultMessage="Status"
      />
    ),
    Cell: ({ value }) => <OperationStatus status={value} />,
  },
  {
    accessor: "baseImageUrl",
    Header: (
      <FormattedMessage
        id="components.OperationTable.baseImage"
        defaultMessage="Base Image"
      />
    ),
    Cell: ({ value }) => (
      <span className="text-nowrap">{value.split("/").pop()}</span>
    ),
  },
  {
    accessor: "createdAt",
    Header: (
      <FormattedMessage
        id="components.OperationTable.startedAt"
        defaultMessage="Started At"
      />
    ),
    Cell: ({ value }) => (
      <FormattedDate
        value={value}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    ),
  },
  {
    accessor: "updatedAt",
    Header: (
      <FormattedMessage
        id="components.OperationTable.updatedAt"
        defaultMessage="Updated At"
      />
    ),
    Cell: ({ value }) => (
      <FormattedDate
        value={value}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    ),
  },
];

type OperationTableProps = {
  className?: string;
  deviceRef: OperationTable_otaOperations$key;
};

const initialSortedColumns = [{ id: "updatedAt", desc: true }];

const OperationTable = ({ className, deviceRef }: OperationTableProps) => {
  const data = useFragment(OPERATION_TABLE_FRAGMENT, deviceRef);

  // react table requires mutable data
  // TODO change this once a solution has been found
  // see also https://github.com/TanStack/react-table/discussions/3648
  const otaOperations = data.otaOperations
    .filter(
      (operation) => operation.status === "DONE" || operation.status === "ERROR"
    )
    .map((operation) => ({
      ...operation,
    }));

  if (!otaOperations) {
    return (
      <div>
        <FormattedMessage
          id="pages.Device.SoftwareUpdateTab.noPreviousUpdates"
          defaultMessage="No previous updates"
        />
      </div>
    );
  }

  return (
    <Table
      className={className}
      columns={columns}
      data={otaOperations}
      sortBy={initialSortedColumns}
    />
  );
};

export type { OperationTableProps };

export default OperationTable;
