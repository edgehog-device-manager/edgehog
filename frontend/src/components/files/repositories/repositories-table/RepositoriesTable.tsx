// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
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
  RepositoriesTable_RepositoryEdgeFragment$data,
  RepositoriesTable_RepositoryEdgeFragment$key,
} from "@/api/__generated__/RepositoriesTable_RepositoryEdgeFragment.graphql";

import InfiniteTable from "@/components/ui/infinite-table/InfiniteTable";
import { createColumnHelper } from "@/components/ui/table/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const REPOSITORIES_FRAGMENT = graphql`
  fragment RepositoriesTable_RepositoryEdgeFragment on RepositoryConnection {
    edges {
      node {
        id
        name
        handle
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<RepositoriesTable_RepositoryEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.files.repositories.repositories-table.RepositoriesTable.nameTitle"
        defaultMessage="Repository Name"
        description="Title for the Name column of the repositories table"
      />
    ),
    meta: {
      label: "Repository Name",
    },
    cell: ({ row, getValue }) => (
      <Link
        route={Route.repositoryEdit}
        params={{ repositoryId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.files.repositories.repositories-table.RepositoriesTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the repositories table"
      />
    ),
    meta: {
      label: "Handle",
    },
  }),
];

type Props = {
  className?: string;
  repositoriesRef: RepositoriesTable_RepositoryEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onSearchChange?: (text: string) => void;
  searchText?: string;
};

const RepositoriesTable = ({
  className,
  repositoriesRef,
  loading = false,
  onLoadMore,
  onSearchChange,
  searchText,
}: Props) => {
  const repositoriesFragment = useFragment(
    REPOSITORIES_FRAGMENT,
    repositoriesRef || null,
  );

  const repositories = useMemo<TableRecord[]>(() => {
    return compact(repositoriesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [repositoriesFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={repositories}
      loading={loading}
      onLoadMore={onLoadMore}
      columnVisibilityKey="repositories-table"
      onSearchChange={onSearchChange}
      searchText={searchText}
    />
  );
};

export default RepositoriesTable;
