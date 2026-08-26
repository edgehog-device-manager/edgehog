// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
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
  NetworksTable_NetworkEdgeFragment$data,
  NetworksTable_NetworkEdgeFragment$key,
} from "@/api/__generated__/NetworksTable_NetworkEdgeFragment.graphql";

import { Link, Route } from "@/Navigation";
import { createColumnHelper } from "@/components/ui/table/Table";
import InfiniteTable from "@/components/ui/infinite-table/InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const NETWORKS_TABLE_FRAGMENT = graphql`
  fragment NetworksTable_NetworkEdgeFragment on NetworkConnection {
    edges {
      node {
        id
        label
        driver
        internal
        enableIpv6
        options
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<NetworksTable_NetworkEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.networks-table.NetworksTable.label"
        defaultMessage="Label"
        description="Title for the Label column of the networks table"
      />
    ),
    meta: {
      label: "Label",
      isPrimaryLink: true,
      getLink: (row, children) => (
        <Link
          route={Route.networksEdit}
          params={{ networkId: row.original.id }}
          className="row-link"
          onClick={(e) => e.stopPropagation()}
        >
          {children}
        </Link>
      ),
    },
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("driver", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.networks-table.NetworksTable.driverTitle"
        defaultMessage="Driver"
        description="Title for the Driver column of the networks table"
      />
    ),
    meta: {
      label: "Driver",
    },
  }),
  columnHelper.accessor("internal", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.networks-table.NetworksTable.internalTitle"
        defaultMessage="Internal"
        description="Title for the Internal column of the networks table"
      />
    ),
    meta: {
      label: "Internal",
    },
  }),
  columnHelper.accessor("enableIpv6", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.networks-table.NetworksTable.enableIpv6"
        defaultMessage="Enable IPv6"
        description="Title for the Enable IPv6 column of the networks table"
      />
    ),
    meta: {
      label: "Enable IPv6",
    },
  }),
];

type NetworksTableProps = {
  className?: string;
  networksRef: NetworksTable_NetworkEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onSearchChange?: (text: string) => void;
  searchText?: string;
};

const NetworksTable = ({
  className,
  networksRef,
  loading = false,
  onLoadMore,
  onSearchChange,
  searchText,
}: NetworksTableProps) => {
  const networksFragment = useFragment(
    NETWORKS_TABLE_FRAGMENT,
    networksRef || null,
  );

  const networks = useMemo<TableRecord[]>(() => {
    return compact(networksFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [networksFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={networks}
      loading={loading}
      onLoadMore={onLoadMore}
      columnVisibilityKey="networks-table"
      onSearchChange={onSearchChange}
      searchText={searchText}
    />
  );
};

export default NetworksTable;
