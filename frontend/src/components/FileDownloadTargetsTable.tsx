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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedDate, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  FileDownloadTargetsTable_CampaignTargetEdgeFragment$data,
  FileDownloadTargetsTable_CampaignTargetEdgeFragment$key,
} from "@/api/__generated__/FileDownloadTargetsTable_CampaignTargetEdgeFragment.graphql";

import InfiniteTable from "@/components/InfiniteTable";
import RequestStatus from "@/components/RequestStatus";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGN_TARGETS_TABLE_FRAGMENT = graphql`
  fragment FileDownloadTargetsTable_CampaignTargetEdgeFragment on CampaignTargetConnection {
    edges {
      node {
        device {
          id
          name
        }
        retryCount
        latestAttempt
        completionTimestamp
        fileDownloadRequest {
          status
          progressPercentage
          responseCode
          responseMessage
          destinationType
          pathOnDevice
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<FileDownloadTargetsTable_CampaignTargetEdgeFragment$data>["edges"]
>[number]["node"];

const columnIds = [
  "deviceName",
  "requestStatus",
  "requestProgress",
  "failureReason",
  "retryCount",
  "latestAttempt",
  "completionTimestamp",
  "pathOnDevice",
] as const;

type ColumnId = (typeof columnIds)[number];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("device.name", {
    id: "deviceName",
    header: () => (
      <FormattedMessage
        id="components.FileDownloadTargetsTable.deviceTitle"
        defaultMessage="Device"
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
    (target) => target.fileDownloadRequest?.status ?? null,
    {
      id: "requestStatus",
      header: () => (
        <FormattedMessage
          id="components.FileDownloadTargetsTable.requestStatusTitle"
          defaultMessage="Request Status"
        />
      ),
      cell: ({ getValue }) => <RequestStatus status={getValue()} />,
    },
  ),
  columnHelper.accessor(
    (target) => target.fileDownloadRequest?.progressPercentage ?? null,
    {
      id: "requestProgress",
      header: () => (
        <FormattedMessage
          id="components.FileDownloadTargetsTable.requestProgressTitle"
          defaultMessage="Progress"
        />
      ),
      cell: ({ getValue }) => {
        const progress = getValue();
        return typeof progress === "number" ? `${progress}%` : "";
      },
    },
  ),
  columnHelper.accessor(
    (target) =>
      target.fileDownloadRequest?.responseMessage ??
      (typeof target.fileDownloadRequest?.responseCode === "number"
        ? `Code ${target.fileDownloadRequest.responseCode}`
        : null),
    {
      id: "failureReason",
      header: () => (
        <FormattedMessage
          id="components.FileDownloadTargetsTable.failureReasonTitle"
          defaultMessage="Failure Reason"
        />
      ),
    },
  ),
  columnHelper.accessor("retryCount", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadTargetsTable.retryCountTitle"
        defaultMessage="Retry Count"
      />
    ),
    cell: ({ getValue }) => {
      const retryCount = getValue();
      return retryCount ? retryCount : "";
    },
  }),
  columnHelper.accessor("latestAttempt", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadTargetsTable.latestAttemptTitle"
        defaultMessage="Latest attempt at"
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
  columnHelper.accessor((target) => target.fileDownloadRequest ?? null, {
    id: "pathOnDevice",
    header: () => (
      <FormattedMessage
        id="components.FileDownloadTargetsTable.pathOnDeviceTitle"
        defaultMessage="Path on device"
      />
    ),
    cell: ({ getValue }) => {
      const request = getValue() as {
        destinationType?: string | null;
        pathOnDevice?: string | null;
      } | null;
      return request?.destinationType === "STORAGE" ? request.pathOnDevice : "";
    },
  }),
  columnHelper.accessor("completionTimestamp", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadTargetsTable.completionTimestampTitle"
        defaultMessage="Completed at"
      />
    ),
    cell: ({ getValue }) => {
      const completionTimestamp = getValue();
      return (
        completionTimestamp && (
          <FormattedDate
            value={completionTimestamp}
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

type FileDownloadTargetsTableProps = {
  className?: string;
  hiddenColumns?: ColumnId[];
  campaignTargetsRef: FileDownloadTargetsTable_CampaignTargetEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const FileDownloadTargetsTable = ({
  className,
  campaignTargetsRef,
  hiddenColumns = [],
  loading = false,
  onLoadMore,
}: FileDownloadTargetsTableProps) => {
  const campaignTargetsFragment = useFragment(
    CAMPAIGN_TARGETS_TABLE_FRAGMENT,
    campaignTargetsRef,
  );

  const campaignTargets = useMemo<TableRecord[]>(() => {
    return _.compact(campaignTargetsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [campaignTargetsFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={campaignTargets}
      loading={loading}
      onLoadMore={onLoadMore}
      hiddenColumns={hiddenColumns}
      hideSearch
    />
  );
};

export default FileDownloadTargetsTable;
export { columnIds };
export type { ColumnId };
