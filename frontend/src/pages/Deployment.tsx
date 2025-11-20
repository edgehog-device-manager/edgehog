/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type {
  Deployment_getDeployment_Query,
  Deployment_getDeployment_Query$data,
} from "api/__generated__/Deployment_getDeployment_Query.graphql";

import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import DeploymentDetails from "components/DeploymentDetails";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";

const GET_DEPLOYMENT_QUERY = graphql`
  query Deployment_getDeployment_Query(
    $deploymentId: ID!
    $first: Int
    $after: String
  ) {
    deployment(id: $deploymentId) {
      id
      state
      isReady
      device {
        name
      }
      release {
        id
        version
        application {
          id
          name
          releases {
            edges {
              node {
                id
                version
                systemModels {
                  name
                }
              }
            }
          }
        }
      }
      ...DeploymentDetails_events
      ...DeploymentDetails_containerDeployments
    }
  }
`;

interface DeploymentContentProps {
  deployment: NonNullable<Deployment_getDeployment_Query$data["deployment"]>;
}

const DeploymentContent = ({ deployment }: DeploymentContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  return (
    <Page>
      <Page.Header
        title={`${deployment.release?.application?.name}: ${deployment.release?.version}`}
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
        <DeploymentDetails deploymentRef={deployment} />
      </Page.Main>
    </Page>
  );
};

type DeploymentWrapperProps = {
  getDeploymentQuery: PreloadedQuery<Deployment_getDeployment_Query>;
  deviceId: string;
};

const DeploymentWrapper = ({
  getDeploymentQuery,
  deviceId,
}: DeploymentWrapperProps) => {
  const { deployment } = usePreloadedQuery(
    GET_DEPLOYMENT_QUERY,
    getDeploymentQuery,
  );

  if (!deployment) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Deployment.deploymentNotFound.title"
            defaultMessage="Deployment not found."
          />
        }
      >
        <Link route={Route.devicesEdit} params={{ deviceId: deviceId }}>
          <FormattedMessage
            id="pages.Deployment.deploymentNotFound.message"
            defaultMessage="Return to the device page."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <DeploymentContent deployment={deployment} />;
};

const DeploymentPage = () => {
  const { deploymentId = "" } = useParams();
  const { deviceId = "" } = useParams();

  const [getDeploymentQuery, getDeployment] =
    useQueryLoader<Deployment_getDeployment_Query>(GET_DEPLOYMENT_QUERY);

  const fetchDeployment = useCallback(
    () => getDeployment({ deploymentId }, { fetchPolicy: "network-only" }),
    [getDeployment, deploymentId],
  );

  useEffect(fetchDeployment, [fetchDeployment]);

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
        onReset={fetchDeployment}
      >
        {getDeploymentQuery && (
          <DeploymentWrapper
            getDeploymentQuery={getDeploymentQuery}
            deviceId={deviceId}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentPage;
