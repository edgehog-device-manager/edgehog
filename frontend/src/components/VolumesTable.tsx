// This file is part of Edgehog.
//
// Copyright 2025, 2026 SECO Mind Srl
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
  VolumesTable_VolumeEdgeFragment$data,
  VolumesTable_VolumeEdgeFragment$key,
} from "@/api/__generated__/VolumesTable_VolumeEdgeFragment.graphql";

import { Link, Route } from "@/Navigation";
import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "./InfiniteTable";

/* eslint-disable relay/unused-fields */
const VOLUMES_TABLE_FRAGMENT = graphql`
  fragment VolumesTable_VolumeEdgeFragment on VolumeConnection {
    edges {
      node {
        id
        label
        driver
        options
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<VolumesTable_VolumeEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.VolumesTable.label"
        defaultMessage="Label"
        description="Title for the Label column of the volumes table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.volumeEdit} params={{ volumeId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("driver", {
    header: () => (
      <FormattedMessage
        id="components.VolumesTable.driverTitle"
        defaultMessage="Driver"
        description="Title for the Driver column of the volumes table"
      />
    ),
  }),
];

type VolumesTableProps = {
  className?: string;
  volumesRef: VolumesTable_VolumeEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const VolumesTable = ({
  className,
  volumesRef,
  loading = false,
  onLoadMore,
}: VolumesTableProps) => {
  const volumesFragment = useFragment(
    VOLUMES_TABLE_FRAGMENT,
    volumesRef || null,
  );

  const volumes = useMemo<TableRecord[]>(() => {
    return _.compact(volumesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [volumesFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={volumes}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default VolumesTable;
