/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import { useCallback, useEffect, useMemo, useState } from "react";
import _ from "lodash";

import type { NetworksTable_PaginationQuery } from "@/api/__generated__/NetworksTable_PaginationQuery.graphql";
import type {
  NetworksTable_NetworkFragment$data,
  NetworksTable_NetworkFragment$key,
} from "@/api/__generated__/NetworksTable_NetworkFragment.graphql";

import { Link, Route } from "@/Navigation";
import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "./InfiniteTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const NETWORKS_TABLE_FRAGMENT = graphql`
  fragment NetworksTable_NetworkFragment on RootQueryType
  @refetchable(queryName: "NetworksTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "NetworkFilterInput" }) {
    networks(first: $first, after: $after, filter: $filter)
      @connection(key: "NetworksTable_networks") {
      edges {
        node {
          id
          label
          driver
          internal
          enableIpv6
          options
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<NetworksTable_NetworkFragment$data["networks"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.label"
        defaultMessage="Label"
        description="Title for the Label column of the networks table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.networksEdit} params={{ networkId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("driver", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.driverTitle"
        defaultMessage="Driver"
        description="Title for the Driver column of the networks table"
      />
    ),
  }),
  columnHelper.accessor("internal", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.internalTitle"
        defaultMessage="Internal"
        description="Title for the Internal column of the networks table"
      />
    ),
  }),
  columnHelper.accessor("enableIpv6", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.enableIpv6"
        defaultMessage="Enable IPv6"
        description="Title for the Enable IPv6 column of the networks table"
      />
    ),
  }),
];

type NetworksTableProps = {
  className?: string;
  networksRef: NetworksTable_NetworkFragment$key;
  hideSearch?: boolean;
};

const NetworksTable = ({
  className,
  networksRef,
  hideSearch = false,
}: NetworksTableProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      NetworksTable_PaginationQuery,
      NetworksTable_NetworkFragment$key
    >(NETWORKS_TABLE_FRAGMENT, networksRef);

  const [searchText, setSearchText] = useState<string | null>(null);
  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: {
                or: [
                  { label: { ilike: `%${text}%` } },
                  { driver: { ilike: `%${text}%` } },
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

  const loadNextVolumes = useCallback(() => {
    if (hasNext && !isLoadingNext) loadNext(RECORDS_TO_LOAD_NEXT);
  }, [hasNext, isLoadingNext, loadNext]);

  const volumes: TableRecord[] = useMemo(() => {
    return (
      data.networks?.edges
        ?.map((edge) => edge?.node)
        .filter(
          (node): node is TableRecord => node !== undefined && node !== null,
        ) ?? []
    );
  }, [data]);

  if (!data.networks) return null;

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={volumes}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextVolumes : undefined}
      setSearchText={hideSearch ? undefined : setSearchText}
    />
  );
};

export default NetworksTable;
