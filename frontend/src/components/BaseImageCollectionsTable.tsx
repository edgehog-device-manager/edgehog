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

import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { BaseImageCollectionsTable_PaginationQuery } from "api/__generated__/BaseImageCollectionsTable_PaginationQuery.graphql";
import type {
  BaseImageCollectionsTable_BaseImageCollectionFragment$data,
  BaseImageCollectionsTable_BaseImageCollectionFragment$key,
} from "api/__generated__/BaseImageCollectionsTable_BaseImageCollectionFragment.graphql";

import Table, { createColumnHelper } from "components/Table";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BASE_IMAGE_COLLECTIONS_TABLE_FRAGMENT = graphql`
  fragment BaseImageCollectionsTable_BaseImageCollectionFragment on RootQueryType
  @refetchable(queryName: "BaseImageCollectionsTable_PaginationQuery") {
    baseImageCollections(first: $first, after: $after)
      @connection(key: "BaseImageCollectionsTable_baseImageCollections") {
      edges {
        node {
          id
          name
          handle
          systemModel {
            name
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    BaseImageCollectionsTable_BaseImageCollectionFragment$data["baseImageCollections"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.BaseImageCollectionsTable.nameTitle"
        defaultMessage="Base Image Collection Name"
        description="Title for the Name column of the base image collections table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.baseImageCollectionsEdit}
        params={{ baseImageCollectionId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.BaseImageCollectionsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the base image collections table"
      />
    ),
  }),
  columnHelper.accessor((row) => row.systemModel?.name, {
    id: "systemModel",
    header: () => (
      <FormattedMessage
        id="components.BaseImageCollectionsTable.systemModelTitle"
        defaultMessage="System Model"
        description="Title for the System Model column of the base image collections table"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
];

type Props = {
  className?: string;
  baseImageCollectionsRef: BaseImageCollectionsTable_BaseImageCollectionFragment$key;
};

const BaseImageCollectionsTable = ({
  className,
  baseImageCollectionsRef,
}: Props) => {
  const { data } = usePaginationFragment<
    BaseImageCollectionsTable_PaginationQuery,
    BaseImageCollectionsTable_BaseImageCollectionFragment$key
  >(BASE_IMAGE_COLLECTIONS_TABLE_FRAGMENT, baseImageCollectionsRef);

  const tableData =
    data.baseImageCollections?.edges?.map((edge) => edge.node) ?? [];

  return <Table className={className} columns={columns} data={tableData} />;
};

export default BaseImageCollectionsTable;
