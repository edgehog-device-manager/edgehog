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

import { Deployments_DeploymentsFragment$key } from "@/api/__generated__/Deployments_DeploymentsFragment.graphql";
import type { Deployments_deployment_created_Subscription } from "@/api/__generated__/Deployments_deployment_created_Subscription.graphql";
import type { Deployments_deployment_destroyed_Subscription } from "@/api/__generated__/Deployments_deployment_destroyed_Subscription.graphql";
import type { Deployments_deployment_updated_Subscription } from "@/api/__generated__/Deployments_deployment_updated_Subscription.graphql";
import type { Deployments_getDeployments_Query } from "@/api/__generated__/Deployments_getDeployments_Query.graphql";
import { Deployments_PaginationQuery } from "@/api/__generated__/Deployments_PaginationQuery.graphql";

import Center from "@/components/Center";
import DeploymentsTable from "@/components/DeploymentsTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

const GET_DEPLOYMENTS_QUERY = graphql`
  query Deployments_getDeployments_Query(
    $first: Int
    $after: String
    $filter: DeploymentFilterInput = {}
  ) {
    ...Deployments_DeploymentsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const DEPLOYMENTS_FRAGMENT = graphql`
  fragment Deployments_DeploymentsFragment on RootQueryType
  @refetchable(queryName: "Deployments_PaginationQuery") {
    deployments(first: $first, after: $after, filter: $filter)
      @connection(key: "Deployments_deployments") {
      edges {
        node {
          __typename
        }
      }
      ...DeploymentsTable_DeploymentEdgeFragment
    }
  }
`;

const DEPLOYMENTS_CREATED_SUBSCRIPTION = graphql`
  subscription Deployments_deployment_created_Subscription {
    deployment {
      created {
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
`;

const DEPLOYMENTS_UPDATED_SUBSCRIPTION = graphql`
  subscription Deployments_deployment_updated_Subscription {
    deployment {
      updated {
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
`;

const DEPLOYMENTS_DESTROYED_SUBSCRIPTION = graphql`
  subscription Deployments_deployment_destroyed_Subscription {
    deployment {
      destroyed
    }
  }
`;

interface DeploymentsLayoutContainerProps {
  deploymentsData: Deployments_getDeployments_Query["response"];
  searchText: string | null;
}
const DeploymentsLayoutContainer = ({
  deploymentsData,
  searchText,
}: DeploymentsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Deployments_PaginationQuery,
      Deployments_DeploymentsFragment$key
    >(DEPLOYMENTS_FRAGMENT, deploymentsData);

  const normalizedSearchText = useMemo(
    () => (searchText ?? "").trim(),
    [searchText],
  );

  const connectionFilter = useMemo(() => {
    if (normalizedSearchText === "") return {};

    return {
      or: [
        {
          release: {
            version: { ilike: `%${normalizedSearchText}%` },
          },
        },
        {
          release: {
            application: { name: { ilike: `%${normalizedSearchText}%` } },
          },
        },
        {
          device: {
            name: { ilike: `%${normalizedSearchText}%` },
          },
        },
      ],
    };
  }, [normalizedSearchText]);

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
              filter: connectionFilter,
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [connectionFilter, refetch],
  );

  useSubscription<Deployments_deployment_created_Subscription>(
    useMemo(
      () => ({
        subscription: DEPLOYMENTS_CREATED_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const deploymentRoot = store.getRootField("deployment");
          const newDeployment = deploymentRoot?.getLinkedRecord("created");
          if (!newDeployment) return;

          if (normalizedSearchText !== "") {
            const search = normalizedSearchText.toLowerCase();
            const device = newDeployment.getLinkedRecord("device");
            const release = newDeployment.getLinkedRecord("release");
            const application = release?.getLinkedRecord("application");

            const deviceName = String(
              device?.getValue("name") ?? "",
            ).toLowerCase();
            const releaseVersion = String(
              release?.getValue("version") ?? "",
            ).toLowerCase();
            const applicationName = String(
              application?.getValue("name") ?? "",
            ).toLowerCase();

            const matchesSearch =
              deviceName.includes(search) ||
              releaseVersion.includes(search) ||
              applicationName.includes(search);

            if (!matchesSearch) return;
          }

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "Deployments_deployments",
            { filter: connectionFilter },
          );
          if (!connection) return;

          const newDeploymentId = newDeployment.getDataID();
          const edges = connection.getLinkedRecords("edges") ?? [];
          const alreadyPresent = edges.some(
            (edge) =>
              edge.getLinkedRecord("node")?.getDataID() === newDeploymentId,
          );
          if (alreadyPresent) return;

          const edge = ConnectionHandler.createEdge(
            store,
            connection,
            newDeployment,
            "DeploymentEdge",
          );

          ConnectionHandler.insertEdgeBefore(connection, edge);
        },
      }),
      [connectionFilter, normalizedSearchText],
    ),
  );

  useSubscription<Deployments_deployment_destroyed_Subscription>(
    useMemo(
      () => ({
        subscription: DEPLOYMENTS_DESTROYED_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const deploymentRoot = store.getRootField("deployment");
          const destroyedId = deploymentRoot?.getValue("destroyed");
          if (!destroyedId || typeof destroyedId !== "string") return;

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "Deployments_deployments",
            { filter: connectionFilter },
          );
          if (!connection) return;

          ConnectionHandler.deleteNode(connection, destroyedId);
        },
      }),
      [connectionFilter],
    ),
  );

  useSubscription<Deployments_deployment_updated_Subscription>(
    useMemo(
      () => ({
        subscription: DEPLOYMENTS_UPDATED_SUBSCRIPTION,
        variables: {},
      }),
      [],
    ),
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }

    return () => {
      debounceRefetch.cancel();
    };
  }, [debounceRefetch, searchText]);

  const loadNextDeployments = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deploymentsRef = data?.deployments;

  if (!deploymentsRef) {
    return null;
  }

  return (
    <DeploymentsTable
      deploymentsRef={deploymentsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextDeployments : undefined}
    />
  );
};

interface DeploymentsContentProps {
  getDeploymentsQuery: PreloadedQuery<Deployments_getDeployments_Query>;
}

const DeploymentsContent = ({
  getDeploymentsQuery,
}: DeploymentsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const deploymentsData = usePreloadedQuery(
    GET_DEPLOYMENTS_QUERY,
    getDeploymentsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Deployments.title"
            defaultMessage="Deployments"
          />
        }
      ></Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <DeploymentsLayoutContainer
          deploymentsData={deploymentsData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const DeploymentsPage = () => {
  const [getDeploymentsQuery, getDeployments] =
    useQueryLoader<Deployments_getDeployments_Query>(GET_DEPLOYMENTS_QUERY);

  const fetchDeployments = useCallback(
    () =>
      getDeployments(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getDeployments],
  );

  useEffect(fetchDeployments, [fetchDeployments]);

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
        onReset={fetchDeployments}
      >
        {getDeploymentsQuery && (
          <DeploymentsContent getDeploymentsQuery={getDeploymentsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentsPage;
