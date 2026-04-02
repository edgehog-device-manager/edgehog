/*
 * This file is part of Edgehog.
 *
 * Copyright 2022 - 2026 SECO Mind Srl
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

import { FormattedDate, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  OperationTable_otaOperationEdgeFragment$data,
  OperationTable_otaOperationEdgeFragment$key,
} from "@/api/__generated__/OperationTable_otaOperationEdgeFragment.graphql";

import Table, { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";
import _ from "lodash";
import { useMemo } from "react";
import {
  OperationStatus,
  operationStatusCodeMessages,
} from "./UpdateTargetsTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const OPERATION_TABLE_FRAGMENT = graphql`
  fragment OperationTable_otaOperationEdgeFragment on OtaOperationConnection {
    edges {
      node {
        baseImageUrl
        createdAt
        status
        statusProgress
        statusCode
        updatedAt
        campaignTarget {
          campaign {
            id
            name
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<OperationTable_otaOperationEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.operationStatus"
        defaultMessage="Status"
      />
    ),
    cell: ({ getValue }) => {
      const status = getValue();
      return status && <OperationStatus status={status} />;
    },
  }),
  columnHelper.accessor("statusProgress", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.operationStatusProgressTitle"
        defaultMessage="Operation progress"
      />
    ),
    cell: ({ getValue, row }) => {
      const status = row.original.status;
      if (status == "FAILURE") return null;

      const progress = getValue();
      return typeof progress === "number" ? `${progress}%` : "";
    },
  }),
  columnHelper.accessor("statusCode", {
    header: () => (
      <FormattedMessage
        id="components.OperationTable.operationsStatusCodeTitle"
        defaultMessage="Failure Reason"
      />
    ),
    cell: ({ getValue }) => {
      const statusCode = getValue();
      return (
        statusCode && (
          <FormattedMessage {...operationStatusCodeMessages[statusCode]} />
        )
      );
    },
  }),
  columnHelper.accessor("campaignTarget.campaign.name", {
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
          updateCampaignId: row.original.campaignTarget?.campaign.id ?? "",
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
  otaOperationsRef: OperationTable_otaOperationEdgeFragment$key;
};

const initialSortedColumns = [{ id: "updatedAt", desc: true }];

const OperationTable = ({
  className,
  otaOperationsRef,
}: OperationTableProps) => {
  const otaOperationsFragment = useFragment(
    OPERATION_TABLE_FRAGMENT,
    otaOperationsRef || null,
  );

  const otaOperations = useMemo<TableRecord[]>(() => {
    return _.compact(otaOperationsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [otaOperationsFragment]);

  if (!otaOperations) {
    return (
      <div>
        <FormattedMessage
          id="components.OperationTable.noPreviousUpdates"
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
