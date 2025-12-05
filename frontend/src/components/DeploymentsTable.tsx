/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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
import { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type {
  DeploymentsTable_DeploymentFragment$data,
  DeploymentsTable_DeploymentFragment$key,
} from "@/api/__generated__/DeploymentsTable_DeploymentFragment.graphql";
import type { DeploymentsTable_PaginationQuery } from "@/api/__generated__/DeploymentsTable_PaginationQuery.graphql";

import DeploymentStateComponent, {
  type DeploymentState,
} from "@/components/DeploymentState";
import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEPLOYMENTS_TABLE_FRAGMENT = graphql`
  fragment DeploymentsTable_DeploymentFragment on RootQueryType
  @refetchable(queryName: "DeploymentsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "DeploymentFilterInput" }) {
    deployments(first: $first, after: $after, filter: $filter)
      @connection(key: "DeploymentsTable_deployments") {
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
            id
            version
            application {
              id
              name
            }
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<DeploymentsTable_DeploymentFragment$data["deployments"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("device.name", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentsTable.deploymentOnDeviceTitle"
        defaultMessage="Deployment on Device"
        description="Title for the Deployment on Device column of the deployments table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.deploymentEdit}
        params={{
          deviceId: row.original.device?.id || "",
          deploymentId: row.original.id,
        }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("release.application.name", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentsTable.applicationNameTitle"
        defaultMessage="Application Name"
        description="Title for the Application Name column of the deployments table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.application}
        params={{ applicationId: row.original.release?.application?.id || "" }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("release.version", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentsTable.releaseVersionTitle"
        defaultMessage="Release Version"
        description="Title for the Release Version column of the deployments table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.release}
        params={{
          applicationId: row.original.release?.application?.id || "",
          releaseId: row.original.release?.id || "",
        }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("state", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentsTable.applicationStateTitle"
        defaultMessage="Application State"
        description="Title for the Application State column of the deployments table"
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

type DeploymentsTableProps = {
  className?: string;
  deploymentsRef: DeploymentsTable_DeploymentFragment$key;
  hideSearch?: boolean;
};

const DeploymentsTable = ({
  className,
  deploymentsRef,
  hideSearch = false,
}: DeploymentsTableProps) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    DeploymentsTable_PaginationQuery,
    DeploymentsTable_DeploymentFragment$key
  >(DEPLOYMENTS_TABLE_FRAGMENT, deploymentsRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: {
                or: [
                  {
                    release: {
                      version: { ilike: `%${text}%` },
                    },
                  },
                  {
                    release: {
                      application: { name: { ilike: `%${text}%` } },
                    },
                  },
                  {
                    device: {
                      name: { ilike: `%${text}%` },
                    },
                  },
                ],
              },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextDevices = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deployments = useMemo(() => {
    return (
      paginationData.deployments?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.deployments) {
    return null;
  }

  return (
    <div>
      <InfiniteTable
        className={className}
        columns={columns}
        data={deployments}
        loading={isLoadingNext}
        onLoadMore={hasNext ? loadNextDevices : undefined}
        setSearchText={setSearchText}
        hideSearch={hideSearch}
      />
    </div>
  );
};

export default DeploymentsTable;
