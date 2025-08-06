/*
  This file is part of Edgehog.

  Copyright 2023-2025 SECO Mind Srl

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

import type { UpdateCampaignsTable_PaginationQuery } from "api/__generated__/UpdateCampaignsTable_PaginationQuery.graphql";
import type {
  UpdateCampaignsTable_UpdateCampaignFragment$data,
  UpdateCampaignsTable_UpdateCampaignFragment$key,
} from "api/__generated__/UpdateCampaignsTable_UpdateCampaignFragment.graphql";

import UpdateCampaignOutcome from "components/UpdateCampaignOutcome";
import UpdateCampaignStatus from "components/UpdateCampaignStatus";
import { createColumnHelper } from "components/Table";
import InfiniteTable from "./InfiniteTable";
import { Link, Route } from "Navigation";

const UPDATE_CAMPAIGNS_TO_LOAD_FIRST = 40;
const UPDATE_CAMPAIGNS_TO_LOAD_NEXT = 10;
// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const UPDATE_CAMPAIGNS_TABLE_FRAGMENT = graphql`
  fragment UpdateCampaignsTable_UpdateCampaignFragment on RootQueryType
  @refetchable(queryName: "UpdateCampaignsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "UpdateCampaignFilterInput" }) {
    updateCampaigns(first: $first, after: $after, filter: $filter)
      @connection(key: "UpdateCampaignsTable_updateCampaigns") {
      edges {
        node {
          id
          name
          status
          ...UpdateCampaignStatus_UpdateCampaignStatusFragment
          outcome
          ...UpdateCampaignOutcome_UpdateCampaignOutcomeFragment
          baseImage {
            name
            baseImageCollection {
              name
            }
          }
          updateChannel {
            name
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    UpdateCampaignsTable_UpdateCampaignFragment$data["updateCampaigns"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.nameTitle"
        defaultMessage="Update Campaign Name"
        description="Title for the Name column of the Update Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.updateCampaignsEdit}
        params={{ updateCampaignId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    cell: ({ row }) => (
      <UpdateCampaignStatus updateCampaignRef={row.original} />
    ),
  }),
  columnHelper.accessor("outcome", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.outcomeTitle"
        defaultMessage="Outcome"
      />
    ),
    cell: ({ row }) => (
      <UpdateCampaignOutcome updateCampaignRef={row.original} />
    ),
  }),
  columnHelper.accessor("updateChannel.name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.updateChannelNameTitle"
        defaultMessage="Update Channel"
        description="Title for the Update Channel column of the Update Campaigns table"
      />
    ),
  }),
  columnHelper.accessor("baseImage.baseImageCollection.name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.baseImageCollectionNameTitle"
        defaultMessage="Base Image Collection"
        description="Title for the Base Image Collection column of the Update Campaigns table"
      />
    ),
  }),
  columnHelper.accessor("baseImage.name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.baseImageTitle"
        defaultMessage="Base Image"
        description="Title for the Base Image column of the Update Campaigns table"
      />
    ),
  }),
];

type Props = {
  className?: string;
  updateCampaignsData: UpdateCampaignsTable_UpdateCampaignFragment$key;
};

const UpdateCampaignsTable = ({ className, updateCampaignsData }: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    UpdateCampaignsTable_PaginationQuery,
    UpdateCampaignsTable_UpdateCampaignFragment$key
  >(UPDATE_CAMPAIGNS_TABLE_FRAGMENT, updateCampaignsData);
  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(() => {
    const enumStatuses = ["FINISHED", "IDLE", "IN_PROGRESS"] as const;
    const enumOutcomes = ["FAILURE", "SUCCESS"] as const;

    type UpdateCampaignStatus = (typeof enumStatuses)[number];
    type UpdateCampaignOutcome = (typeof enumOutcomes)[number];

    const isEnumStatus = (value: string): value is UpdateCampaignStatus =>
      enumStatuses.includes(value.toUpperCase() as UpdateCampaignStatus);

    const isEnumOutcome = (value: string): value is UpdateCampaignOutcome =>
      enumOutcomes.includes(value.toUpperCase() as UpdateCampaignOutcome);

    return _.debounce((text: string) => {
      if (text === "") {
        refetch(
          {
            first: UPDATE_CAMPAIGNS_TO_LOAD_FIRST,
          },
          { fetchPolicy: "network-only" },
        );
      } else {
        const likeText = `%${text}%`;
        const normalizedText = text.toUpperCase();

        const filters: any[] = [
          { name: { ilike: likeText } },
          {
            baseImage: {
              version: { ilike: likeText },
              localizedReleaseDisplayNames: {
                value: { ilike: likeText },
              },
              baseImageCollection: {
                name: { ilike: likeText },
              },
            },
          },
          {
            updateChannel: {
              name: { ilike: likeText },
            },
          },
        ];

        if (isEnumStatus(normalizedText)) {
          filters.push({
            status: { eq: normalizedText as UpdateCampaignStatus },
          });
        }

        if (isEnumOutcome(normalizedText)) {
          filters.push({
            outcome: { eq: normalizedText as UpdateCampaignOutcome },
          });
        }

        refetch(
          {
            first: UPDATE_CAMPAIGNS_TO_LOAD_FIRST,
            filter: {
              or: filters,
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

  const loadNextUpdateCampaigns = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(UPDATE_CAMPAIGNS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const updateCampaigns = useMemo(() => {
    return (
      paginationData.updateCampaigns?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.updateCampaigns) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={updateCampaigns}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextUpdateCampaigns : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default UpdateCampaignsTable;
