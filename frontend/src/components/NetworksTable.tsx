/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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
import { graphql, useFragment } from "react-relay/hooks";
import { useMemo } from "react";

import type {
  NetworksTable_NetworkFragment$data,
  NetworksTable_NetworkFragment$key,
} from "api/__generated__/NetworksTable_NetworkFragment.graphql";

import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const NETWORKS_TABLE_FRAGMENT = graphql`
  fragment NetworksTable_NetworkFragment on Network @relay(plural: true) {
    id
    label
    driver
    internal
    enableIpv6
    options
  }
`;

type TableRecord = NetworksTable_NetworkFragment$data[0];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.label"
        defaultMessage="Label"
        description="Title for the Label column of the networks table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.networksEdit} params={{ networkId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("driver", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.driverTitle"
        defaultMessage="Driver"
        description="Title for the Driver column of the networks table"
      />
    ),
  }),
  columnHelper.accessor("internal", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.internalTitle"
        defaultMessage="Internal"
        description="Title for the Internal column of the networks table"
      />
    ),
  }),
  columnHelper.accessor("enableIpv6", {
    header: () => (
      <FormattedMessage
        id="components.NetworksTable.enableIpv6"
        defaultMessage="Enable IPv6"
        description="Title for the Enable IPv6 column of the networks table"
      />
    ),
  }),
];

type NetworksTableProps = {
  className?: string;
  networksRef: NetworksTable_NetworkFragment$key;
  hideSearch?: boolean;
};

const NetworksTable = ({
  className,
  networksRef,
  hideSearch = false,
}: NetworksTableProps) => {
  const networks = useFragment(NETWORKS_TABLE_FRAGMENT, networksRef);

  const memoizedColumns = useMemo(() => columns, []);

  return (
    <Table
      className={className}
      columns={memoizedColumns}
      data={networks}
      hideSearch={hideSearch}
    />
  );
};

export default NetworksTable;
