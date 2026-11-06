/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import compact from "lodash/compact";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  AllowedRegistriesTable_AllowedRegistryEdgeFragment$data,
  AllowedRegistriesTable_AllowedRegistryEdgeFragment$key,
} from "@/api/__generated__/AllowedRegistriesTable_AllowedRegistryEdgeFragment.graphql";

import { createColumnHelper } from "@/components/ui/table/Table";
import { Link, Route } from "@/Navigation";
import InfiniteTable from "@/components/ui/infinite-table/InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const ALLOWED_REGISTRIES_TABLE_FRAGMENT = graphql`
  fragment AllowedRegistriesTable_AllowedRegistryEdgeFragment on AllowedRegistryConnection {
    edges {
      node {
        id
        registry
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<AllowedRegistriesTable_AllowedRegistryEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("registry", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.allowed-registries-table.AllowedRegistriesTable.registryTitle"
        defaultMessage="Registry Host"
      />
    ),
    meta: {
      label: "Registry Host",
      isPrimaryLink: true,
      getLink: (row, children) => (
        <Link
          route={Route.allowedRegistriesEdit}
          params={{ allowedRegistryId: row.original.id }}
          className="row-link"
          aria-label="Edit allowed registry"
          onClick={(e) => e.stopPropagation()}
        >
          {children}
        </Link>
      ),
    },
    cell: ({ getValue }) => getValue(),
  }),
];

type AllowedRegistriesTableProps = {
  className?: string;
  allowedRegistriesRef: AllowedRegistriesTable_AllowedRegistryEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onSearchChange?: (text: string) => void;
  searchText?: string;
};

const AllowedRegistriesTable = ({
  className,
  allowedRegistriesRef,
  loading = false,
  onLoadMore,
  onSearchChange,
  searchText,
}: AllowedRegistriesTableProps) => {
  const allowedRegistriesFragment = useFragment(
    ALLOWED_REGISTRIES_TABLE_FRAGMENT,
    allowedRegistriesRef || null,
  );

  const allowedRegistries = useMemo<TableRecord[]>(() => {
    return compact(allowedRegistriesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [allowedRegistriesFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={allowedRegistries}
      loading={loading}
      onLoadMore={onLoadMore}
      columnVisibilityKey="allowedRegistries-table"
      onSearchChange={onSearchChange}
      searchText={searchText}
    />
  );
};

export default AllowedRegistriesTable;
