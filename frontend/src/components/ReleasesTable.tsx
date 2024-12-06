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
  ReleasesTable_ReleaseFragment$data,
  ReleasesTable_ReleaseFragment$key,
} from "api/__generated__/ReleasesTable_ReleaseFragment.graphql";

import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const RELEASES_TABLE_FRAGMENT = graphql`
  fragment ReleasesTable_ReleaseFragment on ReleaseConnection {
    edges {
      node {
        id
        version
        application {
          id
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  ReleasesTable_ReleaseFragment$data["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("version", {
    header: () => (
      <FormattedMessage
        id="components.ReleaseTable.versionTitle"
        defaultMessage="Release Version"
        description="Title for the Release Version column of the releases table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.release}
        params={{
          applicationId: row.original.application?.id ?? "",
          releaseId: row.original.id,
        }}
      >
        {getValue()}
      </Link>
    ),
  }),
];

type ReleaseTableProps = {
  className?: string;
  releasesRef: ReleasesTable_ReleaseFragment$key;
  hideSearch?: boolean;
};

const ReleasesTable = ({
  className,
  releasesRef,
  hideSearch = false,
}: ReleaseTableProps) => {
  const release = useFragment(RELEASES_TABLE_FRAGMENT, releasesRef);
  const data = release.edges ? release.edges.map((edge) => edge.node) : [];

  return (
    <Table
      className={className}
      columns={columns}
      data={data}
      hideSearch={hideSearch}
    />
  );
};

export default ReleasesTable;
