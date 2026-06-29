// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";

import type {
  ContainerCreate_createContainer_Mutation,
  CreateContainerInput,
} from "@/api/__generated__/ContainerCreate_createContainer_Mutation.graphql";
import type { ContainerCreate_getOptions_Query } from "@/api/__generated__/ContainerCreate_getOptions_Query.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import ReuseContainerModal from "@/components/ReuseContainerModal";
import Spinner from "@/components/Spinner";
import CreateContainerForm from "@/forms/CreateContainer";
import { ContainerInputData } from "@/forms/validation";
import { Route, useNavigate } from "@/Navigation";

const GET_CREATE_CONTAINER_OPTIONS_QUERY = graphql`
  query ContainerCreate_getOptions_Query {
    ...hooks_VolumesOptionsFragment
    ...hooks_ImageCredentialsOptionsFragment
    ...hooks_NetworksOptionsFragment
  }
`;

const CREATE_CONTAINER_MUTATION = graphql`
  mutation ContainerCreate_createContainer_Mutation(
    $input: CreateContainerInput!
  ) {
    createContainer(input: $input) {
      result {
        id
      }
    }
  }
`;

type ContainerProps = {
  getCreateContainerOptionsQuery: PreloadedQuery<ContainerCreate_getOptions_Query>;
};

const Container = ({ getCreateContainerOptionsQuery }: ContainerProps) => {
  const intl = useIntl();
  const navigate = useNavigate();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [showModal, setShowModal] = useState(false);
  const [initialData, setInitialData] = useState<Partial<ContainerInputData>>({
    name: "",
  });

  const containerCreateData =
    usePreloadedQuery<ContainerCreate_getOptions_Query>(
      GET_CREATE_CONTAINER_OPTIONS_QUERY,
      getCreateContainerOptionsQuery,
    );

  const [createContainer, isCreatingContainer] =
    useMutation<ContainerCreate_createContainer_Mutation>(
      CREATE_CONTAINER_MUTATION,
    );

  const handleCreateContainer = useCallback(
    (container: CreateContainerInput) => {
      createContainer({
        variables: {
          input: container,
        },

        onCompleted(data, errors) {
          const containerId = data?.createContainer?.result?.id;

          if (containerId) {
            navigate({
              route: Route.containersEdit,
              params: { containerId },
            });

            return;
          }

          if (errors?.length) {
            const formattedErrors = errors
              .map(({ fields, message }) =>
                fields?.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(".\n");

            setErrorFeedback(formattedErrors);
          }
        },

        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.ContainerCreate.creationErrorFeedback"
              defaultMessage="Could not create the Container, please try again."
            />,
          );
        },

        updater(store, data) {
          if (!data?.createContainer?.result) {
            return;
          }

          const container = store
            .getRootField("createContainer")
            ?.getLinkedRecord("result");

          const root = store.getRoot();

          const connection = ConnectionHandler.getConnection(
            root,
            "Containers_containers",
          );

          if (connection && container) {
            const edge = ConnectionHandler.createEdge(
              store,
              connection,
              container,
              "ContainerEdge",
            );

            ConnectionHandler.insertEdgeBefore(connection, edge);
          }
        },
      });
    },
    [createContainer, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ContainerCreate.title"
            defaultMessage="Create Container"
          />
        }
      >
        <Button
          variant="secondary"
          title={intl.formatMessage({
            id: "pages.ContainerCreate.reuseContainerTitleButton",
            defaultMessage: "Copy configuration from an existing container",
          })}
          onClick={() => setShowModal(true)}
        >
          <FormattedMessage
            id="pages.ContainerCreate.reuseContainerButton"
            defaultMessage="Reuse Container"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          dismissible
          onClose={() => setErrorFeedback(null)}
        >
          {errorFeedback}
        </Alert>

        <CreateContainerForm
          queryRef={containerCreateData}
          onSubmit={handleCreateContainer}
          isLoading={isCreatingContainer}
          initialData={initialData}
        />

        <ReuseContainerModal
          open={showModal}
          setInitialData={setInitialData}
          onToggleModal={setShowModal}
        />
      </Page.Main>
    </Page>
  );
};

type ContainerWrapperProps = {
  getCreateContainerOptionsQuery: PreloadedQuery<ContainerCreate_getOptions_Query>;
};

const ContainerWrapper = ({
  getCreateContainerOptionsQuery,
}: ContainerWrapperProps) => {
  return (
    <Container
      getCreateContainerOptionsQuery={getCreateContainerOptionsQuery}
    />
  );
};

const ContainerCreatePage = () => {
  const [getCreateContainerOptionsQuery, getCreateContainerOptions] =
    useQueryLoader<ContainerCreate_getOptions_Query>(
      GET_CREATE_CONTAINER_OPTIONS_QUERY,
    );

  const fetchCreateContainerOptions = useCallback(() => {
    getCreateContainerOptions(
      {},
      {
        fetchPolicy: "network-only",
      },
    );
  }, [getCreateContainerOptions]);

  useEffect(() => {
    fetchCreateContainerOptions();
  }, [fetchCreateContainerOptions]);

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
        onReset={fetchCreateContainerOptions}
      >
        {getCreateContainerOptionsQuery && (
          <ContainerWrapper
            getCreateContainerOptionsQuery={getCreateContainerOptionsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ContainerCreatePage;
