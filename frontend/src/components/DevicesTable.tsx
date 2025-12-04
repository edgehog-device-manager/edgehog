/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2025 SECO Mind Srl
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

import { ConnectionHandler } from "relay-runtime";
import _ from "lodash";

import type { DevicesTable_PaginationQuery } from "@/api/__generated__/DevicesTable_PaginationQuery.graphql";
import type {
  DevicesTable_DeviceFragment$data,
  DevicesTable_DeviceFragment$key,
} from "@/api/__generated__/DevicesTable_DeviceFragment.graphql";

import ConnectionStatus from "@/components/ConnectionStatus";
import { createColumnHelper } from "@/components/Table";
import InfiniteTable from "./InfiniteTable";
import LastSeen from "@/components/LastSeen";
import { Link, Route } from "@/Navigation";
import Tag from "@/components/Tag";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICES_TABLE_FRAGMENT = graphql`
  fragment DevicesTable_DeviceFragment on RootQueryType
  @refetchable(queryName: "DevicesTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "DeviceFilterInput" }) {
    devices(first: $first, after: $after, filter: $filter)
      @connection(key: "DevicesTable_devices") {
      edges {
        node {
          id
          deviceId
          lastConnection
          lastDisconnection
          name
          online
          systemModel {
            name
            hardwareType {
              name
            }
          }
          tags {
            edges {
              node {
                name
              }
            }
          }
        }
      }
    }
  }
`;

const DEVICE_CREATED_SUBSCRIPTION = graphql`
  subscription DevicesTable_deviceCreated_Subscription {
    deviceCreated {
      created {
        id
        deviceId
        name
        online
        lastConnection
        lastDisconnection
        systemModel {
          id
          name
          hardwareType {
            id
            name
          }
        }
        tags {
          edges {
            node {
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
  NonNullable<DevicesTable_DeviceFragment$data["devices"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("online", {
    header: () => (
      <FormattedMessage
        id="components.DevicesTable.statusTitle"
        defaultMessage="Status"
        description="Title for the Status column of the devices table"
      />
    ),
    cell: ({ getValue }) => <ConnectionStatus connected={getValue()} />,
    sortingFn: "basic",
  }),
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.DevicesTable.nameTitle"
        defaultMessage="Device Name"
        description="Title for the Name column of the devices table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link route={Route.devicesEdit} params={{ deviceId: row.original.id }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("deviceId", {
    header: () => (
      <FormattedMessage
        id="components.DevicesTable.deviceIdTitle"
        defaultMessage="Device ID"
        description="Title for the Device ID column of the devices table"
      />
    ),
    sortingFn: "basic",
  }),
  columnHelper.accessor((device) => device.systemModel?.name, {
    id: "systemModel",
    header: () => (
      <FormattedMessage id="Device.systemModel" defaultMessage="System Model" />
    ),
  }),
  columnHelper.accessor((device) => device.systemModel?.hardwareType?.name, {
    id: "hardwareType",
    header: () => (
      <FormattedMessage
        id="Device.hardwareType"
        defaultMessage="Hardware Type"
      />
    ),
  }),
  columnHelper.accessor(
    (device) => {
      if (device.online) {
        return "now";
      } else {
        return device.lastDisconnection || "never";
      }
    },
    {
      id: "lastSeen",
      header: () => (
        <FormattedMessage
          id="components.DevicesTable.lastSeenTitle"
          defaultMessage="Last Seen"
          description="Title for the Last Seen column of the devices table"
        />
      ),
      cell: ({ row }) => (
        <LastSeen
          lastConnection={row.original.lastConnection}
          lastDisconnection={row.original.lastDisconnection}
          online={row.original.online}
        />
      ),
    },
  ),
  columnHelper.accessor("tags", {
    enableSorting: false,
    header: () => (
      <FormattedMessage
        id="components.DevicesTable.tagsTitle"
        defaultMessage="Tags"
        description="Title for the Tags column of the devices table"
      />
    ),
    cell: ({ getValue }) => (
      <>
        {getValue().edges?.map(({ node: { name: tag } }) => (
          <Tag key={tag} className="me-2">
            {tag}
          </Tag>
        ))}
      </>
    ),
  }),
];

type Props = {
  className?: string;
  devicesRef: DevicesTable_DeviceFragment$key;
};

const DevicesTable = ({ className, devicesRef }: Props) => {
  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    DevicesTable_PaginationQuery,
    DevicesTable_DeviceFragment$key
  >(DEVICES_TABLE_FRAGMENT, devicesRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const normalizedSearchText = useMemo(
    () => (searchText ?? "").trim(),
    [searchText],
  );

  const currentFilter = useMemo(() => {
    if (normalizedSearchText === "") return {};

    return {
      or: [
        { name: { ilike: `%${normalizedSearchText}%` } },
        { deviceId: { ilike: `%${normalizedSearchText}%` } },
      ],
    };
  }, [normalizedSearchText]);

  useSubscription(
    useMemo(
      () => ({
        subscription: DEVICE_CREATED_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const deviceCreated = store.getRootField("deviceCreated");
          const newDevice = deviceCreated?.getLinkedRecord("created");
          if (!newDevice) return;

          if (normalizedSearchText !== "") {
            const search = normalizedSearchText.toLowerCase();
            const name = String(newDevice.getValue("name") ?? "").toLowerCase();
            const deviceId = String(
              newDevice.getValue("deviceId") ?? "",
            ).toLowerCase();

            if (!name.includes(search) && !deviceId.includes(search)) return;
          }

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "DevicesTable_devices",
            { filter: currentFilter },
          );
          if (!connection) return;

          const newDeviceId = newDevice.getDataID();
          const edges = connection.getLinkedRecords("edges") ?? [];
          const alreadyPresent = edges.some(
            (edge) => edge.getLinkedRecord("node")?.getDataID() === newDeviceId,
          );
          if (alreadyPresent) return;

          const edge = ConnectionHandler.createEdge(
            store,
            connection,
            newDevice,
            "DeviceEdge",
          );

          ConnectionHandler.insertEdgeBefore(connection, edge);
        },
      }),
      [currentFilter, normalizedSearchText],
    ),
  );

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: {},
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
                  { deviceId: { ilike: `%${text}%` } },
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

  const devices = useMemo(() => {
    return (
      paginationData.devices?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is TableRecord => node != null) ?? []
    );
  }, [paginationData]);

  if (!paginationData.devices) {
    return null;
  }

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={devices}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDevices : undefined}
      setSearchText={setSearchText}
    />
  );
};

export default DevicesTable;
