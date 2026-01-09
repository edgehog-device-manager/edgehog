/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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
  DeploymentTargetsTable_CampaignTargetsFragment$data,
  DeploymentTargetsTable_CampaignTargetsFragment$key,
} from "@/api/__generated__/DeploymentTargetsTable_CampaignTargetsFragment.graphql";

import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "@/components/InfiniteTable";
import DeploymentEventMessage from "@/components/DeploymentEventMessage";
import DeploymentStateComponent from "@/components/DeploymentState";
import DeploymentReadiness from "@/components/DeploymentReadiness";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGN_TARGETS_TABLE_FRAGMENT = graphql`
  fragment DeploymentTargetsTable_CampaignTargetsFragment on CampaignTarget
  @relay(plural: true) {
    device {
      id
      name
    }
    latestAttempt
    completionTimestamp
    deployment {
      state
      isReady
      events(
        filter: { type: { eq: ERROR } }
        sort: [{ field: INSERTED_AT, order: DESC }]
        first: 1
      ) {
        edges {
          node {
            message
            type
            insertedAt
            addInfo
          }
        }
      }
    }
  }
`;

type TableRecord = DeploymentTargetsTable_CampaignTargetsFragment$data[number];
const columnIds = [
  "deviceName",
  "state",
  "readiness",
  "lastErrorMessage",
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
        id="components.DeploymentTargetsTable.deviceNameTitle"
        defaultMessage="Device Name"
        description="Title for the Device Name column of the Deployment Targets table"
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
    (campaignTarget) => campaignTarget.deployment?.state ?? null,
    {
      id: "state",
      header: () => (
        <FormattedMessage
          id="components.DeploymentTargetsTable.stateTitle"
          defaultMessage="State"
          description="Title for the State column of the Deployment Targets table"
        />
      ),
      cell: ({ row, getValue }) => {
        const state = getValue();
        const isReady = row.original.deployment?.isReady;
        return (
          state && <DeploymentStateComponent state={state} isReady={isReady} />
        );
      },
    },
  ),
  columnHelper.accessor(
    (campaignTarget) => campaignTarget.deployment?.isReady ?? null,
    {
      id: "readiness",
      header: () => (
        <FormattedMessage
          id="components.DeploymentTargetsTable.readinessTitle"
          defaultMessage="Readiness"
          description="Title for the Readiness column of the Deployment Targets table"
        />
      ),
      cell: ({ getValue }) => {
        const isReady = getValue();
        return <DeploymentReadiness isReady={isReady} />;
      },
    },
  ),
  columnHelper.accessor(
    (campaignTarget) =>
      campaignTarget.deployment?.events?.edges?.[0]?.node ?? null,
    {
      id: "lastErrorMessage",
      header: () => (
        <FormattedMessage
          id="components.DeploymentTargetsTable.lastErrorMessageTitle"
          defaultMessage="Failure Reason"
          description="Title for the Last Error Message column of the Deployment Targets table"
        />
      ),
      cell: ({ getValue }) => {
        const event = getValue();
        return event ? <DeploymentEventMessage event={event} /> : null;
      },
    },
  ),
  columnHelper.accessor("latestAttempt", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentTargetsTable.latestAttemptTitle"
        defaultMessage="Latest attempt at"
        description="Title for the Latest attempt at column of the Deployment Targets table"
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
        id="components.DeploymentTargetsTable.completionTimestampTitle"
        defaultMessage="Completed at"
        description="Title for the Completed at column of the Deployment Targets table"
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
  campaignTargetsRef: DeploymentTargetsTable_CampaignTargetsFragment$key;
  isLoadingNext: boolean;
  hasNext: boolean;
  loadNextCampaignTargets: () => void;
};

const DeploymentTargetsTable = ({
  className,
  campaignTargetsRef,
  hiddenColumns = [],
  isLoadingNext,
  hasNext,
  loadNextCampaignTargets,
}: Props) => {
  const campaignTargets = useFragment(
    CAMPAIGN_TARGETS_TABLE_FRAGMENT,
    campaignTargetsRef,
  );
  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={[...campaignTargets]}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextCampaignTargets : undefined}
      hiddenColumns={hiddenColumns}
      hideSearch
    />
  );
};

export default DeploymentTargetsTable;
export { columnIds };
export type { ColumnId };
