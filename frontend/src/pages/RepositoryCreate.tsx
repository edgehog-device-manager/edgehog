/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { Suspense, useCallback, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import { ConnectionHandler, graphql, useMutation } from "react-relay/hooks";

import type { RepositoryCreate_createRepository_Mutation } from "@/api/__generated__/RepositoryCreate_createRepository_Mutation.graphql";

import Alert from "@/components/Alert";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Spinner from "@/components/Spinner";
import CreateRepositoryForm from "@/forms/CreateRepository";
import { RepositoryFormData } from "@/forms/validation";
import { Route, useNavigate } from "@/Navigation";

const CREATE_REPOSITORY_MUTATION = graphql`
  mutation RepositoryCreate_createRepository_Mutation(
    $input: CreateRepositoryInput!
  ) {
    createRepository(input: $input) {
      result {
        id
        name
        handle
        description
      }
    }
  }
`;

const Repository = () => {
  const navigate = useNavigate();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [createRepository, isCreatingRepository] =
    useMutation<RepositoryCreate_createRepository_Mutation>(
      CREATE_REPOSITORY_MUTATION,
    );

  const handleCreateRepository = useCallback(
    (repository: RepositoryFormData) => {
      const newRepository = { ...repository };

      createRepository({
        variables: { input: newRepository },
        onCompleted(data, errors) {
          const repositoryId = data.createRepository?.result?.id;
          if (repositoryId) {
            return navigate({
              route: Route.repositoryEdit,
              params: { repositoryId },
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
              id="pages.RepositoryCreate.creationErrorFeedback"
              defaultMessage="Could not create the repository, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createRepository?.result?.id) {
            return;
          }

          const repository = store
            .getRootField("createRepository")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const connection = ConnectionHandler.getConnection(
            root,
            "Repositories_repositories",
          );

          if (connection && repository) {
            const edge = ConnectionHandler.createEdge(
              store,
              connection,
              repository,
              "RepositoryEdge",
            );
            ConnectionHandler.insertEdgeBefore(connection, edge);
          }
        },
      });
    },
    [createRepository, navigate],
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
      <CreateRepositoryForm
        onSubmit={handleCreateRepository}
        isLoading={isCreatingRepository}
      />
    </>
  );
};

const RepositoryWrapper = () => {
  return <Repository />;
};

const RepositoryCreatePage = () => {
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
      >
        <Page>
          <Page.Header
            title={
              <FormattedMessage
                id="pages.RepositoryCreate.title"
                defaultMessage="Create Repository"
              />
            }
          />
          <Page.Main>
            <RepositoryWrapper />
          </Page.Main>
        </Page>
      </ErrorBoundary>
    </Suspense>
  );
};

export default RepositoryCreatePage;
