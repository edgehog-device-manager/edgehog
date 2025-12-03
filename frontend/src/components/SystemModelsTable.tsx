/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2025 SECO Mind Srl
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

import React, { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import _ from "lodash";

import type { SystemModelsTable_PaginationQuery } from "@/api/__generated__/SystemModelsTable_PaginationQuery.graphql";
import type {
  SystemModelsTable_SystemModelsFragment$key,
  SystemModelsTable_SystemModelsFragment$data,
} from "@/api/__generated__/SystemModelsTable_SystemModelsFragment.graphql";

import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "./InfiniteTable";
import { Link, Route } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const SYSTEM_MODELS_TABLE_FRAGMENT = graphql`
  fragment SystemModelsTable_SystemModelsFragment on RootQueryType
  @refetchable(queryName: "SystemModelsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "SystemModelFilterInput" }) {
    systemModels(first: $first, after: $after, filter: $filter)
      @connection(key: "SystemModelsTable_systemModels") {
      edges {
        node {
          id
          handle
          name
          hardwareType {
            name
          }
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
    SystemModelsTable_SystemModelsFragment$data["systemModels"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.nameTitle"
        defaultMessage="System Model Name"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.systemModelsEdit}
        params={{ systemModelId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.handleTitle"
        defaultMessage="Handle"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor((row) => row.hardwareType?.name, {
    id: "hardwareType",
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.hardwareType"
        defaultMessage="Hardware Type"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor("partNumbers", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.partNumbersTitle"
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
    enableSorting: false,
  }),
];

type Props = {
  className?: string;
  systemModelsRef: SystemModelsTable_SystemModelsFragment$key;
};

const SystemModelsTable = ({ className, systemModelsRef }: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    SystemModelsTable_PaginationQuery,
    SystemModelsTable_SystemModelsFragment$key
  >(SYSTEM_MODELS_TABLE_FRAGMENT, systemModelsRef);
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
                  { name: { ilike: `%${text}%` } },
                  { handle: { ilike: `%${text}%` } },
                  {
                    partNumbers: {
                      partNumber: {
                        ilike: `%${text}%`,
                      },
                    },
                  },
                  {
                    hardwareType: {
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

  const loadNextSystemModels = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const hardwareTypes = useMemo(() => {
    return (
      paginationData.systemModels?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.systemModels) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={hardwareTypes}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextSystemModels : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default SystemModelsTable;
