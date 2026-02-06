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
import { Button } from "react-bootstrap";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ReleasesTable_ReleaseEdgeFragment$data,
  ReleasesTable_ReleaseEdgeFragment$key,
} from "@/api/__generated__/ReleasesTable_ReleaseEdgeFragment.graphql";

import { Link, Route } from "@/Navigation";
import Icon from "@/components/Icon";
import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "./InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const RELEASES_TABLE_FRAGMENT = graphql`
  fragment ReleasesTable_ReleaseEdgeFragment on ReleaseConnection {
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

export type ReleaseTableRecord = NonNullable<
  ReleasesTable_ReleaseEdgeFragment$data["edges"]
>[number]["node"];

type ReleaseTableProps = {
  className?: string;
  releasesRef: ReleasesTable_ReleaseEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onDelete: (release: ReleaseTableRecord) => void;
};

const ReleasesTable = ({
  className,
  releasesRef,
  loading = false,
  onLoadMore,
  onDelete,
}: ReleaseTableProps) => {
  const releasesFragment = useFragment(
    RELEASES_TABLE_FRAGMENT,
    releasesRef || null,
  );

  const releases = useMemo<ReleaseTableRecord[]>(() => {
    return _.compact(releasesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [releasesFragment]);

  const columnHelper = createColumnHelper<ReleaseTableRecord>();
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
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.ReleasesTable.action"
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
    <div>
      <InfiniteTable
        className={className}
        columns={columns}
        data={releases}
        loading={loading}
        onLoadMore={onLoadMore}
        hideSearch
      />
    </div>
  );
};

export default ReleasesTable;
