/*
 * This file is part of Edgehog.
 *
 * Copyright 2024, 2025 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useState } from "react";
import { Form, Row, Col } from "react-bootstrap";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage, useIntl } from "react-intl";

import type {
  Application_getApplication_Query,
  Application_getApplication_Query$data,
} from "@/api/__generated__/Application_getApplication_Query.graphql";

import { Link, Route } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import ReleasesTable from "@/components/ReleasesTable";
import Button from "@/components/Button";
import ApplicationDevicesTable from "@/components/ApplicationDevicesTable";
import Tabs, { Tab } from "@/components/Tabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

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
      ...ReleasesTable_ReleaseFragment @arguments(filter: $filter)
      ...ApplicationDevicesTable_ReleaseFragment @arguments(filter: $filter)
    }
  }
`;

interface ApplicationContentProps {
  application: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
}

interface ReleasesTabProps {
  application: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
  setErrorFeedback: (error: React.ReactNode) => void;
}

const ReleasesTab = ({ application, setErrorFeedback }: ReleasesTabProps) => {
  const intl = useIntl();

  return (
    <Tab
      eventKey="releases-tab"
      title={intl.formatMessage({
        id: "pages.Application.releases",
        defaultMessage: "Releases",
      })}
    >
      <div className="mt-3">
        <ReleasesTable
          releasesRef={application}
          hideSearch
          setErrorFeedback={setErrorFeedback}
        />
      </div>
    </Tab>
  );
};

interface DevicesTabProps {
  application: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
}

const DevicesTab = ({ application }: DevicesTabProps) => {
  const intl = useIntl();

  return (
    <Tab
      eventKey="devices-tab"
      title={intl.formatMessage({
        id: "pages.Application.devices",
        defaultMessage: "Devices",
      })}
    >
      <div className="mt-3">
        <ApplicationDevicesTable
          applicationDevicesRef={application}
          hideSearch
        />
      </div>
    </Tab>
  );
};

const ApplicationContent = ({ application }: ApplicationContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

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
          <ReleasesTab
            application={application}
            setErrorFeedback={setErrorFeedback}
          />
          <DevicesTab application={application} />
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
        { applicationId, first: RECORDS_TO_LOAD_FIRST },
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
