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

import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { BaseImagesTable_PaginationQuery } from "api/__generated__/BaseImagesTable_PaginationQuery.graphql";
import type {
  BaseImagesTable_BaseImagesFragment$data,
  BaseImagesTable_BaseImagesFragment$key,
} from "api/__generated__/BaseImagesTable_BaseImagesFragment.graphql";

import Table, { createColumnHelper } from "components/Table";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BASE_IMAGES_TABLE_FRAGMENT = graphql`
  fragment BaseImagesTable_BaseImagesFragment on BaseImageCollection
  @refetchable(queryName: "BaseImagesTable_PaginationQuery") {
    id
    baseImages(first: $first, after: $after)
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
  const { data } = usePaginationFragment<
    BaseImagesTable_PaginationQuery,
    BaseImagesTable_BaseImagesFragment$key
  >(BASE_IMAGES_TABLE_FRAGMENT, baseImageCollectionRef);

  const tableData = data.baseImages?.edges?.map((edge) => edge.node) ?? [];

  const columns = useMemo(() => getColumnsDefinition(data.id), [data.id]);

  return (
    <Table
      className={className}
      columns={columns}
      data={tableData}
      hideSearch={hideSearch}
    />
  );
};

export default BaseImagesTable;
