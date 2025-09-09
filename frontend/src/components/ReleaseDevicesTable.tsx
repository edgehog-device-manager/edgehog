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

import { useCallback, useMemo, useState } from "react";
import { Button, Collapse } from "react-bootstrap";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type {
  ReleaseDevicesTable_DeploymentsFragment$data,
  ReleaseDevicesTable_DeploymentsFragment$key,
} from "api/__generated__/ReleaseDevicesTable_DeploymentsFragment.graphql";
import type { ReleaseDevicesTable_PaginationQuery } from "api/__generated__/ReleaseDevicesTable_PaginationQuery.graphql";

import ConnectionStatus from "components/ConnectionStatus";
import {
  DeploymentState,
  DeploymentStateComponent,
} from "components/DeployedApplicationsTable";
import Icon from "components/Icon";
import InfiniteScroll from "components/InfiniteScroll";
import InfiniteTable from "components/InfiniteTable";
import { createColumnHelper } from "components/Table";
import { Link, Route } from "Navigation";

const DEVICES_TO_LOAD_NEXT = 5;

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const RELEASE_DEVICES_TABLE_FRAGMENT = graphql`
  fragment ReleaseDevicesTable_DeploymentsFragment on Release
  @refetchable(queryName: "ReleaseDevicesTable_PaginationQuery") {
    deployments(first: $first, after: $after)
      @connection(key: "ReleaseDevicesTable_deployments") {
      edges {
        node {
          id
          state
          device {
            id
            name
            online
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  ReleaseDevicesTable_DeploymentsFragment$data["deployments"]["edges"]
>[number]["node"];

type ReleaseDevicesTableProps = {
  className?: string;
  releaseDevicesRef: ReleaseDevicesTable_DeploymentsFragment$key;
  hideSearch?: boolean;
};

const ReleaseDevicesTable = ({
  className,
  releaseDevicesRef,
  hideSearch = true,
}: ReleaseDevicesTableProps) => {
  const [isOpenDevicesSection, setIsOpenDevicesSection] = useState(true);

  const { data, loadNext, hasNext, isLoadingNext } = usePaginationFragment<
    ReleaseDevicesTable_PaginationQuery,
    ReleaseDevicesTable_DeploymentsFragment$key
  >(RELEASE_DEVICES_TABLE_FRAGMENT, releaseDevicesRef);

  const loadNextContainers = useCallback(() => {
    if (hasNext && !isLoadingNext) loadNext(DEVICES_TO_LOAD_NEXT);
  }, [hasNext, isLoadingNext, loadNext]);

  const deployments: TableRecord[] = useMemo(() => {
    return data.deployments?.edges?.map((edge) => edge?.node) ?? [];
  }, [data]);

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
        />
      ),
    }),
  ];

  return (
    <div className={className}>
      <div className="border rounded">
        <Button
          variant="light"
          className="w-100 d-flex align-items-center fw-bold"
          onClick={() => setIsOpenDevicesSection((prevState) => !prevState)}
        >
          <FormattedMessage
            id="components.ReleaseDevicesTable.devices"
            defaultMessage="Devices"
          />
          <span className="ms-auto">
            {isOpenDevicesSection ? (
              <Icon icon="caretUp" />
            ) : (
              <Icon icon="caretDown" />
            )}
          </span>
        </Button>

        <InfiniteScroll
          className={className}
          loading={isLoadingNext}
          onLoadMore={hasNext ? loadNextContainers : undefined}
        >
          <Collapse in={isOpenDevicesSection}>
            <div className="p-3 border-top">
              {deployments.length ? (
                <InfiniteTable
                  className={className}
                  columns={columns}
                  data={deployments}
                  hideSearch={hideSearch}
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
          </Collapse>
        </InfiniteScroll>
      </div>
    </div>
  );
};

export default ReleaseDevicesTable;
