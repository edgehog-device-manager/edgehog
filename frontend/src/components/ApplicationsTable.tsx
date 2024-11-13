/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import type {
  ApplicationsTable_ApplicationFragment$data,
  ApplicationsTable_ApplicationFragment$key,
} from "api/__generated__/ApplicationsTable_ApplicationFragment.graphql";

import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const APPLICATIONS_TABLE_FRAGMENT = graphql`
  fragment ApplicationsTable_ApplicationFragment on Application
  @relay(plural: true) {
    id
    name
    description
  }
`;

type TableRecord = ApplicationsTable_ApplicationFragment$data[0];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.ApplicationsTable.nameTitle"
        defaultMessage="Application Name"
        description="Title for the Name column of the applications table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.application}
        params={{ applicationId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
];

type ApplicationsTableProps = {
  className?: string;
  applicationsRef: ApplicationsTable_ApplicationFragment$key;
  hideSearch?: boolean;
};

const ApplicationsTable = ({
  className,
  applicationsRef,
  hideSearch = false,
}: ApplicationsTableProps) => {
  const applications = useFragment(
    APPLICATIONS_TABLE_FRAGMENT,
    applicationsRef,
  );

  return (
    <Table
      className={className}
      columns={columns}
      data={applications}
      hideSearch={hideSearch}
    />
  );
};

export default ApplicationsTable;
