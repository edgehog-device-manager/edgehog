/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { Suspense, useCallback, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { Applications_getApplications_Query } from "api/__generated__/Applications_getApplications_Query.graphql";

import Page from "components/Page";
import Center from "components/Center";
import Spinner from "components/Spinner";
import ApplicationsTable from "components/ApplicationsTable";

const GET_APPLICATIONS_QUERY = graphql`
  query Applications_getApplications_Query {
    applications {
      results {
        ...ApplicationsTable_ApplicationFragment
      }
    }
  }
`;

interface ApplicationsContentProps {
  getApplicationsQuery: PreloadedQuery<Applications_getApplications_Query>;
}

const ApplicationsContent = ({
  getApplicationsQuery,
}: ApplicationsContentProps) => {
  const { applications } = usePreloadedQuery(
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
      />
      <Page.Main>
        <ApplicationsTable applicationsRef={applications?.results ?? []} />
      </Page.Main>
    </Page>
  );
};

const ApplicationsPage = () => {
  const [getApplicationsQuery, getApplications] =
    useQueryLoader<Applications_getApplications_Query>(GET_APPLICATIONS_QUERY);

  const fetchApplications = useCallback(
    () => getApplications({}, { fetchPolicy: "store-and-network" }),
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
