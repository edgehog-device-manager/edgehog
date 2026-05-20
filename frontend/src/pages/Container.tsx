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
import { Container_updateContainer_Mutation } from "@/api/__generated__/Container_updateContainer_Mutation.graphql";

import { Link, Route } from "@/Navigation";
import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import ContainerDetails from "@/components/ContainerDetails";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Icon from "@/components/Icon";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";

const GET_CONTAINER_QUERY = graphql`
  query Container_getContainer_Query($containerId: ID!) {
    container(id: $containerId) {
      id
      name
      ...ContainerDetailsFragment
    }
  }
`;

const UPDATE_CONTAINER_MUTATION = graphql`
  mutation Container_updateContainer_Mutation(
    $containerId: ID!
    $input: UpdateContainerInput!
  ) {
    updateContainer(id: $containerId, input: $input) {
      result {
        id
        name
      }
    }
  }
`;

interface ContainerContentProps {
  container: NonNullable<Container_getContainer_Query$data["container"]>;
}

const ContainerContent = ({ container }: ContainerContentProps) => {
  const { containerId = "" } = useParams();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [containerDraftName, setContainerDraftName] = useState(
    container?.name || "",
  );
  const [isSavingName, setIsSavingName] = useState(false);
  const [isEditingName, setIsEditingName] = useState(false);

  const [updateContainer] = useMutation<Container_updateContainer_Mutation>(
    UPDATE_CONTAINER_MUTATION,
  );

  const handleAPIErrors = useCallback((errors: PayloadError[]) => {
    const errorFeedback = errors
      .map(({ fields, message }) =>
        fields.length ? `${fields.join(" ")} ${message}` : message,
      )
      .join(". \n");

    setErrorFeedback(errorFeedback);
  }, []);

  const handleEditClick = useCallback(() => {
    setIsSavingName(true);

    updateContainer({
      variables: {
        containerId,
        input: { name: containerDraftName },
      },
      onCompleted(_data, errors) {
        setIsSavingName(false);

        if (errors) {
          handleAPIErrors(errors);
          return;
        }

        setIsEditingName(false);
      },
      onError() {
        setIsSavingName(false);

        setErrorFeedback(
          <FormattedMessage
            id="pages.Container.updateContainerErrorFeedback"
            defaultMessage="Could not update the container, please try again."
          />,
        );
      },
    });
  }, [containerDraftName, updateContainer, containerId, handleAPIErrors]);

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

          <div className="ps-2 border-bottom mb-3">
            <FormRow
              id="name"
              label={
                <FormattedMessage
                  id="pages.Container.name"
                  defaultMessage="Container Name"
                />
              }
            >
              <div className="position-relative w-100 mb-2">
                <Form.Control
                  type="text"
                  value={containerDraftName}
                  readOnly={!isEditingName}
                  onChange={(e) => setContainerDraftName(e.target.value)}
                  className="pe-5"
                />

                <div
                  className="position-absolute top-50 end-0 translate-middle-y d-flex align-items-center gap-2 pe-3"
                  style={{ zIndex: 5 }}
                >
                  {isEditingName ? (
                    <>
                      <Button
                        type="button"
                        className="border-0 bg-transparent p-0 d-flex"
                        disabled={isSavingName}
                        onClick={handleEditClick}
                      >
                        <Icon icon="check" className="text-success" />
                      </Button>

                      <Icon
                        icon="xMark"
                        className="text-danger"
                        role="button"
                        onClick={() => {
                          setContainerDraftName(container.name);
                          setIsEditingName(false);
                        }}
                      />
                    </>
                  ) : (
                    <Icon
                      icon="edit"
                      className="text-secondary"
                      role="button"
                      onClick={() => setIsEditingName(true)}
                    />
                  )}
                </div>
              </div>
            </FormRow>
          </div>

          <ContainerDetails container={container} />
        </div>
      </Page.Main>
    </Page>
  );
};

type ContainerWrapperProps = {
  getContainerQuery: PreloadedQuery<Container_getContainer_Query>;
};

const ContainerWrapper = ({ getContainerQuery }: ContainerWrapperProps) => {
  const { container } = usePreloadedQuery(
    GET_CONTAINER_QUERY,
    getContainerQuery,
  );

  if (!container) {
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

  return <ContainerContent container={container} />;
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
