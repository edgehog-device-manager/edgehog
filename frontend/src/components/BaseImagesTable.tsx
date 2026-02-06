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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  BaseImagesTable_BaseImageEdgeFragment$data,
  BaseImagesTable_BaseImageEdgeFragment$key,
} from "@/api/__generated__/BaseImagesTable_BaseImageEdgeFragment.graphql";

import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BASE_IMAGES_TABLE_FRAGMENT = graphql`
  fragment BaseImagesTable_BaseImageEdgeFragment on BaseImageConnection {
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
`;

type TableRecord = NonNullable<
  NonNullable<BaseImagesTable_BaseImageEdgeFragment$data>["edges"]
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
  baseImagesRef: BaseImagesTable_BaseImageEdgeFragment$key;
  baseImageCollectionId: string;
  loading?: boolean;
  onLoadMore?: () => void;
};

const BaseImagesTable = ({
  className,
  baseImagesRef,
  baseImageCollectionId,
  loading = false,
  onLoadMore,
}: Props) => {
  const baseImagesFragment = useFragment(
    BASE_IMAGES_TABLE_FRAGMENT,
    baseImagesRef || null,
  );
  const baseImages = useMemo<TableRecord[]>(() => {
    return _.compact(baseImagesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [baseImagesFragment]);

  const columns = useMemo(
    () => getColumnsDefinition(baseImageCollectionId),
    [baseImageCollectionId],
  );

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={baseImages}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default BaseImagesTable;
