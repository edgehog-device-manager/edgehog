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

import React from "react";
import { defineMessages, FormattedDate, FormattedMessage } from "react-intl";

import Icon from "components/Icon";
import Table from "components/Table";
import type { Column } from "components/Table";
import type { OTAOperation, OTAOperationStatus } from "types/OTAUpdate";

type OperationStatusProps = {
  status: OTAOperationStatus | null;
};

const getStatusColor = (status: OTAOperationStatus | null) => {
  switch (status) {
    case "Pending":
    case "InProgress":
      return "text-warning";

    case "Error":
      return "text-danger";

    case "Done":
      return "text-success";

    case null:
      return "text-muted";
  }
};

defineMessages({
  started: {
    id: "device.otaOperationStatus.Pending",
    defaultMessage: "Pending",
  },
  inProgress: {
    id: "device.otaOperationStatus.InProgress",
    defaultMessage: "In progress",
  },
  error: {
    id: "device.otaOperationStatus.Error",
    defaultMessage: "Error",
  },
  done: {
    id: "device.otaOperationStatus.Done",
    defaultMessage: "Done",
  },
  unknown: {
    id: "device.otaOperationStatus.Unknown",
    defaultMessage: "Unknown",
  },
});

const OperationStatus = ({ status }: OperationStatusProps) => {
  const color = getStatusColor(status);
  return (
    <div className="d-flex align-items-center">
      <Icon icon="circle" className={`me-2 ${color}`} />
      <span>
        <FormattedMessage id={`device.otaOperationStatus.${status}`} />
      </span>
    </div>
  );
};

const columns: Column<OTAOperation>[] = [
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
  data: OTAOperation[];
};

const initialSortedColumns = [{ id: "updatedAt", desc: true }];

const OperationTable = ({ className, data }: OperationTableProps) => {
  return (
    <Table
      className={className}
      columns={columns}
      data={data}
      sortBy={initialSortedColumns}
    />
  );
};

export type { OperationTableProps };

export default OperationTable;
