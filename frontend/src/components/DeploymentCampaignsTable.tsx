/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import _ from "lodash";

import type { DeploymentCampaignsTable_PaginationQuery } from "api/__generated__/DeploymentCampaignsTable_PaginationQuery.graphql";
import type {
  DeploymentCampaignsTable_DeploymentCampaignFragment$data,
  DeploymentCampaignsTable_DeploymentCampaignFragment$key,
} from "api/__generated__/DeploymentCampaignsTable_DeploymentCampaignFragment.graphql";

import DeploymentCampaignOutcome from "components/DeploymentCampaignOutcome";
import DeploymentCampaignStatus from "components/DeploymentCampaignStatus";
import { createColumnHelper } from "components/Table";
import InfiniteTable from "components/InfiniteTable";
import { Link, Route } from "Navigation";
import Icon from "components/Icon";

const DEPLOYMENT_CAMPAIGNS_TO_LOAD_FIRST = 40;
const DEPLOYMENT_CAMPAIGNS_TO_LOAD_NEXT = 10;

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEPLOYMENT_CAMPAIGNS_TABLE_FRAGMENT = graphql`
  fragment DeploymentCampaignsTable_DeploymentCampaignFragment on RootQueryType
  @refetchable(queryName: "DeploymentCampaignsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "DeploymentCampaignFilterInput" }) {
    deploymentCampaigns(first: $first, after: $after, filter: $filter)
      @connection(key: "DeploymentCampaignsTable_deploymentCampaigns") {
      edges {
        node {
          id
          name
          status
          operationType
          ...DeploymentCampaignStatus_DeploymentCampaignStatusFragment
          outcome
          ...DeploymentCampaignOutcome_DeploymentCampaignOutcomeFragment
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
          channel {
            name
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    DeploymentCampaignsTable_DeploymentCampaignFragment$data["deploymentCampaigns"]
  >["edges"]
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
  columnHelper.accessor("operationType", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.operationTypeTitle"
        defaultMessage="Operation type"
      />
    ),
    cell: ({ getValue }) => {
      const value = getValue();
      return value.charAt(0) + value.slice(1).toLowerCase();
    },
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    cell: ({ row }) => (
      <DeploymentCampaignStatus deploymentCampaignRef={row.original} />
    ),
  }),
  columnHelper.accessor("outcome", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.outcomeTitle"
        defaultMessage="Outcome"
      />
    ),
    cell: ({ row }) => (
      <DeploymentCampaignOutcome deploymentCampaignRef={row.original} />
    ),
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
  columnHelper.accessor("release.application.name", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.applicationNameTitle"
        defaultMessage="Application Name"
        description="Title for the Application Name column of the Deployment Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.application}
        params={{ applicationId: row.original.release?.application?.id || "" }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("release.version", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentCampaignsTable.releaseNameTitle"
        defaultMessage="Release Version"
        description="Title for the Release column of the Deployment Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => (
      <>
        <Link
          route={Route.release}
          params={{
            applicationId: row.original.release?.application?.id || "",
            releaseId: row.original.release?.id || "",
          }}
        >
          {getValue()}
        </Link>
        {row.original.operationType == "UPGRADE" && (
          <>
            <Icon icon={"arrowRight"} className="ms-2 me-2" />
            <Link
              route={Route.release}
              params={{
                applicationId: row.original.release?.application?.id || "",
                releaseId: row.original.targetRelease?.id || "",
              }}
            >
              {row.original.targetRelease?.version}
            </Link>
          </>
        )}
      </>
    ),
  }),
];

type Props = {
  className?: string;
  deploymentCampaignsData: DeploymentCampaignsTable_DeploymentCampaignFragment$key;
};

const DeploymentCampaignsTable = ({
  className,
  deploymentCampaignsData,
}: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    DeploymentCampaignsTable_PaginationQuery,
    DeploymentCampaignsTable_DeploymentCampaignFragment$key
  >(DEPLOYMENT_CAMPAIGNS_TABLE_FRAGMENT, deploymentCampaignsData);
  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(() => {
    const enumStatuses = ["FINISHED", "IDLE", "IN_PROGRESS"] as const;
    const enumOutcomes = ["FAILURE", "SUCCESS"] as const;

    const findMatches = <T extends readonly string[]>(
      enums: T,
      searchText: string,
    ): T[number][] =>
      enums.filter((value) =>
        value.toLowerCase().includes(searchText.toLowerCase()),
      );

    return _.debounce((text: string) => {
      if (text === "") {
        refetch(
          {
            first: DEPLOYMENT_CAMPAIGNS_TO_LOAD_FIRST,
          },
          { fetchPolicy: "network-only" },
        );
      } else {
        refetch(
          {
            first: DEPLOYMENT_CAMPAIGNS_TO_LOAD_FIRST,
            filter: {
              or: [
                { name: { ilike: `%${text}%` } },
                {
                  release: {
                    version: { ilike: `%${text}%` },
                  },
                },
                {
                  channel: {
                    name: { ilike: `%${text}%` },
                  },
                },
                ...findMatches(enumStatuses, text).map((status) => ({
                  status: { eq: status },
                })),
                ...findMatches(enumOutcomes, text).map((outcome) => ({
                  outcome: { eq: outcome },
                })),
              ],
            },
          },
          { fetchPolicy: "network-only" },
        );
      }
    }, 500);
  }, [refetch]);

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextDeploymentCampaigns = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(DEPLOYMENT_CAMPAIGNS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deploymentCampaigns = useMemo(() => {
    return (
      paginationData.deploymentCampaigns?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.deploymentCampaigns) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={deploymentCampaigns}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDeploymentCampaigns : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default DeploymentCampaignsTable;
