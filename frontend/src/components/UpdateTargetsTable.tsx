/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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
  OtaOperationStatusCode,
  UpdateTargetsTable_UpdateTargetsFragment$data,
  UpdateTargetsTable_UpdateTargetsFragment$key,
} from "api/__generated__/UpdateTargetsTable_UpdateTargetsFragment.graphql";

import Icon from "components/Icon";
import { createColumnHelper } from "components/Table";
import { Link, Route } from "Navigation";
import InfiniteTable from "./InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const UPDATE_TARGETS_TABLE_FRAGMENT = graphql`
  fragment UpdateTargetsTable_UpdateTargetsFragment on UpdateTarget
  @relay(plural: true) {
    device {
      id
      name
    }
    latestAttempt
    completionTimestamp
    otaOperation {
      status
      statusProgress
      statusCode
    }
  }
`;

const getOperationStatusColor = (status: OtaOperationStatus): string => {
  switch (status) {
    case "PENDING":
      return "text-muted";
    case "SUCCESS":
      return "text-success";
    case "FAILURE":
      return "text-danger";

    case "ACKNOWLEDGED":
    case "DEPLOYED":
    case "DEPLOYING":
    case "DOWNLOADING":
    case "ERROR":
    case "REBOOTING":
      return "text-warning";
  }
};

const operationStatusMessages = defineMessages<OtaOperationStatus>({
  PENDING: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Pending",
    defaultMessage: "Pending",
  },
  ACKNOWLEDGED: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Acknowledged",
    defaultMessage: "Acknowledged",
  },
  DOWNLOADING: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Downloading",
    defaultMessage: "Downloading",
  },
  DEPLOYING: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Deploying",
    defaultMessage: "Deploying",
  },
  DEPLOYED: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Deployed",
    defaultMessage: "Deployed",
  },
  REBOOTING: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Rebooting",
    defaultMessage: "Rebooting",
  },
  SUCCESS: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Success",
    defaultMessage: "Success",
  },
  ERROR: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Error",
    defaultMessage: "Error",
  },
  FAILURE: {
    id: "components.UpdateTargetsTable.otaOperationStatus.Failure",
    defaultMessage: "Failure",
  },
});

const OperationStatus = ({ status }: { status: OtaOperationStatus }) => (
  <div className="d-flex align-items-center">
    <Icon icon="circle" className={`me-2 ${getOperationStatusColor(status)}`} />
    <span>
      <FormattedMessage id={operationStatusMessages[status].id} />
    </span>
  </div>
);

const operationStatusCodeMessages = defineMessages<OtaOperationStatusCode>({
  CANCELED: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.Canceled",
    defaultMessage: "Canceled",
  },
  INTERNAL_ERROR: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.InternalError",
    defaultMessage: "Internal error",
  },
  INVALID_BASE_IMAGE: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.InvalidBaseImage",
    defaultMessage: "Invalid Base Image",
  },
  INVALID_REQUEST: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.InvalidRequest",
    defaultMessage: "Invalid request",
  },
  IO_ERROR: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.IOError",
    defaultMessage: "IO error",
  },
  NETWORK_ERROR: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.NetworkError",
    defaultMessage: "Network error",
  },
  REQUEST_TIMEOUT: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.RequestTimeout",
    defaultMessage: "Request timeout",
  },
  SYSTEM_ROLLBACK: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.SystemRollback",
    defaultMessage: "System rollback",
  },
  UPDATE_ALREADY_IN_PROGRESS: {
    id: "components.UpdateTargetsTable.otaOperationStatusCode.UpdateAlreadyInProgress",
    defaultMessage: "Update already in progress",
  },
});

type TableRecord = UpdateTargetsTable_UpdateTargetsFragment$data[number];
const columnIds = [
  "deviceName",
  "otaOperationStatus",
  "otaOperationStatusProgress",
  "otaOperationStatusCode",
  "latestAttempt",
  "completionTimestamp",
] as const;
type ColumnId = (typeof columnIds)[number];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("device.name", {
    id: "deviceName",
    header: () => (
      <FormattedMessage
        id="components.UpdateTargetsTable.deviceTitle"
        defaultMessage="Device"
        description="Title for the Device column of the Update Targets table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.devicesEdit}
        params={{ deviceId: row.original.device.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor(
    (updateTarget) => updateTarget.otaOperation?.status ?? null,
    {
      id: "otaOperationStatus",
      header: () => (
        <FormattedMessage
          id="components.UpdateTargetsTable.otaOperationStatusTitle"
          defaultMessage="Operation"
          description="Title for the Operation Status column of the Update Targets table"
        />
      ),
      cell: ({ getValue }) => {
        const status = getValue();
        return status && <OperationStatus status={status} />;
      },
    },
  ),
  columnHelper.accessor(
    (updateTarget) => updateTarget.otaOperation?.statusProgress ?? null,
    {
      id: "otaOperationStatusProgress",
      header: () => (
        <FormattedMessage
          id="components.UpdateTargetsTable.otaOperationStatusProgressTitle"
          defaultMessage="Operation progress"
          description="Title for the Operation Status Progress column of the Update Targets table"
        />
      ),
      cell: ({ getValue }) => {
        const progress = getValue();
        return typeof progress === "number" ? `${progress}%` : "";
      },
    },
  ),
  columnHelper.accessor(
    (updateTarget) => updateTarget.otaOperation?.statusCode ?? null,
    {
      id: "otaOperationStatusCode",
      header: () => (
        <FormattedMessage
          id="components.UpdateTargetsTable.otaOperationStatusCodeTitle"
          defaultMessage="Failure Reason"
          description="Title for the Operation Status Code column of the Update Targets table"
        />
      ),
      cell: ({ getValue }) => {
        const statusCode = getValue();
        return (
          statusCode && (
            <FormattedMessage id={operationStatusCodeMessages[statusCode].id} />
          )
        );
      },
    },
  ),
  columnHelper.accessor("latestAttempt", {
    header: () => (
      <FormattedMessage
        id="components.UpdateTargetsTable.latestAttemptTitle"
        defaultMessage="Latest attempt at"
        description="Title for the Latest attempt at column of the Update Targets table"
      />
    ),
    cell: ({ getValue }) => {
      const latestAttempt = getValue();
      return (
        latestAttempt && (
          <FormattedDate
            value={latestAttempt}
            year="numeric"
            month="long"
            day="numeric"
            hour="numeric"
            minute="numeric"
          />
        )
      );
    },
  }),
  columnHelper.accessor("completionTimestamp", {
    header: () => (
      <FormattedMessage
        id="components.UpdateTargetsTable.completionTimestampTitle"
        defaultMessage="Completed at"
        description="Title for the Completed at column of the Update Targets table"
      />
    ),
    cell: ({ getValue }) => {
      const latestAttempt = getValue();
      return (
        latestAttempt && (
          <FormattedDate
            value={latestAttempt}
            year="numeric"
            month="long"
            day="numeric"
            hour="numeric"
            minute="numeric"
          />
        )
      );
    },
  }),
];

type Props = {
  className?: string;
  hiddenColumns?: ColumnId[];
  updateTargetsRef: UpdateTargetsTable_UpdateTargetsFragment$key;
  isLoadingNext: boolean;
  hasNext: boolean;
  loadNextUpdateTargets: () => void;
};

const UpdateTargetsTable = ({
  className,
  updateTargetsRef,
  hiddenColumns = [],
  isLoadingNext,
  hasNext,
  loadNextUpdateTargets,
}: Props) => {
  const updateTargets = useFragment(
    UPDATE_TARGETS_TABLE_FRAGMENT,
    updateTargetsRef,
  );

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={[...updateTargets]}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextUpdateTargets : undefined}
      hiddenColumns={hiddenColumns}
      hideSearch
    />
  );
};

export default UpdateTargetsTable;
export { columnIds };
export type { ColumnId };
