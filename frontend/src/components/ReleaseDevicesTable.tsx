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

import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import _ from "lodash";

import type {
  ReleaseDevicesTable_DeploymentEdgeFragment$data,
  ReleaseDevicesTable_DeploymentEdgeFragment$key,
} from "@/api/__generated__/ReleaseDevicesTable_DeploymentEdgeFragment.graphql";

import ConnectionStatus from "@/components/ConnectionStatus";
import DeploymentStateComponent, {
  type DeploymentState,
} from "@/components/DeploymentState";
import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const RELEASE_DEVICES_TABLE_FRAGMENT = graphql`
  fragment ReleaseDevicesTable_DeploymentEdgeFragment on DeploymentConnection {
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
      }
    }
  }
`;

type TableRecord = NonNullable<
  ReleaseDevicesTable_DeploymentEdgeFragment$data["edges"]
>[number]["node"];

type ReleaseDevicesTableProps = {
  className?: string;
  deploymentsRef: ReleaseDevicesTable_DeploymentEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const ReleaseDevicesTable = ({
  className,
  deploymentsRef,
  loading = false,
  onLoadMore,
}: ReleaseDevicesTableProps) => {
  const deploymentsFragment = useFragment(
    RELEASE_DEVICES_TABLE_FRAGMENT,
    deploymentsRef || null,
  );
  const deployments = useMemo<TableRecord[]>(() => {
    return _.compact(deploymentsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [deploymentsFragment]);

  const columnHelper = createColumnHelper<TableRecord>();
  const columns = [
    columnHelper.accessor("device.online", {
      header: () => (
        <FormattedMessage
          id="components.ReleaseDevicesTable.statusTitle"
          defaultMessage="Status"
          description="Title for the Status column of the devices table"
        />
      ),
      cell: ({ getValue }) => <ConnectionStatus connected={getValue()} />,
    }),
    columnHelper.accessor("device.name", {
      header: () => (
        <FormattedMessage
          id="components.ReleaseDevicesTable.deviceNameTitle"
          defaultMessage="Device Name"
          description="Title for the Device Name column of the release devices table"
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
    columnHelper.accessor("state", {
      header: () => (
        <FormattedMessage
          id="components.ReleaseDevicesTable.applicationStateTitle"
          defaultMessage="Application State"
          description="Title for the Application State column of the release devices table"
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
      {deployments.length ? (
        <InfiniteTable
          className={className}
          columns={columns}
          data={deployments}
          loading={loading}
          onLoadMore={onLoadMore}
          hideSearch
        />
      ) : (
        <p>
          <FormattedMessage
            id="components.ReleaseDevicesTable.noDevices"
            defaultMessage="No devices available."
          />
        </p>
      )}
    </div>
  );
};

export default ReleaseDevicesTable;
