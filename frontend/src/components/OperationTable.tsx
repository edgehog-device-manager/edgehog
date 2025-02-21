/*
  This file is part of Edgehog.

  Copyright 2022-2025 SECO Mind Srl

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
import { graphql, useFragment } from "react-relay/hooks";

import type {
  OtaOperationStatus,
  OperationTable_otaOperations$data,
  OperationTable_otaOperations$key,
} from "api/__generated__/OperationTable_otaOperations.graphql";

import Icon from "components/Icon";
import Table, { createColumnHelper } from "components/Table";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const OPERATION_TABLE_FRAGMENT = graphql`
  fragment OperationTable_otaOperations on Device {
    otaOperations {
      baseImageUrl
      createdAt
      status
      updatedAt
      updateTarget {
        updateCampaign {
          id
          name
        }
      }
    }
  }
`;

const otaOperationFinalStatuses = ["SUCCESS", "FAILURE"] as const;
type OtaOperationFinalStatus = (typeof otaOperationFinalStatuses)[number];

const isOtaOperationFinalStatus = (
  status: OtaOperationStatus,
): status is OtaOperationFinalStatus =>
  (otaOperationFinalStatuses as readonly string[]).includes(status);

type OtaOperation = OperationTable_otaOperations$data["otaOperations"][number];
type OtaOperationWithFinalStatus = Omit<OtaOperation, "status"> & {
  readonly status: OtaOperationFinalStatus;
};

const isOtaOperationWithFinalStatus = (
  operation: OtaOperation,
): operation is OtaOperationWithFinalStatus =>
  isOtaOperationFinalStatus(operation.status);

const statusColors: Record<OtaOperationFinalStatus, string> = {
  SUCCESS: "text-success",
  FAILURE: "text-danger",
};

const statusMessages = defineMessages<OtaOperationFinalStatus>({
  SUCCESS: {
    id: "device.otaOperationStatus.Success",
    defaultMessage: "Success",
  },
  FAILURE: {
    id: "device.otaOperationStatus.Failure",
    defaultMessage: "Failure",
  },
});

const OperationStatus = ({ status }: { status: OtaOperationFinalStatus }) => (
  <div className="d-flex align-items-center">
    <Icon icon="circle" className={`me-2 ${statusColors[status]}`} />
    <span>
      <FormattedMessage id={statusMessages[status].id} />
    </span>
  </div>
);

const columnHelper = createColumnHelper<OtaOperationWithFinalStatus>();
const columns = [
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.operationStatus"
        defaultMessage="Status"
      />
    ),
    cell: ({ getValue }) => <OperationStatus status={getValue()} />,
  }),
  columnHelper.accessor("updateTarget.updateCampaign.name", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.updateCampaignNameTitle"
        defaultMessage="Update Campaign"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.updateCampaignsEdit}
        params={{
          updateCampaignId: row.original.updateTarget?.updateCampaign.id ?? "",
        }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("baseImageUrl", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.baseImage"
        defaultMessage="Base Image"
      />
    ),
    cell: ({ getValue }) => (
      <span className="text-nowrap">{getValue().split("/").pop()}</span>
    ),
  }),
  columnHelper.accessor("createdAt", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.startedAt"
        defaultMessage="Started At"
      />
    ),
    cell: ({ getValue }) => (
      <FormattedDate
        value={getValue()}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    ),
  }),
  columnHelper.accessor("updatedAt", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.updatedAt"
        defaultMessage="Updated At"
      />
    ),
    cell: ({ getValue }) => (
      <FormattedDate
        value={getValue()}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    ),
  }),
];

type OperationTableProps = {
  className?: string;
  deviceRef: OperationTable_otaOperations$key;
};

const initialSortedColumns = [{ id: "updatedAt", desc: true }];

const OperationTable = ({ className, deviceRef }: OperationTableProps) => {
  const data = useFragment(OPERATION_TABLE_FRAGMENT, deviceRef);

  const otaOperations = data.otaOperations.filter(
    isOtaOperationWithFinalStatus,
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
