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
import type { ReactNode } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type {
  DeploymentCampaignCreate_getOptions_Query,
  DeploymentCampaignCreate_getOptions_Query$data,
} from "api/__generated__/DeploymentCampaignCreate_getOptions_Query.graphql";
import type { DeploymentCampaignCreate_CreateDeploymentCampaign_Mutation } from "api/__generated__/DeploymentCampaignCreate_CreateDeploymentCampaign_Mutation.graphql";

import Alert from "components/Alert";
import Button from "components/Button";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import CreateDeploymentCampaignForm from "forms/CreateDeploymentCampaign";
import type { DeploymentCampaignData } from "forms/CreateDeploymentCampaign";
import { Link, Route, useNavigate } from "Navigation";

const GET_CREATE_DEPLOYMENT_CAMPAIGN_OPTIONS_QUERY = graphql`
  query DeploymentCampaignCreate_getOptions_Query {
    applications {
      __typename
      count
    }
    channels {
      __typename
      count
    }
    ...CreateDeploymentCampaign_OptionsFragment
  }
`;

const CREATE_DEPLOYMENT_CAMPAIGN_MUTATION = graphql`
  mutation DeploymentCampaignCreate_CreateDeploymentCampaign_Mutation(
    $input: CreateDeploymentCampaignInput!
  ) {
    createDeploymentCampaign(input: $input) {
      result {
        id
      }
    }
  }
`;

type DeploymentCampaignProps = {
  deploymentCampaignOptions: DeploymentCampaignCreate_getOptions_Query$data;
};

const DeploymentCampaign = ({
  deploymentCampaignOptions,
}: DeploymentCampaignProps) => {
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

  const [CreateDeploymentCampaign, isCreatingDeploymentCampaign] =
    useMutation<DeploymentCampaignCreate_CreateDeploymentCampaign_Mutation>(
      CREATE_DEPLOYMENT_CAMPAIGN_MUTATION,
    );

  const handleCreateDeploymentCampaign = useCallback(
    (deploymentCampaign: DeploymentCampaignData) => {
      CreateDeploymentCampaign({
        variables: { input: deploymentCampaign },
        onCompleted(data, errors) {
          if (data.createDeploymentCampaign?.result) {
            const deploymentCampaignId =
              data.createDeploymentCampaign.result.id;
            navigate({
              route: Route.deploymentCampaignsEdit,
              params: { deploymentCampaignId },
            });
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.DeploymentCampaignCreate.creationErrorFeedback"
              defaultMessage="Could not create the Deployment Campaign, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createDeploymentCampaign?.result) {
            return;
          }

          const deploymentCampaign = store
            .getRootField("createDeploymentCampaign")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const deploymentCampaigns = root.getLinkedRecords(
            "deploymentCampaigns",
          );
          if (deploymentCampaigns) {
            root.setLinkedRecords(
              [...deploymentCampaigns, deploymentCampaign],
              "deploymentCampaigns",
            );
          }
        },
      });
    },
    [CreateDeploymentCampaign, navigate],
  );

  return (
    <>
      <Alert
        show={!!errorFeedback}
        variant="danger"
        onClose={() => setErrorFeedback(null)}
        dismissible
      >
        {errorFeedback}
      </Alert>
      <CreateDeploymentCampaignForm
        deploymentCampaignOptionsRef={deploymentCampaignOptions}
        onSubmit={handleCreateDeploymentCampaign}
        isLoading={isCreatingDeploymentCampaign}
      />
    </>
  );
};

const NoApplications = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.DeploymentCampaignCreate.noApplication.title"
        defaultMessage="You haven't created any Application yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.DeploymentCampaignCreate.noApplication.message"
        defaultMessage="You need at least one Application with Release to create a Deployment Campaign"
      />
    </p>
    <Button as={Link} route={Route.applicationNew}>
      <FormattedMessage
        id="pages.DeploymentApplication.noApplication.createButton"
        defaultMessage="Create Application"
      />
    </Button>
  </Result.EmptyList>
);

const NoChannels = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.DeploymentCampaignCreate.noChannel.title"
        defaultMessage="You haven't created any Channel yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.DeploymentCampaignCreate.noChannel.message"
        defaultMessage="You need at least one Channel to create a Deployment Campaign"
      />
    </p>
    <Button as={Link} route={Route.channelsNew}>
      <FormattedMessage
        id="pages.DeploymentCampaignCreate.noChannel.createButton"
        defaultMessage="Create Channel"
      />
    </Button>
  </Result.EmptyList>
);

type DeploymentCampaignWrapperProps = {
  getCreateDeploymentCampaignOptionsQuery: PreloadedQuery<DeploymentCampaignCreate_getOptions_Query>;
};

const DeploymentCampaignWrapper = ({
  getCreateDeploymentCampaignOptionsQuery,
}: DeploymentCampaignWrapperProps) => {
  const deploymentCampaignOptions = usePreloadedQuery(
    GET_CREATE_DEPLOYMENT_CAMPAIGN_OPTIONS_QUERY,
    getCreateDeploymentCampaignOptionsQuery,
  );
  const { channels, applications } = deploymentCampaignOptions;

  if (applications?.count === 0) {
    return <NoApplications />;
  }

  if (channels?.count === 0) {
    return <NoChannels />;
  }

  return (
    <DeploymentCampaign deploymentCampaignOptions={deploymentCampaignOptions} />
  );
};

const DeploymentCampaignCreatePage = () => {
  const [
    getCreateDeploymentCampaignOptionsQuery,
    getCreateDeploymentCampaignOptions,
  ] = useQueryLoader<DeploymentCampaignCreate_getOptions_Query>(
    GET_CREATE_DEPLOYMENT_CAMPAIGN_OPTIONS_QUERY,
  );

  const fetchCreateDeploymentCampaignOptions = useCallback(
    () =>
      getCreateDeploymentCampaignOptions({}, { fetchPolicy: "network-only" }),
    [getCreateDeploymentCampaignOptions],
  );

  useEffect(fetchCreateDeploymentCampaignOptions, [
    fetchCreateDeploymentCampaignOptions,
  ]);

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
        onReset={fetchCreateDeploymentCampaignOptions}
      >
        {getCreateDeploymentCampaignOptionsQuery && (
          <Page>
            <Page.Header
              title={
                <FormattedMessage
                  id="pages.DeploymentCampaignCreate.title"
                  defaultMessage="Create Deployment Campaign"
                />
              }
            />
            <Page.Main>
              <DeploymentCampaignWrapper
                getCreateDeploymentCampaignOptionsQuery={
                  getCreateDeploymentCampaignOptionsQuery
                }
              />
            </Page.Main>
          </Page>
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentCampaignCreatePage;
