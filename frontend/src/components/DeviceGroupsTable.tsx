/*
  This file is part of Edgehog.

  Copyright 2022-2025 SECO Mind Srl

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

import type { DeviceGroupsTable_PaginationQuery } from "api/__generated__/DeviceGroupsTable_PaginationQuery.graphql";
import type {
  DeviceGroupsTable_DeviceGroupFragment$data,
  DeviceGroupsTable_DeviceGroupFragment$key,
} from "api/__generated__/DeviceGroupsTable_DeviceGroupFragment.graphql";

import { createColumnHelper } from "components/Table";
import InfiniteTable from "components/InfiniteTable";
import { Link, Route } from "Navigation";

const DEVICE_GROUPS_TO_LOAD_FIRST = 40;
const DEVICE_GROUPS_TO_LOAD_NEXT = 10;

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment DeviceGroupsTable_DeviceGroupFragment on RootQueryType
  @refetchable(queryName: "DeviceGroupsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "DeviceGroupFilterInput" }) {
    deviceGroups(first: $first, after: $after, filter: $filter)
      @connection(key: "DeviceGroupsTable_deviceGroups") {
      edges {
        node {
          id
          name
          handle
          selector
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    DeviceGroupsTable_DeviceGroupFragment$data["deviceGroups"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.nameTitle"
        defaultMessage="Group Name"
        description="Title for the Name column of the device groups table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.deviceGroupsEdit}
        params={{ deviceGroupId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the device groups table"
      />
    ),
  }),
  columnHelper.accessor("selector", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.selectorTitle"
        defaultMessage="Selector"
        description="Title for the Selector column of the device groups table"
      />
    ),
  }),
];

type Props = {
  className?: string;
  deviceGroupsRef: DeviceGroupsTable_DeviceGroupFragment$key;
  hideSearch?: boolean;
};

const DeviceGroupsTable = ({
  className,
  deviceGroupsRef,
  hideSearch = false,
}: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    DeviceGroupsTable_PaginationQuery,
    DeviceGroupsTable_DeviceGroupFragment$key
  >(DEVICE_GROUPS_TABLE_FRAGMENT, deviceGroupsRef);
  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: DEVICE_GROUPS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: DEVICE_GROUPS_TO_LOAD_FIRST,
              filter: {
                or: [
                  { name: { ilike: `%${text}%` } },
                  { handle: { ilike: `%${text}%` } },
                  { selector: { ilike: `%${text}%` } },
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

  const loadNextDeviceGroups = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(DEVICE_GROUPS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deviceGroups = useMemo(() => {
    return (
      paginationData.deviceGroups?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.deviceGroups) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={deviceGroups}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDeviceGroups : undefined}
      setSearchText={setSearchText}
      hideSearch={hideSearch}
    />
  );
};

export default DeviceGroupsTable;
