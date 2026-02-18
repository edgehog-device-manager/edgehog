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

import type { Applications_ApplicationsFragment$key } from "@/api/__generated__/Applications_ApplicationsFragment.graphql";
import type { Applications_ApplicationSubscription } from "@/api/__generated__/Applications_ApplicationSubscription.graphql";
import type { Applications_getApplications_Query } from "@/api/__generated__/Applications_getApplications_Query.graphql";
import { Applications_PaginationQuery } from "@/api/__generated__/Applications_PaginationQuery.graphql";

import Alert from "@/components/Alert";
import ApplicationsTable, { TableRecord } from "@/components/ApplicationsTable";
import Button from "@/components/Button";
import Center from "@/components/Center";
import DeleteApplicationModal from "@/components/DeleteApplicationModal";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_APPLICATIONS_QUERY = graphql`
  query Applications_getApplications_Query(
    $first: Int
    $after: String
    $filter: ApplicationFilterInput = {}
  ) {
    ...Applications_ApplicationsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const APPLICATIONS_FRAGMENT = graphql`
  fragment Applications_ApplicationsFragment on RootQueryType
  @refetchable(queryName: "Applications_PaginationQuery") {
    applications(first: $first, after: $after, filter: $filter)
      @connection(key: "Applications_applications") {
      edges {
        node {
          __typename
        }
      }
      ...ApplicationsTable_ApplicationEdgeFragment
    }
  }
`;

const APPLICATION_SUBSCRIPTION = graphql`
  subscription Applications_ApplicationSubscription {
    application {
      created {
        id
        name
        description
      }
      updated {
        id
        name
        description
      }
      destroyed
    }
  }
`;

type SelectedApplication = TableRecord;

interface ApplicationsLayoutContainerProps {
  applicationsData: Applications_getApplications_Query["response"];
  searchText: string | null;
  onDelete: (application: SelectedApplication) => void;
}
const ApplicationsLayoutContainer = ({
  applicationsData,
  searchText,
  onDelete,
}: ApplicationsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Applications_PaginationQuery,
      Applications_ApplicationsFragment$key
    >(APPLICATIONS_FRAGMENT, applicationsData);

  const normalizedSearchText = useMemo(
    () => (searchText ?? "").trim(),
    [searchText],
  );

  const connectionFilter = useMemo(() => {
    if (normalizedSearchText === "") {
      return { filter: {} };
    }

    return {
      filter: {
        or: [{ name: { ilike: `%${normalizedSearchText}%` } }],
      },
    };
  }, [normalizedSearchText]);

  useSubscription<Applications_ApplicationSubscription>(
    useMemo(
      () => ({
        subscription: APPLICATION_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const applicationEvent = store.getRootField("application");
          const createdApplication =
            applicationEvent?.getLinkedRecord("created");

          if (createdApplication) {
            if (normalizedSearchText !== "") {
              const search = normalizedSearchText.toLowerCase();
              const name = String(
                createdApplication.getValue("name") ?? "",
              ).toLowerCase();

              if (!name.includes(search)) {
                return;
              }
            }

            const connection = ConnectionHandler.getConnection(
              store.getRoot(),
              "Applications_applications",
              connectionFilter,
            );

            if (!connection) return;

            const newApplicationId = createdApplication.getDataID();
            const edges = connection.getLinkedRecords("edges") ?? [];
            const alreadyPresent = edges.some(
              (edge) =>
                edge.getLinkedRecord("node")?.getDataID() === newApplicationId,
            );
            if (alreadyPresent) return;

            const edge = ConnectionHandler.createEdge(
              store,
              connection,
              createdApplication,
              "ApplicationEdge",
            );

            ConnectionHandler.insertEdgeAfter(connection, edge);
          }

          const destroyedId = applicationEvent?.getValue("destroyed");
          if (!destroyedId || typeof destroyedId !== "string") return;

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "Applications_applications",
            connectionFilter,
          );
          if (!connection) return;

          ConnectionHandler.deleteNode(connection, destroyedId);
        },
      }),
      [connectionFilter, normalizedSearchText],
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
                or: [{ name: { ilike: `%${text}%` } }],
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

  const loadNextApplications = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const applicationsRef = data?.applications || null;

  if (!applicationsRef) {
    return null;
  }

  return (
    <ApplicationsTable
      onDelete={onDelete}
      applicationsRef={applicationsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextApplications : undefined}
    />
  );
};
interface ApplicationsContentProps {
  getApplicationsQuery: PreloadedQuery<Applications_getApplications_Query>;
}

const ApplicationsContent = ({
  getApplicationsQuery,
}: ApplicationsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [applicationToDelete, setApplicationToDelete] =
    useState<SelectedApplication | null>(null);

  const applicationsData = usePreloadedQuery(
    GET_APPLICATIONS_QUERY,
    getApplicationsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Applications.title"
            defaultMessage="Applications"
          />
        }
      >
        <Button as={Link} route={Route.applicationNew}>
          <FormattedMessage
            id="pages.Applications.createButton"
            defaultMessage="Create Application"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <ApplicationsLayoutContainer
          applicationsData={applicationsData}
          searchText={searchText}
          onDelete={setApplicationToDelete}
        />

        {applicationToDelete && (
          <DeleteApplicationModal
            applicationToDelete={applicationToDelete}
            onConfirm={() => setApplicationToDelete(null)}
            onCancel={() => setApplicationToDelete(null)}
            setErrorFeedback={setErrorFeedback}
          />
        )}
      </Page.Main>
    </Page>
  );
};

const ApplicationsPage = () => {
  const [getApplicationsQuery, getApplications] =
    useQueryLoader<Applications_getApplications_Query>(GET_APPLICATIONS_QUERY);

  const fetchApplications = useCallback(
    () =>
      getApplications(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getApplications],
  );

  useEffect(fetchApplications, [fetchApplications]);

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
        onReset={fetchApplications}
      >
        {getApplicationsQuery && (
          <ApplicationsContent getApplicationsQuery={getApplicationsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplicationsPage;
