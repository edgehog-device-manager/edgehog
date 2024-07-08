/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

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

import React from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import Table, { createColumnHelper } from "components/Table";
import { Link, Route } from "Navigation";
import type {
  HardwareTypesTable_HardwareTypesFragment$key,
  HardwareTypesTable_HardwareTypesFragment$data,
} from "api/__generated__/HardwareTypesTable_HardwareTypesFragment.graphql";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const HARDWARE_TYPES_TABLE_FRAGMENT = graphql`
  fragment HardwareTypesTable_HardwareTypesFragment on HardwareType
  @relay(plural: true) {
    id
    handle
    name
    partNumbers {
      partNumber
    }
  }
`;

type TableRecord = HardwareTypesTable_HardwareTypesFragment$data[number];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.HardwareTypesTable.nameTitle"
        defaultMessage="Hardware Type Name"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.hardwareTypesEdit}
        params={{ hardwareTypeId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.HardwareTypesTable.handleTitle"
        defaultMessage="Handle"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor("partNumbers", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.HardwareTypesTable.partNumbersTitle"
        defaultMessage="Part Numbers"
      />
    ),
    cell: ({ getValue }) =>
      getValue().map(({ partNumber }, index) => (
        <React.Fragment key={partNumber}>
          {index > 0 && ", "}
          <span className="text-nowrap">{partNumber}</span>
        </React.Fragment>
      )),
  }),
];

type Props = {
  className?: string;
  hardwareTypesRef: HardwareTypesTable_HardwareTypesFragment$key;
};

const HardwareTypesTable = ({ className, hardwareTypesRef }: Props) => {
  const hardwareTypes = useFragment(
    HARDWARE_TYPES_TABLE_FRAGMENT,
    hardwareTypesRef,
  );

  return <Table className={className} columns={columns} data={hardwareTypes} />;
};

export default HardwareTypesTable;
