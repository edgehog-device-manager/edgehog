/*
 * This file is part of Edgehog.
 *
 * Copyright 2022-2025 SECO Mind Srl
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

import { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  usePaginationFragment,
  useSubscription,
} from "react-relay/hooks";
import _ from "lodash";

import { ConnectionHandler } from "relay-runtime";

import type { DeviceGroupsTable_PaginationQuery } from "@/api/__generated__/DeviceGroupsTable_PaginationQuery.graphql";
import type {
  DeviceGroupsTable_DeviceGroupFragment$data,
  DeviceGroupsTable_DeviceGroupFragment$key,
} from "@/api/__generated__/DeviceGroupsTable_DeviceGroupFragment.graphql";

import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "@/components/InfiniteTable";
import { Link, Route } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment DeviceGroupsTable_DeviceGroupFragment on RootQueryType
  @refetchable(queryName: "DeviceGroupsTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "DeviceGroupFilterInput" }) {
    deviceGroups(first: $first, after: $after, filter: $filter)
      @connection(key: "DeviceGroupsTable_deviceGroups") {
      edges {
        node {
          id
          name
          handle
          selector
        }
      }
    }
  }
`;

const DEVICE_GROUP_CREATED_SUBSCRIPTION = graphql`
  subscription DeviceGroupsTable_deviceGroupEvent_created_Subscription {
    deviceGroup {
      created {
        id
        name
        handle
        selector
      }
    }
  }
`;

const DEVICE_GROUP_UPDATED_SUBSCRIPTION = graphql`
  subscription DeviceGroupsTable_deviceGroupEvent_updated_Subscription {
    deviceGroup {
      updated {
        id
        name
        handle
        selector
      }
    }
  }
`;

const DEVICE_GROUP_DESTROYED_SUBSCRIPTION = graphql`
  subscription DeviceGroupsTable_deviceGroupEvent_destroyed_Subscription {
    deviceGroup {
      destroyed
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<
    DeviceGroupsTable_DeviceGroupFragment$data["deviceGroups"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.nameTitle"
        defaultMessage="Group Name"
        description="Title for the Name column of the device groups table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.deviceGroupsEdit}
        params={{ deviceGroupId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("handle", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the device groups table"
      />
    ),
  }),
  columnHelper.accessor("selector", {
    header: () => (
      <FormattedMessage
        id="components.DeviceGroupsTable.selectorTitle"
        defaultMessage="Selector"
        description="Title for the Selector column of the device groups table"
      />
    ),
  }),
];

type Props = {
  className?: string;
  deviceGroupsRef: DeviceGroupsTable_DeviceGroupFragment$key;
  hideSearch?: boolean;
};

const DeviceGroupsTable = ({
  className,
  deviceGroupsRef,
  hideSearch = false,
}: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    DeviceGroupsTable_PaginationQuery,
    DeviceGroupsTable_DeviceGroupFragment$key
  >(DEVICE_GROUPS_TABLE_FRAGMENT, deviceGroupsRef);
  const [searchText, setSearchText] = useState<string | null>(null);

  const normalizedSearchText = useMemo(
    () => (searchText ?? "").trim(),
    [searchText],
  );

  const connectionFilter = useMemo(() => {
    if (normalizedSearchText === "") return undefined;

    return {
      or: [
        { name: { ilike: `%${normalizedSearchText}%` } },
        { handle: { ilike: `%${normalizedSearchText}%` } },
        { selector: { ilike: `%${normalizedSearchText}%` } },
      ],
    };
  }, [normalizedSearchText]);

  useSubscription(
    useMemo(
      () => ({
        subscription: DEVICE_GROUP_CREATED_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const groupEvent = store.getRootField("deviceGroup");
          const newGroup = groupEvent?.getLinkedRecord("created");
          if (!newGroup) return;

          if (normalizedSearchText !== "") {
            const search = normalizedSearchText.toLowerCase();
            const name = String(newGroup.getValue("name") ?? "").toLowerCase();
            const handle = String(
              newGroup.getValue("handle") ?? "",
            ).toLowerCase();
            const selector = String(
              newGroup.getValue("selector") ?? "",
            ).toLowerCase();

            if (
              !name.includes(search) &&
              !handle.includes(search) &&
              !selector.includes(search)
            ) {
              return;
            }
          }

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "DeviceGroupsTable_deviceGroups",
            connectionFilter ? { filter: connectionFilter } : undefined,
          );
          if (!connection) return;

          const newGroupId = newGroup.getDataID();
          const edges = connection.getLinkedRecords("edges") ?? [];
          const alreadyPresent = edges.some(
            (edge) => edge.getLinkedRecord("node")?.getDataID() === newGroupId,
          );
          if (alreadyPresent) return;

          const edge = ConnectionHandler.createEdge(
            store,
            connection,
            newGroup,
            "DeviceGroupEdge",
          );

          ConnectionHandler.insertEdgeBefore(connection, edge);
        },
      }),
      [connectionFilter, normalizedSearchText],
    ),
  );

  useSubscription(
    useMemo(
      () => ({
        subscription: DEVICE_GROUP_UPDATED_SUBSCRIPTION,
        variables: {},
      }),
      [],
    ),
  );

  useSubscription(
    useMemo(
      () => ({
        subscription: DEVICE_GROUP_DESTROYED_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const groupEvent = store.getRootField("deviceGroup");
          const destroyedId = groupEvent?.getValue("destroyed");
          if (!destroyedId || typeof destroyedId !== "string") return;

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "DeviceGroupsTable_deviceGroups",
            connectionFilter ? { filter: connectionFilter } : undefined,
          );
          if (!connection) return;

          ConnectionHandler.deleteNode(connection, destroyedId);
        },
      }),
      [connectionFilter],
    ),
  );

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
                  { name: { ilike: `%${text}%` } },
                  { handle: { ilike: `%${text}%` } },
                  { selector: { ilike: `%${text}%` } },
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
      debounceRefetch(normalizedSearchText);
    }
  }, [debounceRefetch, normalizedSearchText, searchText]);

  const loadNextDeviceGroups = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deviceGroups = useMemo(() => {
    return (
      paginationData.deviceGroups?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.deviceGroups) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={deviceGroups}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDeviceGroups : undefined}
      setSearchText={setSearchText}
      hideSearch={hideSearch}
    />
  );
};

export default DeviceGroupsTable;
