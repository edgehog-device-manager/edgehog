/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ApplicationsTable_ApplicationEdgeFragment$data,
  ApplicationsTable_ApplicationEdgeFragment$key,
} from "@/api/__generated__/ApplicationsTable_ApplicationEdgeFragment.graphql";

import { Link, Route } from "@/Navigation";
import Button from "@/components/Button";
import Icon from "@/components/Icon";
import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "./InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const APPLICATIONS_TABLE_FRAGMENT = graphql`
  fragment ApplicationsTable_ApplicationEdgeFragment on ApplicationConnection {
    edges {
      node {
        id
        name
        description
      }
    }
  }
`;

export type TableRecord = NonNullable<
  NonNullable<ApplicationsTable_ApplicationEdgeFragment$data>["edges"]
>[number]["node"];

type ApplicationsTableProps = {
  className?: string;
  applicationsRef: ApplicationsTable_ApplicationEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onDelete: (application: TableRecord) => void;
};

const ApplicationsTable = ({
  className,
  applicationsRef,
  loading = false,
  onLoadMore,
  onDelete,
}: ApplicationsTableProps) => {
  const applicationsFragment = useFragment(
    APPLICATIONS_TABLE_FRAGMENT,
    applicationsRef || null,
  );

  const applications = useMemo<TableRecord[]>(() => {
    return _.compact(applicationsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [applicationsFragment]);

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
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.ApplicationsTable.action"
          defaultMessage="Action"
        />
      ),
      cell: ({ getValue }) => (
        <Button
          className="btn p-0 border-0 bg-transparent ms-4"
          onClick={() => {
            onDelete(getValue());
          }}
        >
          <Icon className="text-danger" icon={"delete"} />
        </Button>
      ),
    }),
  ];

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={applications}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default ApplicationsTable;
