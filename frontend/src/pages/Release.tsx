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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  useMutation,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";
import { Card } from "react-bootstrap";

import { Containers_PaginationQuery } from "@/api/__generated__/Containers_PaginationQuery.graphql";
import { Release_ContainersFragment$key } from "@/api/__generated__/Release_ContainersFragment.graphql";
import { Release_DeploymentsFragment$key } from "@/api/__generated__/Release_DeploymentsFragment.graphql";
import type {
  Release_getRelease_Query,
  Release_getRelease_Query$data,
} from "@/api/__generated__/Release_getRelease_Query.graphql";
import type {
  Release_updateRelease_Mutation,
  UpdateReleaseInput,
} from "@/api/__generated__/Release_updateRelease_Mutation.graphql";
import { ReleaseDevices_PaginationQuery } from "@/api/__generated__/ReleaseDevices_PaginationQuery.graphql";

import Alert from "@/components/ui/alert/Alert";
import Center from "@/components/ui/center/Center";
import ContainersOverview from "@/components/apps/containers/containers-overview/ContainersOverview";
import Page from "@/components/ui/page/Page";
import ReleaseDevicesTable from "@/components/apps/releases/release-devices-table/ReleaseDevicesTable";
import ReleaseSystemModelsTable from "@/components/apps/releases/release-system-models-table/ReleaseSystemModelsTable";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import Tabs, { Tab } from "@/components/ui/tabs/Tabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import CreateRelease from "@/forms/CreateRelease";
import { ReleaseFormData } from "@/forms/validation";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import { Link, Route, useNavigate } from "@/Navigation";

const GET_RELEASE_QUERY = graphql`
  query Release_getRelease_Query($releaseId: ID!, $first: Int, $after: String) {
    release(id: $releaseId) {
      id
      version
      application {
        name
      }
      systemModels {
        id
      }
      selectedContainers: containers {
        edges {
          node {
            id
          }
        }
      }
      containerDependencies {
        edges {
          node {
            container {
              id
            }
            dependency {
              id
            }
          }
        }
      }
      ...Release_ContainersFragment
      ...ReleaseSystemModelsTable_SystemModelsFragment
      ...Release_DeploymentsFragment
    }
    ...hooks_SystemModelsOptionsFragment
    ...hooks_ContainersOptionsFragment
  }
`;

const UPDATE_RELEASE_MUTATION = graphql`
  mutation Release_updateRelease_Mutation(
    $releaseId: ID!
    $input: UpdateReleaseInput!
    $first: Int
    $after: String
  ) {
    updateRelease(id: $releaseId, input: $input) {
      result {
        id
        version
        systemModels {
          id
        }
        selectedContainers: containers {
          edges {
            node {
              id
            }
          }
        }
        containerDependencies {
          edges {
            node {
              container {
                id
              }
              dependency {
                id
              }
            }
          }
        }
        ...Release_ContainersFragment
        ...ReleaseSystemModelsTable_SystemModelsFragment
      }
    }
  }
`;

const DEPLOYMENTS_FRAGMENT = graphql`
  fragment Release_DeploymentsFragment on Release
  @refetchable(queryName: "ReleaseDevices_PaginationQuery") {
    deployments(first: $first, after: $after)
      @connection(key: "Release_deployments") {
      edges {
        node {
          __typename
        }
      }
      ...ReleaseDevicesTable_DeploymentEdgeFragment
    }
  }
`;

const CONTAINERS_FRAGMENT = graphql`
  fragment Release_ContainersFragment on Release
  @refetchable(queryName: "ReleaseContainers_PaginationQuery") {
    containers(first: $first, after: $after)
      @connection(key: "Release_containers") {
      edges {
        node {
          __typename
        }
      }
      ...ContainersOverview_ContainerEdgeFragment
    }
  }
`;

const TAB_KEYS = ["containers-tab", "system-models-tab", "devices-tab"];

type Release = NonNullable<Release_getRelease_Query$data["release"]>;

interface ContainersLayoutContainerProps {
  releaseRef: Release_ContainersFragment$key;
}

const ContainersLayoutContainer = ({
  releaseRef,
}: ContainersLayoutContainerProps) => {
  const { data } = usePaginationFragment<
    Containers_PaginationQuery,
    Release_ContainersFragment$key
  >(CONTAINERS_FRAGMENT, releaseRef);

  const containersRef = data?.containers;

  if (!containersRef) {
    return null;
  }

  return <ContainersOverview containersRef={containersRef} />;
};

interface SystemModelsTabProps {
  release: Release;
}

const SystemModelsTab = ({ release }: SystemModelsTabProps) => {
  const intl = useIntl();

  return (
    <Tab
      className="pt-3 d-flex flex-column flex-grow-1"
      eventKey="system-models-tab"
      title={intl.formatMessage({
        id: "pages.Release.systemModels",
        defaultMessage: "System Models",
      })}
    >
      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <ReleaseSystemModelsTable systemModelsRef={release} />
      </Card>
    </Tab>
  );
};

interface ReleaseDevicesLayoutContainerProps {
  releaseRef: Release_DeploymentsFragment$key;
}

const ReleaseDevicesLayoutContainer = ({
  releaseRef,
}: ReleaseDevicesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext } = usePaginationFragment<
    ReleaseDevices_PaginationQuery,
    Release_DeploymentsFragment$key
  >(DEPLOYMENTS_FRAGMENT, releaseRef);

  const { onLoadMore } = useRelayConnectionPagination({
    hasNext,
    isLoadingNext,
    loadNext,
  });

  const deploymentsRef = data?.deployments;

  if (!deploymentsRef) {
    return null;
  }

  return (
    <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
      <ReleaseDevicesTable
        deploymentsRef={deploymentsRef}
        loading={isLoadingNext}
        onLoadMore={onLoadMore}
      />
    </Card>
  );
};

interface ReleaseContentProps {
  release: NonNullable<Release_getRelease_Query$data["release"]>;
  queryData: Release_getRelease_Query$data;
}

const ReleaseContent = ({ release, queryData }: ReleaseContentProps) => {
  const intl = useIntl();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { applicationId = "", releaseId = "", activeTab } = useParams();
  const navigate = useNavigate();

  const currentTabKey = activeTab || TAB_KEYS[0];

  const [updateRelease, isUpdatingRelease] =
    useMutation<Release_updateRelease_Mutation>(UPDATE_RELEASE_MUTATION);

  const handleUpdateRelease = useCallback(
    (releaseData: UpdateReleaseInput) => {
      updateRelease({
        variables: {
          releaseId,
          input: releaseData,
          first: RECORDS_TO_LOAD_FIRST,
        },
        onCompleted(_data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Release.updateErrorFeedback"
              defaultMessage="Could not update the release, please try again."
            />,
          );
        },
      });
    },
    [updateRelease, releaseId],
  );

  const defaultValues = useMemo<ReleaseFormData>(() => {
    const dependenciesByContainer = new Map<string, string[]>();
    for (const edge of release.containerDependencies.edges ?? []) {
      if (!edge?.node) continue;
      const containerId = edge.node.container.id;
      const dependencyId = edge.node.dependency.id;
      const deps = dependenciesByContainer.get(containerId) ?? [];
      deps.push(dependencyId);
      dependenciesByContainer.set(containerId, deps);
    }

    return {
      version: release.version,
      requiredSystemModels: release.systemModels.map((sm) => ({ id: sm.id })),
      containers:
        release.selectedContainers.edges?.flatMap((e) =>
          e?.node ? [{ id: e.node.id }] : [],
        ) ?? [],
      containerDependencies: Array.from(
        dependenciesByContainer.entries(),
        ([containerId, dependencies]) => ({
          containerId,
          dependencies,
        }),
      ),
    };
  }, [
    release.version,
    release.systemModels,
    release.selectedContainers,
    release.containerDependencies,
  ]);

  return (
    <Page>
      <Page.Header
        title={`${release.application?.name ?? ""} (v${release.version})`}
      />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>

        <Card className="border-0 p-3 shadow-sm mb-3">
          <CreateRelease
            requiredSystemModelsOptionsRef={queryData}
            containersOptionsRef={queryData}
            defaultValues={defaultValues}
            onSubmit={handleUpdateRelease}
            isLoading={isUpdatingRelease}
          />
        </Card>

        <Tabs
          className="pt-3 d-flex flex-column flex-grow-1"
          activeKey={currentTabKey}
          tabsOrder={TAB_KEYS}
          onChange={(tabKey) =>
            navigate(
              {
                route: Route.release,
                params: { applicationId, releaseId, activeTab: tabKey },
              },
              { replace: true },
            )
          }
        >
          <Tab
            className="pt-3 d-flex flex-column flex-grow-1"
            eventKey="containers-tab"
            title={intl.formatMessage({
              id: "pages.Release.containers",
              defaultMessage: "Containers",
            })}
          >
            <ContainersLayoutContainer releaseRef={release} />
          </Tab>

          <SystemModelsTab release={release} />

          <Tab
            className="pt-3 d-flex flex-column flex-grow-1"
            eventKey="devices-tab"
            title={intl.formatMessage({
              id: "pages.Release.devices",
              defaultMessage: "Devices",
            })}
          >
            <ReleaseDevicesLayoutContainer releaseRef={release} />
          </Tab>
        </Tabs>
      </Page.Main>
    </Page>
  );
};

type ReleaseWrapperProps = {
  getReleaseQuery: PreloadedQuery<Release_getRelease_Query>;
};

const ReleaseWrapper = ({ getReleaseQuery }: ReleaseWrapperProps) => {
  const queryData = usePreloadedQuery<Release_getRelease_Query>(
    GET_RELEASE_QUERY,
    getReleaseQuery,
  );
  const { release } = queryData;

  if (!release) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Release.releaseNotFound.title"
            defaultMessage="Release not found."
          />
        }
      >
        <Link route={Route.applications}>
          <FormattedMessage
            id="pages.Release.releaseNotFound.message"
            defaultMessage="Return to the applications list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <ReleaseContent release={release} queryData={queryData} />;
};

const ReleasePage = () => {
  const { releaseId = "" } = useParams();

  const [getReleaseQuery, getRelease] =
    useQueryLoader<Release_getRelease_Query>(GET_RELEASE_QUERY);

  const fetchRelease = useCallback(
    () =>
      getRelease(
        { releaseId, first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "network-only" },
      ),
    [getRelease, releaseId],
  );

  useEffect(fetchRelease, [fetchRelease]);

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
        onReset={fetchRelease}
      >
        {getReleaseQuery && (
          <ReleaseWrapper getReleaseQuery={getReleaseQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ReleasePage;
