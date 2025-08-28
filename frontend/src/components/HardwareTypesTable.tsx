/*
  This file is part of Edgehog.

  Copyright 2021-2025 SECO Mind Srl

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

import type { HardwareTypesTable_PaginationQuery } from "api/__generated__/HardwareTypesTable_PaginationQuery.graphql";
import type {
  HardwareTypesTable_HardwareTypesFragment$key,
  HardwareTypesTable_HardwareTypesFragment$data,
} from "api/__generated__/HardwareTypesTable_HardwareTypesFragment.graphql";

import { createColumnHelper } from "components/Table";
import InfiniteTable from "./InfiniteTable";
import { Link, Route } from "Navigation";

const HARDWARE_TYPES_TO_LOAD_FIRST = 40;
const HARDWARE_TYPES_TO_LOAD_NEXT = 10;

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const HARDWARE_TYPES_TABLE_FRAGMENT = graphql`
  fragment HardwareTypesTable_HardwareTypesFragment on RootQueryType
  @refetchable(queryName: "HardwareTypesTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "HardwareTypeFilterInput" }) {
    hardwareTypes(first: $first, after: $after, filter: $filter)
      @connection(key: "HardwareTypesTable_hardwareTypes") {
      edges {
        node {
          id
          handle
          name
          partNumbers {
            edges {
              node {
                partNumber
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
    HardwareTypesTable_HardwareTypesFragment$data["hardwareTypes"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.HardwareTypesTable.nameTitle"
        defaultMessage="Hardware Type Name"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.hardwareTypesEdit}
        params={{ hardwareTypeId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.HardwareTypesTable.handleTitle"
        defaultMessage="Handle"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor("partNumbers", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.HardwareTypesTable.partNumbersTitle"
        defaultMessage="Part Numbers"
      />
    ),
    cell: ({ getValue }) =>
      getValue().edges?.map(({ node: { partNumber } }, index) => (
        <React.Fragment key={partNumber}>
          {index > 0 && ", "}
          <span className="text-nowrap">{partNumber}</span>
        </React.Fragment>
      )),
  }),
];

type Props = {
  className?: string;
  hardwareTypesRef: HardwareTypesTable_HardwareTypesFragment$key;
};

const HardwareTypesTable = ({ className, hardwareTypesRef }: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    HardwareTypesTable_PaginationQuery,
    HardwareTypesTable_HardwareTypesFragment$key
  >(HARDWARE_TYPES_TABLE_FRAGMENT, hardwareTypesRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: HARDWARE_TYPES_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: HARDWARE_TYPES_TO_LOAD_FIRST,
              filter: {
                or: [
                  { name: { ilike: `%${text}%` } },
                  { handle: { ilike: `%${text}%` } },
                  {
                    partNumbers: {
                      partNumber: {
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

  const loadNextHardwareTypes = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(HARDWARE_TYPES_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const hardwareTypes = useMemo(() => {
    return (
      paginationData.hardwareTypes?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.hardwareTypes) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={hardwareTypes}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextHardwareTypes : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default HardwareTypesTable;
