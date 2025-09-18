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

import type { ChannelsTable_PaginationQuery } from "api/__generated__/ChannelsTable_PaginationQuery.graphql";
import type {
  ChannelsTable_ChannelFragment$data,
  ChannelsTable_ChannelFragment$key,
} from "api/__generated__/ChannelsTable_ChannelFragment.graphql";

import { createColumnHelper } from "components/Table";
import InfiniteTable from "./InfiniteTable";
import { Link, Route } from "Navigation";
import Tag from "components/Tag";

const CHANNELS_TO_LOAD_FIRST = 40;
const CHANNELS_TO_LOAD_NEXT = 10;
// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment ChannelsTable_ChannelFragment on RootQueryType
  @refetchable(queryName: "ChannelsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "ChannelFilterInput" }) {
    channels(first: $first, after: $after, filter: $filter)
      @connection(key: "ChannelsTable_channels") {
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
  NonNullable<ChannelsTable_ChannelFragment$data["channels"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.ChannelsTable.nameTitle"
        defaultMessage="Channel Name"
        description="Title for the Name column of the channels table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.channelsEdit} params={{ channelId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.ChannelsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the channels table"
      />
    ),
  }),
  columnHelper.accessor("targetGroups", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.ChannelsTable.targetGroupsTitle"
        defaultMessage="Target Groups"
        description="Title for the Target Groups column of the channels table"
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
  channelsRef: ChannelsTable_ChannelFragment$key;
};

const ChannelsTable = ({ className, channelsRef }: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    ChannelsTable_PaginationQuery,
    ChannelsTable_ChannelFragment$key
  >(DEVICE_GROUPS_TABLE_FRAGMENT, channelsRef);
  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: CHANNELS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: CHANNELS_TO_LOAD_FIRST,
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

  const loadNextChannels = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(CHANNELS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const channels = useMemo(() => {
    return (
      paginationData.channels?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.channels) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={channels}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextChannels : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default ChannelsTable;
