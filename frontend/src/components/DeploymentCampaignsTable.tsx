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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  DeploymentCampaignsTable_CampaignEdgeFragment$data,
  DeploymentCampaignsTable_CampaignEdgeFragment$key,
} from "@/api/__generated__/DeploymentCampaignsTable_CampaignEdgeFragment.graphql";

import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import Icon from "@/components/Icon";
import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGNS_TABLE_FRAGMENT = graphql`
  fragment DeploymentCampaignsTable_CampaignEdgeFragment on CampaignConnection {
    edges {
      node {
        id
        name
        status
        ...CampaignStatus_CampaignStatusFragment
        outcome
        ...CampaignOutcome_CampaignOutcomeFragment
        channel {
          name
        }
        campaignMechanism {
          __typename
          ... on DeploymentDeploy {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentStart {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentStop {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentDelete {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentUpgrade {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
            targetRelease {
              id
              version
            }
          }
        }
      }
    }
  }
`;

const CAMPAIGN_MECHANISM_LABELS: Record<string, string> = {
  DeploymentDeploy: "Deploy",
  DeploymentStart: "Start",
  DeploymentStop: "Stop",
  DeploymentDelete: "Delete",
  DeploymentUpgrade: "Upgrade",
};

type TableRecord = NonNullable<
  NonNullable<DeploymentCampaignsTable_CampaignEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.nameTitle"
        defaultMessage="Deployment Campaign Name"
        description="Title for the Name column of the Deployment Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.deploymentCampaignsEdit}
        params={{ deploymentCampaignId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("campaignMechanism.__typename", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.operationTypeTitle"
        defaultMessage="Operation type"
      />
    ),
    cell: ({ getValue }) => {
      const value = getValue();
      return CAMPAIGN_MECHANISM_LABELS[value] ?? value;
    },
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    cell: ({ row }) => <CampaignStatus campaignRef={row.original} />,
  }),
  columnHelper.accessor("outcome", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.outcomeTitle"
        defaultMessage="Outcome"
      />
    ),
    cell: ({ row }) => <CampaignOutcome campaignRef={row.original} />,
  }),
  columnHelper.accessor("channel.name", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.deploymentChannelNameTitle"
        defaultMessage="Channel"
        description="Title for the Channel column of the Deployment Campaigns table"
      />
    ),
  }),
  columnHelper.accessor("campaignMechanism.release.application.name", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.applicationNameTitle"
        defaultMessage="Application Name"
        description="Title for the Application Name column of the Deployment Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => {
      const mechanism = row.original.campaignMechanism;

      if (!mechanism || !("release" in mechanism)) {
        return null;
      }

      return (
        <Link
          route={Route.application}
          params={{
            applicationId: mechanism.release?.application?.id || "",
          }}
        >
          {getValue()}
        </Link>
      );
    },
  }),

  columnHelper.accessor("campaignMechanism.release.version", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.releaseVersionTitle"
        defaultMessage="Release Version"
        description="Title for the Release column of the Deployment Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => {
      const mechanism = row.original.campaignMechanism;

      if (!mechanism || !("release" in mechanism)) {
        return null;
      }

      return (
        <>
          <Link
            route={Route.release}
            params={{
              applicationId: mechanism.release?.application?.id || "",
              releaseId: mechanism.release?.id || "",
            }}
          >
            {getValue()}
          </Link>

          {mechanism?.__typename === "DeploymentUpgrade" && (
            <>
              <Icon icon="arrowRight" className="ms-2 me-2" />
              <Link
                route={Route.release}
                params={{
                  applicationId: mechanism.release?.application?.id || "",
                  releaseId: mechanism.targetRelease?.id || "",
                }}
              >
                {mechanism.targetRelease?.version}
              </Link>
            </>
          )}
        </>
      );
    },
  }),
];

type DeploymentCampaignsTableProps = {
  className?: string;
  deploymentCampaignsRef: DeploymentCampaignsTable_CampaignEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const DeploymentCampaignsTable = ({
  className,
  deploymentCampaignsRef,
  loading = false,
  onLoadMore,
}: DeploymentCampaignsTableProps) => {
  const deploymentCampaignsFragment = useFragment(
    CAMPAIGNS_TABLE_FRAGMENT,
    deploymentCampaignsRef || null,
  );

  const deploymentCampaigns = useMemo<TableRecord[]>(() => {
    return (
      _.compact(deploymentCampaignsFragment?.edges?.map((e) => e?.node)) ?? []
    );
  }, [deploymentCampaignsFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={deploymentCampaigns}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default DeploymentCampaignsTable;
