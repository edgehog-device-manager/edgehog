/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

/* eslint-disable relay/unused-fields */

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  useSubscription,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type {
  Deployment_getDeployment_Query,
  Deployment_getDeployment_Query$data,
} from "@/api/__generated__/Deployment_getDeployment_Query.graphql";
import type { Deployment_deployment_updated_Subscription } from "@/api/__generated__/Deployment_deployment_updated_Subscription.graphql";
import type { Deployment_sendDeployment_Mutation } from "@/api/__generated__/Deployment_sendDeployment_Mutation.graphql";
import type { Deployment_startDeployment_Mutation } from "@/api/__generated__/Deployment_startDeployment_Mutation.graphql";
import type { Deployment_stopDeployment_Mutation } from "@/api/__generated__/Deployment_stopDeployment_Mutation.graphql";
import type { Deployment_upgradeDeployment_Mutation } from "@/api/__generated__/Deployment_upgradeDeployment_Mutation.graphql";
import type { Deployment_deleteDeployment_Mutation } from "@/api/__generated__/Deployment_deleteDeployment_Mutation.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import DeploymentDetails from "@/components/DeploymentDetails";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";

const handleMutationCompletion = (
  errors: readonly any[] | null | undefined,
  setErrorFeedback: (msg: React.ReactNode) => void,
  onSuccess?: () => void,
) => {
  if (errors && errors.length > 0) {
    const errorMessage = errors
      .map(({ fields, message }) =>
        fields?.length ? `${fields.join(" ")} ${message}` : message,
      )
      .join(". \n");

    setErrorFeedback(errorMessage);
    return;
  }

  setErrorFeedback(null);
  onSuccess?.();
};

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
        online
        systemModel {
          id
          name
        }
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

const DEPLOYMENT_UPDATED_SUBSCRIPTION = graphql`
  subscription Deployment_deployment_updated_Subscription(
    $deploymentId: ID!
    $first: Int
    $after: String
  ) {
    deploymentById(deploymentId: $deploymentId) {
      updated {
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
  }
`;

const SEND_DEPLOYMENT_MUTATION = graphql`
  mutation Deployment_sendDeployment_Mutation($id: ID!) {
    sendDeployment(id: $id) {
      result {
        id
        state
      }
      errors {
        message
      }
    }
  }
`;

const START_DEPLOYMENT_MUTATION = graphql`
  mutation Deployment_startDeployment_Mutation($id: ID!) {
    startDeployment(id: $id) {
      result {
        id
      }
      errors {
        message
      }
    }
  }
`;

const STOP_DEPLOYMENT_MUTATION = graphql`
  mutation Deployment_stopDeployment_Mutation($id: ID!) {
    stopDeployment(id: $id) {
      result {
        id
      }
      errors {
        message
      }
    }
  }
`;

const DELETE_DEPLOYMENT_MUTATION = graphql`
  mutation Deployment_deleteDeployment_Mutation($id: ID!) {
    deleteDeployment(id: $id) {
      result {
        id
      }
    }
  }
`;

const UPGRADE_DEPLOYMENT_MUTATION = graphql`
  mutation Deployment_upgradeDeployment_Mutation(
    $id: ID!
    $input: UpgradeDeploymentInput!
  ) {
    upgradeDeployment(id: $id, input: $input) {
      result {
        id
      }
    }
  }
`;

interface DeploymentContentProps {
  deployment: NonNullable<Deployment_getDeployment_Query$data["deployment"]>;
  isOnline: boolean;
}

const DeploymentContent = ({
  deployment,
  isOnline,
}: DeploymentContentProps) => {
  const navigate = useNavigate();
  const { deviceId } = useParams();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [sendDeployment] = useMutation<Deployment_sendDeployment_Mutation>(
    SEND_DEPLOYMENT_MUTATION,
  );
  const [startDeployment] = useMutation<Deployment_startDeployment_Mutation>(
    START_DEPLOYMENT_MUTATION,
  );
  const [stopDeployment] = useMutation<Deployment_stopDeployment_Mutation>(
    STOP_DEPLOYMENT_MUTATION,
  );

  const [deleteDeployment, isDeletingDeployment] =
    useMutation<Deployment_deleteDeployment_Mutation>(
      DELETE_DEPLOYMENT_MUTATION,
    );

  const [upgradeDeployment] =
    useMutation<Deployment_upgradeDeployment_Mutation>(
      UPGRADE_DEPLOYMENT_MUTATION,
    );

  const handleSendDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="pages.Deployment.sendErrorOffline"
            defaultMessage="The device is disconnected. You cannot deploy an application while it is offline."
          />,
        );
      }

      sendDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          handleMutationCompletion(errors, setErrorFeedback);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Deployment.sendErrorFeedback"
              defaultMessage="Could not send the Application to the device, please try again."
            />,
          );
        },
      });
    },
    [isOnline, sendDeployment, setErrorFeedback],
  );

  const handleStartDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="pages.Deployment.startErrorOffline"
            defaultMessage="The device is disconnected. You cannot start an application while it is offline."
          />,
        );
      }

      startDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          handleMutationCompletion(errors, setErrorFeedback);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Deployment.startErrorFeedback"
              defaultMessage="Could not Start the Deployed Application, please try again."
            />,
          );
        },
      });
    },
    [isOnline, startDeployment, setErrorFeedback],
  );

  const handleStopDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="pages.Deployment.stopErrorOffline"
            defaultMessage="The device is disconnected. You cannot stop an application while it is offline."
          />,
        );
      }

      stopDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          handleMutationCompletion(errors, setErrorFeedback);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Deployment.stopErrorFeedback"
              defaultMessage="Could not Stop the Deployed Application, please try again."
            />,
          );
        },
      });
    },
    [isOnline, stopDeployment, setErrorFeedback],
  );

  const handleDeleteDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="pages.Deployment.deleteErrorOffline"
            defaultMessage="The device is disconnected. You cannot delete an application while it is offline."
          />,
        );
      }

      deleteDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          handleMutationCompletion(errors, setErrorFeedback, () => {
            if (deviceId) {
              navigate({
                route: Route.devicesEdit,
                params: { deviceId },
              });
            }
          });
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Deployment.deletionErrorFeedback"
              defaultMessage="Could not delete the deployment, please try again."
            />,
          );
        },
      });
    },
    [deleteDeployment, setErrorFeedback, navigate, deviceId, isOnline],
  );

  const handleUpgradeDeployedRelease = useCallback(
    (deploymentId: string, upgradeTargetReleaseId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="pages.Deployment.upgradeErrorOffline"
            defaultMessage="The device is disconnected. You cannot upgrade an application while it is offline."
          />,
        );
      }

      upgradeDeployment({
        variables: {
          id: deploymentId,
          input: { target: upgradeTargetReleaseId },
        },
        onCompleted: (data, errors) => {
          handleMutationCompletion(errors, setErrorFeedback, () => {
            if (deviceId && data?.upgradeDeployment?.result?.id) {
              navigate({
                route: Route.deploymentEdit,
                params: {
                  deviceId,
                  deploymentId: data.upgradeDeployment.result.id,
                },
              });
            }
          });
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Deployment.upgradeErrorFeedback"
              defaultMessage="Could not upgrade the deployment, please try again."
            />,
          );
        },
      });
    },
    [upgradeDeployment, setErrorFeedback, isOnline, deviceId, navigate],
  );

  return (
    <Page className="h-100 d-flex flex-column overflow-hidden">
      <Page.Header
        title={`${deployment.release?.application?.name}: ${deployment.release?.version}`}
      />
      <Page.Main
        className="d-flex flex-column flex-grow-1"
        style={{
          minHeight: 0,
        }}
      >
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>

        <DeploymentDetails
          deploymentRef={deployment}
          isDeletingDeployment={isDeletingDeployment}
          setErrorFeedback={setErrorFeedback}
          onStart={handleStartDeployedApplication}
          onStop={handleStopDeployedApplication}
          onRedeploy={handleSendDeployedApplication}
          onDelete={handleDeleteDeployedApplication}
          onUpgrade={handleUpgradeDeployedRelease}
        />
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
  const isOnline = deployment?.device?.online ?? false;

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
        <Link route={Route.devicesEdit} params={{ deviceId }}>
          <FormattedMessage
            id="pages.Deployment.deploymentNotFound.message"
            defaultMessage="Return to the device page."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <DeploymentContent deployment={deployment} isOnline={isOnline} />;
};

const DeploymentPage = () => {
  const { deploymentId = "", deviceId = "" } = useParams();

  const [getDeploymentQuery, getDeployment] =
    useQueryLoader<Deployment_getDeployment_Query>(GET_DEPLOYMENT_QUERY);

  const fetchDeployment = useCallback(
    () => getDeployment({ deploymentId }, { fetchPolicy: "network-only" }),
    [getDeployment, deploymentId],
  );

  useSubscription<Deployment_deployment_updated_Subscription>(
    useMemo(
      () => ({
        subscription: DEPLOYMENT_UPDATED_SUBSCRIPTION,
        variables: { deploymentId },
      }),
      [deploymentId],
    ),
  );

  useEffect(fetchDeployment, [fetchDeployment]);

  return (
    <Suspense
      fallback={
        <Center>
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center>
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
