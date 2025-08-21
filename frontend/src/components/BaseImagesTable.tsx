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

import type { BaseImagesTable_PaginationQuery } from "api/__generated__/BaseImagesTable_PaginationQuery.graphql";
import type {
  BaseImagesTable_BaseImagesFragment$data,
  BaseImagesTable_BaseImagesFragment$key,
} from "api/__generated__/BaseImagesTable_BaseImagesFragment.graphql";

import { createColumnHelper } from "components/Table";
import InfiniteTable from "components/InfiniteTable";
import { Link, Route } from "Navigation";

const BASE_IMAGES_TO_LOAD_FIRST = 40;
const BASE_IMAGES_TO_LOAD_NEXT = 10;

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BASE_IMAGES_TABLE_FRAGMENT = graphql`
  fragment BaseImagesTable_BaseImagesFragment on BaseImageCollection
  @refetchable(queryName: "BaseImagesTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "BaseImageFilterInput" }) {
    id
    baseImages(first: $first, after: $after, filter: $filter)
      @connection(key: "BaseImagesTable_baseImages") {
      edges {
        node {
          id
          version
          startingVersionRequirement
          localizedReleaseDisplayNames {
            value
            languageTag
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<BaseImagesTable_BaseImagesFragment$data["baseImages"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const getColumnsDefinition = (baseImageCollectionId: string) => [
  columnHelper.accessor("version", {
    header: () => (
      <FormattedMessage
        id="components.BaseImagesTable.versionTitle"
        defaultMessage="Base Image Version"
        description="Title for the Version column of the base images table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.baseImagesEdit}
        params={{ baseImageCollectionId, baseImageId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("localizedReleaseDisplayNames", {
    header: () => (
      <FormattedMessage
        id="components.BaseImagesTable.releaseDisplayNameTitle"
        defaultMessage="Release Name"
        description="Title for the Release Name column of the base images table"
      />
    ),
    cell: ({ getValue }) => {
      // TODO: for now, only one translation can be present so we take it directly.
      const localizedReleaseDisplayNames = getValue();
      return (
        <span>
          {localizedReleaseDisplayNames?.length &&
            localizedReleaseDisplayNames[0].value}
        </span>
      );
    },
  }),
  columnHelper.accessor("startingVersionRequirement", {
    header: () => (
      <FormattedMessage
        id="components.BaseImagesTable.startingVersionRequirementTitle"
        defaultMessage="Supported Starting Versions"
        description="Title for the Supported Starting Versions column of the base images table"
      />
    ),
  }),
];

type Props = {
  className?: string;
  baseImageCollectionRef: BaseImagesTable_BaseImagesFragment$key;
  hideSearch?: boolean;
};

const BaseImagesTable = ({
  className,
  baseImageCollectionRef,
  hideSearch = false,
}: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    BaseImagesTable_PaginationQuery,
    BaseImagesTable_BaseImagesFragment$key
  >(BASE_IMAGES_TABLE_FRAGMENT, baseImageCollectionRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const columns = useMemo(
    () => getColumnsDefinition(paginationData.id),
    [paginationData.id],
  );

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: BASE_IMAGES_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: BASE_IMAGES_TO_LOAD_FIRST,
              filter: {
                or: [
                  { version: { ilike: `%${text}%` } },
                  { url: { ilike: `%${text}%` } },
                  {
                    startingVersionRequirement: {
                      ilike: `%${text}%`,
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

  const loadNextBaseImageCollections = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(BASE_IMAGES_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const baseImages = useMemo(() => {
    return (
      paginationData.baseImages?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.baseImages) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={baseImages}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextBaseImageCollections : undefined}
      setSearchText={setSearchText}
      hideSearch={hideSearch}
    />
  );
};

export default BaseImagesTable;
