/*
  This file is part of Edgehog.

  Copyright 2022-2023 SECO Mind Srl

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

import { defineMessages, FormattedDate, FormattedMessage } from "react-intl";
import type { MessageDescriptor } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  OtaOperationStatus,
  OperationTable_otaOperations$data,
  OperationTable_otaOperations$key,
} from "api/__generated__/OperationTable_otaOperations.graphql";

import Icon from "components/Icon";
import Table from "components/Table";
import type { Column } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
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

const otaOperationFinalStatuses = ["SUCCESS", "FAILURE"] as const;
type OtaOperationFinalStatus = typeof otaOperationFinalStatuses[number];

const isOtaOperationFinalStatus = (
  status: OtaOperationStatus
): status is OtaOperationFinalStatus =>
  (otaOperationFinalStatuses as readonly string[]).includes(status);

type OtaOperation = OperationTable_otaOperations$data["otaOperations"][number];
type OtaOperationWithFinalStatus = Omit<OtaOperation, "status"> & {
  readonly status: OtaOperationFinalStatus;
};

const isOtaOperationWithFinalStatus = (
  operation: OtaOperation
): operation is OtaOperationWithFinalStatus =>
  isOtaOperationFinalStatus(operation.status);

const getStatusColor = (status: OtaOperationFinalStatus): string => {
  switch (status) {
    case "SUCCESS":
      return "text-success";

    case "FAILURE":
      return "text-danger";
  }
};

const messages: Record<OtaOperationFinalStatus, MessageDescriptor> =
  defineMessages({
    SUCCESS: {
      id: "device.otaOperationStatus.Success",
      defaultMessage: "Success",
    },
    FAILURE: {
      id: "device.otaOperationStatus.Failure",
      defaultMessage: "Failure",
    },
  });

const OperationStatus = ({ status }: { status: OtaOperationFinalStatus }) => {
  const color = getStatusColor(status);
  return (
    <div className="d-flex align-items-center">
      <Icon icon="circle" className={`me-2 ${color}`} />
      <span>
        <FormattedMessage id={messages[status].id} />
      </span>
    </div>
  );
};

const columns: Column<OtaOperationWithFinalStatus>[] = [
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

  const otaOperations = data.otaOperations.filter(
    isOtaOperationWithFinalStatus
  );

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
