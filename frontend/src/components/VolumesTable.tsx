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
  VolumesTable_VolumeFragment$data,
  VolumesTable_VolumeFragment$key,
} from "api/__generated__/VolumesTable_VolumeFragment.graphql";

import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const VOLUMES_TABLE_FRAGMENT = graphql`
  fragment VolumesTable_VolumeFragment on Volume @relay(plural: true) {
    id
    label
    driver
    options
  }
`;

type TableRecord = VolumesTable_VolumeFragment$data[0];

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
  volumesRef: VolumesTable_VolumeFragment$key;
  hideSearch?: boolean;
};

const VolumesTable = ({
  className,
  volumesRef,
  hideSearch = false,
}: VolumesTableProps) => {
  const volumes = useFragment(VOLUMES_TABLE_FRAGMENT, volumesRef);

  const memoizedColumns = useMemo(() => columns, []);

  return (
    <Table
      className={className}
      columns={memoizedColumns}
      data={volumes}
      hideSearch={hideSearch}
    />
  );
};

export default VolumesTable;
