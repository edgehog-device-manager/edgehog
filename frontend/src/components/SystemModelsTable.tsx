/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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
  SystemModelsTable_SystemModelsFragment$key,
  SystemModelsTable_SystemModelsFragment$data,
} from "../api/__generated__/SystemModelsTable_SystemModelsFragment.graphql";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const SYSTEM_MODELS_TABLE_FRAGMENT = graphql`
  fragment SystemModelsTable_SystemModelsFragment on SystemModel
  @relay(plural: true) {
    id
    handle
    name
    hardwareType {
      name
    }
    partNumbers
  }
`;

type TableRecord = SystemModelsTable_SystemModelsFragment$data[number];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.nameTitle"
        defaultMessage="System Model Name"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.systemModelsEdit}
        params={{ systemModelId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.handleTitle"
        defaultMessage="Handle"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor("hardwareType.name", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.hardwareType"
        defaultMessage="Hardware Type"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor("partNumbers", {
    header: () => (
      <FormattedMessage
        id="components.SystemModelsTable.partNumbersTitle"
        defaultMessage="Part Numbers"
      />
    ),
    cell: ({ getValue }) =>
      getValue().map((partNumber, index) => (
        <React.Fragment key={partNumber}>
          {index > 0 && ", "}
          <span className="text-nowrap">{partNumber}</span>
        </React.Fragment>
      )),
    enableSorting: false,
  }),
];

type Props = {
  className?: string;
  systemModelsRef: SystemModelsTable_SystemModelsFragment$key;
};

const SystemModelsTable = ({ className, systemModelsRef }: Props) => {
  const systemModels = useFragment(
    SYSTEM_MODELS_TABLE_FRAGMENT,
    systemModelsRef,
  );
  return <Table className={className} columns={columns} data={systemModels} />;
};

export type { TableRecord };

export default SystemModelsTable;
