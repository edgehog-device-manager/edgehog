// This file is part of Edgehog.
//
// Copyright 2024-2026 SECO Mind Srl
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

import compact from "lodash/compact";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ContainersTable_ContainerEdgeFragment$data,
  ContainersTable_ContainerEdgeFragment$key,
} from "@/api/__generated__/ContainersTable_ContainerEdgeFragment.graphql";

import { Link, Route } from "@/Navigation";
import { createColumnHelper } from "@tanstack/react-table";
import InfiniteTable from "./InfiniteTable";

/* eslint-disable relay/unused-fields */
const CONTAINERS_TABLE_FRAGMENT = graphql`
  fragment ContainersTable_ContainerEdgeFragment on ContainerConnection {
    edges {
      node {
        id
        name
        image {
          reference
          credentials {
            id
            label
            username
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<ContainersTable_ContainerEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.ContainersTable.Name"
        defaultMessage="Name"
        description="Title for the Name column of the containers table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.containersEdit}
        params={{ containerId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("image.reference", {
    header: () => (
      <FormattedMessage
        id="components.ContainersTable.imageTitle"
        defaultMessage="Image"
        description="Title for the Image column of the containers table"
      />
    ),
  }),
];

type ContainersTableProps = {
  className?: string;
  containersRef: ContainersTable_ContainerEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const ContainersTable = ({
  className,
  containersRef,
  loading = false,
  onLoadMore,
}: ContainersTableProps) => {
  const containersFragment = useFragment(
    CONTAINERS_TABLE_FRAGMENT,
    containersRef || null,
  );

  const containers = useMemo<TableRecord[]>(() => {
    return compact(containersFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [containersFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={containers}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default ContainersTable;
