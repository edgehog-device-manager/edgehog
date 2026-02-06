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
import { Col, Form, Row } from "react-bootstrap";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import { Application_ReleasesFragment$key } from "@/api/__generated__/Application_ReleasesFragment.graphql";
import type {
  Application_getApplication_Query,
  Application_getApplication_Query$data,
} from "@/api/__generated__/Application_getApplication_Query.graphql";
import { Releases_PaginationQuery } from "@/api/__generated__/Releases_PaginationQuery.graphql";

import { Link, Route } from "@/Navigation";
import Alert from "@/components/Alert";
import ApplicationDevicesTable from "@/components/ApplicationDevicesTable";
import Button from "@/components/Button";
import Center from "@/components/Center";
import DeleteReleaseModal from "@/components/DeleteReleaseModal";
import Page from "@/components/Page";
import type { ReleaseTableRecord } from "@/components/ReleasesTable";
import ReleasesTable from "@/components/ReleasesTable";
import Result from "@/components/Result";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import Tabs, { Tab } from "@/components/Tabs";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

const GET_APPLICATION_QUERY = graphql`
  query Application_getApplication_Query(
    $applicationId: ID!
    $first: Int
    $after: String
    $filter: ReleaseFilterInput = {}
  ) {
    application(id: $applicationId) {
      name
      description
      ...Application_ReleasesFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

/* eslint-disable relay/unused-fields */
const RELEASES_FRAGMENT = graphql`
  fragment Application_ReleasesFragment on Application
  @refetchable(queryName: "Releases_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: { type: "ReleaseFilterInput", defaultValue: {} }
  ) {
    id
    releases(first: $first, after: $after, filter: $filter)
      @connection(key: "Application_releases") {
      edges {
        node {
          __typename
        }
      }
      ...ReleasesTable_ReleaseEdgeFragment
      ...ApplicationDevicesTable_ReleaseEdgeFragment
    }
  }
`;

type SelectedRelease = ReleaseTableRecord;

interface ApplicationContentProps {
  application: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
}

interface ReleasesLayoutContainerProps {
  applicationRef: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
  searchText: string | null;
  onDelete: (release: SelectedRelease) => void;
}

const ReleasesLayoutContainer = ({
  applicationRef,
  searchText,
  onDelete,
}: ReleasesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Releases_PaginationQuery,
      Application_ReleasesFragment$key
    >(RELEASES_FRAGMENT, applicationRef);

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
              filter: { version: { ilike: `%${text}%` } },
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

    return () => {
      debounceRefetch.cancel();
    };
  }, [debounceRefetch, searchText]);

  const loadNextReleases = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const releasesRef = data?.releases;

  if (!releasesRef) {
    return null;
  }

  return (
    <div className="mt-3">
      <ReleasesTable
        onDelete={onDelete}
        releasesRef={releasesRef}
        loading={isLoadingNext}
        onLoadMore={hasNext ? loadNextReleases : undefined}
      />
    </div>
  );
};

interface DevicesLayoutContainerProps {
  applicationRef: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
}

const DevicesLayoutContainer = ({
  applicationRef,
}: DevicesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext } = usePaginationFragment<
    Releases_PaginationQuery,
    Application_ReleasesFragment$key
  >(RELEASES_FRAGMENT, applicationRef);

  const loadNextApplicationDevices = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const applicationDevicesRef = data?.releases;

  if (!applicationDevicesRef) {
    return null;
  }

  return (
    <div className="mt-3">
      <ApplicationDevicesTable
        applicationDevicesRef={applicationDevicesRef}
        loading={isLoadingNext}
        onLoadMore={hasNext ? loadNextApplicationDevices : undefined}
      />
    </div>
  );
};

const ApplicationContent = ({ application }: ApplicationContentProps) => {
  const intl = useIntl();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [searchText, setSearchText] = useState<string | null>(null);
  const [releaseToDelete, setReleaseToDelete] =
    useState<SelectedRelease | null>(null);
  const { applicationId = "" } = useParams();

  return (
    <Page>
      <Page.Header title={application.name}>
        <Button
          as={Link}
          route={Route.releaseNew}
          params={{ applicationId: applicationId }}
        >
          <FormattedMessage
            id="pages.Application.createButton"
            defaultMessage="Create Release"
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

        <Form.Group as={Row} controlId="application" className="mt-3 mb-4">
          <Form.Label column sm={2}>
            <FormattedMessage
              id="pages.Application.description"
              defaultMessage="Description"
            />
          </Form.Label>
          <Col sm={10}>
            <Form.Control
              as="textarea"
              value={application.description ?? ""}
              rows={5}
              readOnly
            />
          </Col>
        </Form.Group>

        <Tabs
          defaultActiveKey="releases-tab"
          tabsOrder={["releases-tab", "devices-tab"]}
        >
          <Tab
            eventKey="releases-tab"
            title={intl.formatMessage({
              id: "pages.Application.releases",
              defaultMessage: "Releases",
            })}
          >
            <SearchBox
              className="flex-grow-1 pb-2 pt-2"
              value={searchText || ""}
              onChange={setSearchText}
            />
            <ReleasesLayoutContainer
              applicationRef={application}
              searchText={searchText}
              onDelete={setReleaseToDelete}
            />
            {releaseToDelete && (
              <DeleteReleaseModal
                releaseToDelete={releaseToDelete}
                onConfirm={() => setReleaseToDelete(null)}
                onCancel={() => setReleaseToDelete(null)}
                setErrorFeedback={setErrorFeedback}
              />
            )}
          </Tab>

          <Tab
            eventKey="devices-tab"
            title={intl.formatMessage({
              id: "pages.Application.devices",
              defaultMessage: "Devices",
            })}
          >
            <DevicesLayoutContainer applicationRef={application} />
          </Tab>
        </Tabs>
      </Page.Main>
    </Page>
  );
};

type ApplicationWrapperProps = {
  getApplicationQuery: PreloadedQuery<Application_getApplication_Query>;
};

const ApplicationWrapper = ({
  getApplicationQuery,
}: ApplicationWrapperProps) => {
  const { application } = usePreloadedQuery(
    GET_APPLICATION_QUERY,
    getApplicationQuery,
  );

  if (!application) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Application.applicationNotFound.title"
            defaultMessage="Application not found."
          />
        }
      >
        <Link route={Route.applications}>
          <FormattedMessage
            id="pages.Application.applicationNotFound.message"
            defaultMessage="Return to the applications list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <ApplicationContent application={application} />;
};

const ApplicationPage = () => {
  const { applicationId = "" } = useParams();

  const [getApplicationQuery, getApplication] =
    useQueryLoader<Application_getApplication_Query>(GET_APPLICATION_QUERY);

  const fetchApplication = useCallback(
    () =>
      getApplication(
        { applicationId, first: 10 },
        { fetchPolicy: "network-only" },
      ),
    [getApplication, applicationId],
  );

  useEffect(fetchApplication, [fetchApplication]);

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
        onReset={fetchApplication}
      >
        {getApplicationQuery && (
          <ApplicationWrapper getApplicationQuery={getApplicationQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplicationPage;
