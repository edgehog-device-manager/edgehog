// This file is part of Edgehog.
//
// Copyright 2023-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import compact from "lodash/compact";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ChannelsTable_ChannelEdgeFragment$data,
  ChannelsTable_ChannelEdgeFragment$key,
} from "@/api/__generated__/ChannelsTable_ChannelEdgeFragment.graphql";

import { Link, Route } from "@/Navigation";
import { createColumnHelper } from "@/components/ui/table/Table";
import Tag from "@/components/ui/tag/Tag";
import InfiniteTable from "@/components/ui/infinite-table/InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CHANNELS_TABLE_FRAGMENT = graphql`
  fragment ChannelsTable_ChannelEdgeFragment on ChannelConnection {
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
`;

type TableRecord = NonNullable<
  NonNullable<ChannelsTable_ChannelEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.fleet.channels.channels-table.ChannelsTable.nameTitle"
        defaultMessage="Channel Name"
        description="Title for the Name column of the channels table"
      />
    ),
    meta: {
      label: "Channel Name",
      isPrimaryLink: true,
      getLink: (row, children) => (
        <Link
          route={Route.channelsEdit}
          params={{ channelId: row.original.id }}
          className="row-link"
          onClick={(e) => e.stopPropagation()}
        >
          {children}
        </Link>
      ),
    },
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.fleet.channels.channels-table.ChannelsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the channels table"
      />
    ),
  }),
  columnHelper.accessor("targetGroups", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.fleet.channels.channels-table.ChannelsTable.targetGroupsTitle"
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
  channelsRef: ChannelsTable_ChannelEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onSearchChange?: (text: string) => void;
  searchText?: string;
};

const ChannelsTable = ({
  className,
  channelsRef,
  loading = false,
  onLoadMore,
  onSearchChange,
  searchText,
}: Props) => {
  const channelsFragment = useFragment(
    CHANNELS_TABLE_FRAGMENT,
    channelsRef || null,
  );

  const channels = useMemo<TableRecord[]>(() => {
    return compact(channelsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [channelsFragment]);
  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={channels}
      loading={loading}
      searchText={searchText ?? ""}
      onSearchChange={onSearchChange}
      onLoadMore={onLoadMore}
      columnVisibilityKey="channels-table"
    />
  );
};

export default ChannelsTable;
