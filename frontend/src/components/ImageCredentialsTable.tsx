/*
 * This file is part of Edgehog.
 *
 * Copyright 2024, 2025 SECO Mind Srl
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

import type { ImageCredentialsTable_PaginationQuery } from "@/api/__generated__/ImageCredentialsTable_PaginationQuery.graphql";
import type {
  ImageCredentialsTable_imageCredentials_Fragment$key,
  ImageCredentialsTable_imageCredentials_Fragment$data,
} from "@/api/__generated__/ImageCredentialsTable_imageCredentials_Fragment.graphql";

import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import InfiniteTable from "./InfiniteTable";
import _ from "lodash";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const IMAGE_CREDENTIALS_FRAGMENT = graphql`
  fragment ImageCredentialsTable_imageCredentials_Fragment on RootQueryType
  @refetchable(queryName: "ImageCredentialsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "ImageCredentialsFilterInput" }) {
    listImageCredentials(first: $first, after: $after, filter: $filter)
      @connection(key: "ImageCredentialsTable_listImageCredentials") {
      edges {
        node {
          id
          label
          username
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    ImageCredentialsTable_imageCredentials_Fragment$data["listImageCredentials"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.ImageCredentialsTable.labelTitle"
        defaultMessage="Label"
      />
    ),
    cell: ({
      row: {
        original: { id: imageCredentialId },
      },
      getValue,
    }) => (
      <Link route={Route.imageCredentialsEdit} params={{ imageCredentialId }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("username", {
    header: () => (
      <FormattedMessage
        id="components.ImageCredentialsTable.usernameTitle"
        defaultMessage="Username"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
];

type ImageCredentialsTableProps = {
  className?: string;
  listImageCredentialsRef: ImageCredentialsTable_imageCredentials_Fragment$key;
  hideSearch?: boolean;
};

const ImageCredentialsTable = ({
  className,
  listImageCredentialsRef,
  hideSearch = false,
}: ImageCredentialsTableProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      ImageCredentialsTable_PaginationQuery,
      ImageCredentialsTable_imageCredentials_Fragment$key
    >(IMAGE_CREDENTIALS_FRAGMENT, listImageCredentialsRef);

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
                  { username: { ilike: `%${text}%` } },
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

  const loadNextImageCredentials = useCallback(() => {
    if (hasNext && !isLoadingNext) loadNext(RECORDS_TO_LOAD_NEXT);
  }, [hasNext, isLoadingNext, loadNext]);

  const imageCredentials: TableRecord[] = useMemo(() => {
    return (
      data.listImageCredentials?.edges
        ?.map((edge) => edge?.node)
        .filter(
          (node): node is TableRecord => node !== undefined && node !== null,
        ) ?? []
    );
  }, [data]);

  if (!data.listImageCredentials) return null;

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={imageCredentials}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextImageCredentials : undefined}
      setSearchText={hideSearch ? undefined : setSearchText}
    />
  );
};

export default ImageCredentialsTable;
