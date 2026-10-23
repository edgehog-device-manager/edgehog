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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";
import { PayloadError } from "relay-runtime";

import type {
  Container_getContainer_Query,
  Container_getContainer_Query$data,
} from "@/api/__generated__/Container_getContainer_Query.graphql";
import type {
  Container_updateContainer_Mutation,
  UpdateContainerInput,
} from "@/api/__generated__/Container_updateContainer_Mutation.graphql";
import type { Container_deleteContainer_Mutation } from "@/api/__generated__/Container_deleteContainer_Mutation.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/ui/alert/Alert";
import Center from "@/components/ui/center/Center";
import { mapContainerToFormData } from "@/components/apps/containers/reuse-container-modal/ReuseContainerModal";
import DeleteModal from "@/components/ui/delete-modal/DeleteModal";
import Page from "@/components/ui/page/Page";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import CreateContainerForm from "@/forms/CreateContainer";

const GET_CONTAINER_QUERY = graphql`
  query Container_getContainer_Query($containerId: ID!) {
    container(id: $containerId) {
      ...ReuseContainerModal_ContainerFragment @relay(mask: false)
    }
    ...hooks_VolumesOptionsFragment
    ...hooks_ImageCredentialsOptionsFragment
    ...hooks_NetworksOptionsFragment
    ...hooks_FilesOptionsFragment
  }
`;

const UPDATE_CONTAINER_MUTATION = graphql`
  mutation Container_updateContainer_Mutation(
    $containerId: ID!
    $input: UpdateContainerInput!
  ) {
    updateContainer(id: $containerId, input: $input) {
      result {
        ...ReuseContainerModal_ContainerFragment @relay(mask: false)
      }
    }
  }
`;

const DELETE_CONTAINER_MUTATION = graphql`
  mutation Container_deleteContainer_Mutation($containerId: ID!) {
    deleteContainer(id: $containerId) {
      result {
        id
      }
    }
  }
`;

interface ContainerContentProps {
  queryData: Container_getContainer_Query$data;
  container: NonNullable<Container_getContainer_Query$data["container"]>;
}

const ContainerContent = ({ queryData, container }: ContainerContentProps) => {
  const { containerId = "" } = useParams();
  const navigate = useNavigate();

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [updateContainer, isUpdatingContainer] =
    useMutation<Container_updateContainer_Mutation>(UPDATE_CONTAINER_MUTATION);

  const [deleteContainer, isDeletingContainer] =
    useMutation<Container_deleteContainer_Mutation>(DELETE_CONTAINER_MUTATION);

  const initialData = useMemo(
    () => mapContainerToFormData(container, true),
    [container],
  );

  const handleAPIErrors = useCallback((errors: PayloadError[]) => {
    const errorFeedback = errors
      .map(({ fields, message }) =>
        fields.length ? `${fields.join(" ")} ${message}` : message,
      )
      .join(". \n");

    setErrorFeedback(errorFeedback);
  }, []);

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, []);

  const handleDeleteContainer = useCallback(() => {
    deleteContainer({
      variables: { containerId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.containers });
        }

        const errorFeedback = errors
          .map(({ fields, message }) =>
            fields.length ? `${fields.join(" ")} ${message}` : message,
          )
          .join(". \n");
        setErrorFeedback(errorFeedback);
        setShowDeleteModal(false);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.Container.deletionErrorFeedback"
            defaultMessage="Could not delete the Container, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
    });
  }, [deleteContainer, containerId, navigate]);

  const handleUpdateContainer = useCallback(
    (input: UpdateContainerInput) => {
      updateContainer({
        variables: {
          containerId,
          input,
        },
        onCompleted(_data, errors) {
          if (errors) {
            handleAPIErrors(errors);
            return;
          }

          setErrorFeedback(null);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Container.updateContainerErrorFeedback"
              defaultMessage="Could not update the container, please try again."
            />,
          );
        },
      });
    },
    [updateContainer, containerId, handleAPIErrors],
  );

  return (
    <Page>
      <Page.Header title={container.name} />

      <Page.Main>
        <div className="container-fluid px-0">
          <Alert
            show={!!errorFeedback}
            variant="danger"
            onClose={() => setErrorFeedback(null)}
            dismissible
            className="shadow-sm"
          >
            {errorFeedback}
          </Alert>

          <CreateContainerForm
            queryRef={queryData}
            initialData={initialData}
            onSubmit={handleUpdateContainer}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingContainer}
          />
        </div>

        {showDeleteModal && (
          <DeleteModal
            confirmText={container.name}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteContainer}
            isDeleting={isDeletingContainer}
            title={
              <FormattedMessage
                id="pages.Container.deleteModal.title"
                defaultMessage="Delete Container"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.Container.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Container <bold>{name}</bold>."
                values={{
                  name: container.name,
                  bold: (chunks) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

type ContainerWrapperProps = {
  getContainerQuery: PreloadedQuery<Container_getContainer_Query>;
};

const ContainerWrapper = ({ getContainerQuery }: ContainerWrapperProps) => {
  const queryData = usePreloadedQuery<Container_getContainer_Query>(
    GET_CONTAINER_QUERY,
    getContainerQuery,
  );

  if (!queryData.container) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Container.containerNotFound.title"
            defaultMessage="Container not found."
          />
        }
      >
        <Link route={Route.containers}>
          <FormattedMessage
            id="pages.Container.containerNotFound.message"
            defaultMessage="Return to the containers list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <ContainerContent queryData={queryData} container={queryData.container} />
  );
};

const ContainerPage = () => {
  const { containerId = "" } = useParams();

  const [getContainerQuery, getContainer] =
    useQueryLoader<Container_getContainer_Query>(GET_CONTAINER_QUERY);

  const fetchContainer = useCallback(
    () => getContainer({ containerId }, { fetchPolicy: "network-only" }),
    [getContainer, containerId],
  );

  useEffect(fetchContainer, [fetchContainer]);

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
        onReset={fetchContainer}
      >
        {getContainerQuery && (
          <ContainerWrapper getContainerQuery={getContainerQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ContainerPage;
