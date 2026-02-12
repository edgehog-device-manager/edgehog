// This file is part of Edgehog.
//
// Copyright 2021-2026 SECO Mind Srl
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
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  ConnectionHandler,
  graphql,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
  useSubscription,
} from "react-relay/hooks";

import { Devices_DevicesFragment$key } from "@/api/__generated__/Devices_DevicesFragment.graphql";
import type { Devices_getDevices_Query } from "@/api/__generated__/Devices_getDevices_Query.graphql";
import { Devices_PaginationQuery } from "@/api/__generated__/Devices_PaginationQuery.graphql";

import Center from "@/components/Center";
import DevicesTable from "@/components/DevicesTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

const GET_DEVICES_QUERY = graphql`
  query Devices_getDevices_Query(
    $first: Int
    $after: String
    $filter: DeviceFilterInput = {}
  ) {
    ...Devices_DevicesFragment
  }
`;

/* eslint-disable relay/unused-fields */
const DEVICES_FRAGMENT = graphql`
  fragment Devices_DevicesFragment on RootQueryType
  @refetchable(queryName: "Devices_PaginationQuery") {
    devices(first: $first, after: $after, filter: $filter)
      @connection(key: "Devices_devices") {
      edges {
        node {
          __typename
        }
      }
      ...DevicesTable_DeviceEdgeFragment
    }
  }
`;

const DEVICE_CREATED_SUBSCRIPTION = graphql`
  subscription DevicesTable_deviceChanged_created_Subscription {
    deviceChanged {
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

const DEVICE_UPDATED_SUBSCRIPTION = graphql`
  subscription DevicesTable_deviceChanged_updated_Subscription {
    deviceChanged {
      updated {
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

interface DevicesLayoutContainerProps {
  devicesData: Devices_getDevices_Query["response"];
  searchText: string | null;
}
const DevicesLayoutContainer = ({
  devicesData,
  searchText,
}: DevicesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<Devices_PaginationQuery, Devices_DevicesFragment$key>(
      DEVICES_FRAGMENT,
      devicesData,
    );

  const normalizedSearchText = useMemo(
    () => (searchText ?? "").trim(),
    [searchText],
  );

  const connectionFilter = useMemo(() => {
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
          const deviceChanged = store.getRootField("deviceChanged");
          const newDevice = deviceChanged?.getLinkedRecord("created");
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
            "Devices_devices",
            { filter: connectionFilter },
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
      [connectionFilter, normalizedSearchText],
    ),
  );

  useSubscription(
    useMemo(
      () => ({ subscription: DEVICE_UPDATED_SUBSCRIPTION, variables: {} }),
      [],
    ),
  );

  useEffect(() => {
    const handler = _.debounce(() => {
      refetch(
        { first: RECORDS_TO_LOAD_FIRST, filter: connectionFilter },
        { fetchPolicy: "network-only" },
      );
    }, 500);

    handler();

    return () => {
      handler.cancel();
    };
  }, [connectionFilter, refetch]);

  const loadNextDevices = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const devicesRef = data?.devices;

  if (!devicesRef) {
    return null;
  }

  return (
    <DevicesTable
      devicesRef={devicesRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDevices : undefined}
    />
  );
};

interface DevicesContentProps {
  getDevicesQuery: PreloadedQuery<Devices_getDevices_Query>;
}

const DevicesContent = ({ getDevicesQuery }: DevicesContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);

  const devicesData = usePreloadedQuery(GET_DEVICES_QUERY, getDevicesQuery);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage id="pages.Devices.title" defaultMessage="Devices" />
        }
      />
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <DevicesLayoutContainer
          devicesData={devicesData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const DevicesPage = () => {
  const [getDevicesQuery, getDevices] =
    useQueryLoader<Devices_getDevices_Query>(GET_DEVICES_QUERY);

  const fetchDevices = useCallback(
    () =>
      getDevices(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getDevices],
  );

  useEffect(fetchDevices, [fetchDevices]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={() => getDevices({})}
      >
        {getDevicesQuery && (
          <DevicesContent getDevicesQuery={getDevicesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DevicesPage;
