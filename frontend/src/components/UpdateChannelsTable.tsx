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

import React, { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import _ from "lodash";

import type { UpdateChannelsTable_PaginationQuery } from "api/__generated__/UpdateChannelsTable_PaginationQuery.graphql";
import type {
  UpdateChannelsTable_UpdateChannelFragment$data,
  UpdateChannelsTable_UpdateChannelFragment$key,
} from "api/__generated__/UpdateChannelsTable_UpdateChannelFragment.graphql";

import { createColumnHelper } from "components/Table";
import InfiniteTable from "./InfiniteTable";
import { Link, Route } from "Navigation";
import Tag from "components/Tag";

const UPDATE_CHANNELS_TO_LOAD_FIRST = 40;
const UPDATE_CHANNELS_TO_LOAD_NEXT = 10;
// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment UpdateChannelsTable_UpdateChannelFragment on RootQueryType
  @refetchable(queryName: "UpdateChannelsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "UpdateChannelFilterInput" }) {
    updateChannels(first: $first, after: $after, filter: $filter)
      @connection(key: "UpdateChannelsTable_updateChannels") {
      edges {
        node {
          id
          name
          handle
          targetGroups {
            edges {
              node {
                name
              }
            }
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    UpdateChannelsTable_UpdateChannelFragment$data["updateChannels"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateChannelsTable.nameTitle"
        defaultMessage="Update Channel Name"
        description="Title for the Name column of the update channels table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.updateChannelsEdit}
        params={{ updateChannelId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.UpdateChannelsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the update channels table"
      />
    ),
  }),
  columnHelper.accessor("targetGroups", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.UpdateChannelsTable.targetGroupsTitle"
        defaultMessage="Target Groups"
        description="Title for the Target Groups column of the update channels table"
      />
    ),
    cell: ({ getValue }) => (
      <>
        {getValue().edges?.map(({ node: group }) => (
          <Tag key={group.name} className="me-2">
            {group.name}
          </Tag>
        ))}
      </>
    ),
  }),
];

type Props = {
  className?: string;
  updateChannelsRef: UpdateChannelsTable_UpdateChannelFragment$key;
};

const UpdateChannelsTable = ({ className, updateChannelsRef }: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    UpdateChannelsTable_PaginationQuery,
    UpdateChannelsTable_UpdateChannelFragment$key
  >(DEVICE_GROUPS_TABLE_FRAGMENT, updateChannelsRef);
  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: UPDATE_CHANNELS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: UPDATE_CHANNELS_TO_LOAD_FIRST,
              filter: {
                or: [
                  { name: { ilike: `%${text}%` } },
                  { handle: { ilike: `%${text}%` } },
                  {
                    targetGroups: {
                      name: {
                        ilike: `%${text}%`,
                      },
                    },
                  },
                ],
              },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextUpdateChannels = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(UPDATE_CHANNELS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const updateChannels = useMemo(() => {
    return (
      paginationData.updateChannels?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.updateChannels) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={updateChannels}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextUpdateChannels : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default UpdateChannelsTable;
