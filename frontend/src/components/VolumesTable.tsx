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

import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import { useCallback, useEffect, useMemo, useState } from "react";
import _ from "lodash";

import type { VolumesTable_PaginationQuery } from "../api/__generated__/VolumesTable_PaginationQuery.graphql";
import type {
  VolumesTable_VolumeFragment$data,
  VolumesTable_VolumeFragment$key,
} from "api/__generated__/VolumesTable_VolumeFragment.graphql";

import { Link, Route } from "Navigation";
import { createColumnHelper } from "components/Table";
import InfiniteTable from "./InfiniteTable";

const VOLUMES_TO_LOAD_FIRST = 40;
const VOLUMES_TO_LOAD_NEXT = 10;

const VOLUMES_TABLE_FRAGMENT = graphql`
  fragment VolumesTable_VolumeFragment on RootQueryType
  @refetchable(queryName: "VolumesTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "VolumeFilterInput" }) {
    volumes(first: $first, after: $after, filter: $filter)
      @connection(key: "VolumesTable_volumes") {
      edges {
        node {
          id
          label
          driver
          options
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<VolumesTable_VolumeFragment$data["volumes"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.VolumesTable.label"
        defaultMessage="Label"
        description="Title for the Label column of the volumes table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.volumeEdit} params={{ volumeId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("driver", {
    header: () => (
      <FormattedMessage
        id="components.VolumesTable.driverTitle"
        defaultMessage="Driver"
        description="Title for the Driver column of the volumes table"
      />
    ),
  }),
];

type VolumesTableProps = {
  className?: string;
  volumesRef: VolumesTable_VolumeFragment$key;
  hideSearch?: boolean;
};

const VolumesTable = ({
  className,
  volumesRef,
  hideSearch = false,
}: VolumesTableProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      VolumesTable_PaginationQuery,
      VolumesTable_VolumeFragment$key
    >(VOLUMES_TABLE_FRAGMENT, volumesRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: VOLUMES_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: VOLUMES_TO_LOAD_FIRST,
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
    if (hasNext && !isLoadingNext) loadNext(VOLUMES_TO_LOAD_NEXT);
  }, [hasNext, isLoadingNext, loadNext]);

  const volumes: TableRecord[] = useMemo(() => {
    return (
      data.volumes?.edges
        ?.map((edge) => edge?.node)
        .filter(
          (node): node is TableRecord => node !== undefined && node !== null,
        ) ?? []
    );
  }, [data]);

  if (!data.volumes) return null;

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

export default VolumesTable;
