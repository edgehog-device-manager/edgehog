// This file is part of Edgehog.
//
// Copyright 2022-2026 SECO Mind Srl
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
  DeviceGroupsTable_DeviceGroupEdgeFragment$data,
  DeviceGroupsTable_DeviceGroupEdgeFragment$key,
} from "@/api/__generated__/DeviceGroupsTable_DeviceGroupEdgeFragment.graphql";

import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment DeviceGroupsTable_DeviceGroupEdgeFragment on DeviceGroupConnection {
    edges {
      node {
        id
        name
        handle
        selector
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<DeviceGroupsTable_DeviceGroupEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.nameTitle"
        defaultMessage="Group Name"
        description="Title for the Name column of the device groups table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.deviceGroupsEdit}
        params={{ deviceGroupId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the device groups table"
      />
    ),
  }),
  columnHelper.accessor("selector", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.selectorTitle"
        defaultMessage="Selector"
        description="Title for the Selector column of the device groups table"
      />
    ),
  }),
];

type Props = {
  className?: string;
  deviceGroupsRef: DeviceGroupsTable_DeviceGroupEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const DeviceGroupsTable = ({
  className,
  deviceGroupsRef,
  loading = false,
  onLoadMore,
}: Props) => {
  const deviceGroupsFragment = useFragment(
    DEVICE_GROUPS_TABLE_FRAGMENT,
    deviceGroupsRef || null,
  );

  const deviceGroups = useMemo<TableRecord[]>(() => {
    return _.compact(deviceGroupsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [deviceGroupsFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={deviceGroups}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default DeviceGroupsTable;
