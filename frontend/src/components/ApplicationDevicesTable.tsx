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
  ApplicationDevicesTable_ReleaseEdgeFragment$data,
  ApplicationDevicesTable_ReleaseEdgeFragment$key,
} from "@/api/__generated__/ApplicationDevicesTable_ReleaseEdgeFragment.graphql";

import ConnectionStatus from "@/components/ConnectionStatus";
import DeploymentStateComponent, {
  type DeploymentState,
} from "@/components/DeploymentState";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";
import InfiniteTable from "./InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const APPLICATION_DEVICES_TABLE_FRAGMENT = graphql`
  fragment ApplicationDevicesTable_ReleaseEdgeFragment on ReleaseConnection {
    edges {
      node {
        deployments {
          edges {
            node {
              id
              state
              isReady
              device {
                id
                name
                online
              }
              release {
                version
              }
            }
          }
        }
      }
    }
  }
`;

type ReleaseRecord = NonNullable<
  ApplicationDevicesTable_ReleaseEdgeFragment$data["edges"]
>[number]["node"];

type TableRecord = NonNullable<
  ReleaseRecord["deployments"]["edges"]
>[number]["node"];

type ApplicationDevicesTableProps = {
  className?: string;
  applicationDevicesRef: ApplicationDevicesTable_ReleaseEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const ApplicationDevicesTable = ({
  className,
  applicationDevicesRef,
  loading = false,
  onLoadMore,
}: ApplicationDevicesTableProps) => {
  const applicationDevicesFragment = useFragment(
    APPLICATION_DEVICES_TABLE_FRAGMENT,
    applicationDevicesRef || null,
  );
  const releases = useMemo<ReleaseRecord[]>(() => {
    return (
      _.compact(applicationDevicesFragment?.edges?.map((e) => e?.node)) ?? []
    );
  }, [applicationDevicesFragment]);

  const tableData = releases.flatMap(
    (release) => release.deployments?.edges?.map((edge) => edge.node) ?? [],
  );

  const columnHelper = createColumnHelper<TableRecord>();
  const columns = [
    columnHelper.accessor("device.online", {
      header: () => (
        <FormattedMessage
          id="components.DevicesTable.statusTitle"
          defaultMessage="Status"
          description="Title for the Status column of the devices table"
        />
      ),
      cell: ({ getValue }) => <ConnectionStatus connected={getValue()} />,
    }),
    columnHelper.accessor("device.name", {
      header: () => (
        <FormattedMessage
          id="components.ApplicationDevicesTable.nameTitle"
          defaultMessage="Device Name"
          description="Title for the Name column of the application devices table"
        />
      ),
      cell: ({ row, getValue }) => (
        <Link
          route={Route.devicesEdit}
          params={{ deviceId: row.original.device?.id || "" }}
        >
          {getValue()}
        </Link>
      ),
    }),
    columnHelper.accessor("release.version", {
      header: () => (
        <FormattedMessage
          id="components.ApplicationDevicesTable.releaseVersionTitle"
          defaultMessage="Release Version"
          description="Title for the Release Version column of the application devices table"
        />
      ),
      cell: ({ row }) => row.original.release?.version,
    }),
    columnHelper.accessor("state", {
      header: () => (
        <FormattedMessage
          id="components.ApplicationDevicesTable.applicationStateTitle"
          defaultMessage="Application State"
          description="Title for the Application State column of the application devices table"
        />
      ),
      cell: ({ row }) => (
        <DeploymentStateComponent
          state={row.original.state as DeploymentState}
          isReady={row.original.isReady}
        />
      ),
    }),
  ];

  return (
    <div>
      <InfiniteTable
        className={className}
        columns={columns}
        data={tableData}
        loading={loading}
        onLoadMore={onLoadMore}
        hideSearch
      />
    </div>
  );
};

export default ApplicationDevicesTable;
