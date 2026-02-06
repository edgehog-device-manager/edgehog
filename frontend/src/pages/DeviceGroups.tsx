// This file is part of Edgehog.
//
// Copyright 2022-2026 SECO Mind Srl
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

import { DeviceGroups_DeviceGroupsFragment$key } from "@/api/__generated__/DeviceGroups_DeviceGroupsFragment.graphql";
import type { DeviceGroups_getDeviceGroups_Query } from "@/api/__generated__/DeviceGroups_getDeviceGroups_Query.graphql";
import { DeviceGroups_PaginationQuery } from "@/api/__generated__/DeviceGroups_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import DeviceGroupsTable from "@/components/DeviceGroupsTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_DEVICE_GROUPS_QUERY = graphql`
  query DeviceGroups_getDeviceGroups_Query(
    $first: Int
    $after: String
    $filter: DeviceGroupFilterInput
  ) {
    ...DeviceGroups_DeviceGroupsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_FRAGMENT = graphql`
  fragment DeviceGroups_DeviceGroupsFragment on RootQueryType
  @refetchable(queryName: "DeviceGroups_PaginationQuery") {
    deviceGroups(first: $first, after: $after, filter: $filter)
      @connection(key: "DeviceGroups_deviceGroups") {
      edges {
        node {
          __typename
        }
      }
      ...DeviceGroupsTable_DeviceGroupEdgeFragment
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

interface DeviceGroupsLayoutContainerProps {
  deviceGroupsData: DeviceGroups_getDeviceGroups_Query["response"];
  searchText: string | null;
}
const DeviceGroupsLayoutContainer = ({
  deviceGroupsData,
  searchText,
}: DeviceGroupsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      DeviceGroups_PaginationQuery,
      DeviceGroups_DeviceGroupsFragment$key
    >(DEVICE_GROUPS_FRAGMENT, deviceGroupsData);

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
            "DeviceGroups_deviceGroups",
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
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextDeviceGroups = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deviceGroupsRef = data?.deviceGroups;

  if (!deviceGroupsRef) {
    return null;
  }

  return (
    <DeviceGroupsTable
      deviceGroupsRef={deviceGroupsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDeviceGroups : undefined}
    />
  );
};

interface DeviceGroupsContentProps {
  getDeviceGroupsQuery: PreloadedQuery<DeviceGroups_getDeviceGroups_Query>;
}

const DeviceGroupsContent = ({
  getDeviceGroupsQuery,
}: DeviceGroupsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const deviceGroupsData = usePreloadedQuery(
    GET_DEVICE_GROUPS_QUERY,
    getDeviceGroupsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.DeviceGroups.title"
            defaultMessage="Groups"
          />
        }
      >
        <Button as={Link} route={Route.deviceGroupsNew}>
          <FormattedMessage
            id="pages.DeviceGroups.createButton"
            defaultMessage="Create Group"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <DeviceGroupsLayoutContainer
          deviceGroupsData={deviceGroupsData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const DevicesPage = () => {
  const [getDeviceGroupsQuery, getDeviceGroups] =
    useQueryLoader<DeviceGroups_getDeviceGroups_Query>(GET_DEVICE_GROUPS_QUERY);

  const fetchDeviceGroups = useCallback(
    () =>
      getDeviceGroups(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getDeviceGroups],
  );

  useEffect(fetchDeviceGroups, [fetchDeviceGroups]);

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
        onReset={fetchDeviceGroups}
      >
        {getDeviceGroupsQuery && (
          <DeviceGroupsContent getDeviceGroupsQuery={getDeviceGroupsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DevicesPage;
