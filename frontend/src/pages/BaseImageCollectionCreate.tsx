/*
  This file is part of Edgehog.

  Copyright 2023-2025 SECO Mind Srl

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
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type {
  BaseImageCollectionCreate_getOptions_Query,
  BaseImageCollectionCreate_getOptions_Query$data,
} from "api/__generated__/BaseImageCollectionCreate_getOptions_Query.graphql";
import type { BaseImageCollectionCreate_createBaseImageCollection_Mutation } from "api/__generated__/BaseImageCollectionCreate_createBaseImageCollection_Mutation.graphql";
import Alert from "components/Alert";
import Button from "components/Button";
import Center from "components/Center";
import CreateBaseImageCollectionForm from "forms/CreateBaseImageCollection";
import type { BaseImageCollectionData } from "forms/CreateBaseImageCollection";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import { Link, Route, useNavigate } from "Navigation";

const CREATE_BASE_IMAGE_COLLECTION_PAGE_QUERY = graphql`
  query BaseImageCollectionCreate_getOptions_Query {
    systemModels {
      __typename
      count
    }
    ...CreateBaseImageCollection_OptionsFragment
  }
`;

const CREATE_BASE_IMAGE_COLLECTION_MUTATION = graphql`
  mutation BaseImageCollectionCreate_createBaseImageCollection_Mutation(
    $input: CreateBaseImageCollectionInput!
  ) {
    createBaseImageCollection(input: $input) {
      result {
        id
      }
    }
  }
`;

type BaseImageCollectionProps = {
  baseImageCollectionOptions: BaseImageCollectionCreate_getOptions_Query$data;
};

const BaseImageCollection = ({
  baseImageCollectionOptions,
}: BaseImageCollectionProps) => {
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [createBaseImageCollection, isCreatingBaseImageCollection] =
    useMutation<BaseImageCollectionCreate_createBaseImageCollection_Mutation>(
      CREATE_BASE_IMAGE_COLLECTION_MUTATION,
    );

  const handleCreateBaseImageCollection = useCallback(
    (baseImageCollection: BaseImageCollectionData) => {
      const newBaseImageCollection = { ...baseImageCollection };
      createBaseImageCollection({
        variables: { input: newBaseImageCollection },
        onCompleted(data, errors) {
          const baseImageCollectionId =
            data.createBaseImageCollection?.result?.id;
          if (baseImageCollectionId) {
            return navigate({
              route: Route.baseImageCollectionsEdit,
              params: { baseImageCollectionId },
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
              id="pages.BaseImageCollectionCreate.creationErrorFeedback"
              defaultMessage="Could not create the Base Image Collection, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createBaseImageCollection?.result) {
            return;
          }

          const baseImageCollection = store
            .getRootField("createBaseImageCollection")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const connection = ConnectionHandler.getConnection(
            root,
            "BaseImageCollectionsTable_baseImageCollections",
          );

          if (connection && baseImageCollection) {
            const edge = ConnectionHandler.createEdge(
              store,
              connection,
              baseImageCollection,
              "BaseImageCollectionEdge",
            );
            ConnectionHandler.insertEdgeBefore(connection, edge);
          }
        },
      });
    },
    [createBaseImageCollection, navigate],
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
      <CreateBaseImageCollectionForm
        optionsRef={baseImageCollectionOptions}
        onSubmit={handleCreateBaseImageCollection}
        isLoading={isCreatingBaseImageCollection}
      />
    </>
  );
};

const NoSystemModels = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.BaseImageCollectionCreate.noSystemModels.title"
        defaultMessage="You haven't created any System Model yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.BaseImageCollectionCreate.noSystemModels.message"
        defaultMessage="You need at least one System Model to create a Base Image Collection"
      />
    </p>
    <Button as={Link} route={Route.systemModelsNew}>
      <FormattedMessage
        id="pages.BaseImageCollectionCreate.noSystemModels.createButton"
        defaultMessage="Create System Model"
      />
    </Button>
  </Result.EmptyList>
);

type BaseImageCollectionWrapperProps = {
  getBaseImageCollectionOptionsQuery: PreloadedQuery<BaseImageCollectionCreate_getOptions_Query>;
};

const BaseImageCollectionWrapper = ({
  getBaseImageCollectionOptionsQuery,
}: BaseImageCollectionWrapperProps) => {
  const baseImageCollectionOptions = usePreloadedQuery(
    CREATE_BASE_IMAGE_COLLECTION_PAGE_QUERY,
    getBaseImageCollectionOptionsQuery,
  );
  const { systemModels } = baseImageCollectionOptions;
  if (systemModels?.count === 0) {
    return <NoSystemModels />;
  }
  return (
    <BaseImageCollection
      baseImageCollectionOptions={baseImageCollectionOptions}
    />
  );
};

const BaseImageCollectionCreatePage = () => {
  const [getBaseImageCollectionOptionsQuery, getBaseImageCollectionOptions] =
    useQueryLoader<BaseImageCollectionCreate_getOptions_Query>(
      CREATE_BASE_IMAGE_COLLECTION_PAGE_QUERY,
    );

  const fetchBaseImageCollectionOptions = useCallback(
    () => getBaseImageCollectionOptions({}, { fetchPolicy: "network-only" }),
    [getBaseImageCollectionOptions],
  );

  useEffect(fetchBaseImageCollectionOptions, [fetchBaseImageCollectionOptions]);

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
        onReset={fetchBaseImageCollectionOptions}
      >
        {getBaseImageCollectionOptionsQuery && (
          <Page>
            <Page.Header
              title={
                <FormattedMessage
                  id="pages.BaseImageCollectionCreate.title"
                  defaultMessage="Create Base Image Collection"
                />
              }
            />
            <Page.Main>
              <BaseImageCollectionWrapper
                getBaseImageCollectionOptionsQuery={
                  getBaseImageCollectionOptionsQuery
                }
              />
            </Page.Main>
          </Page>
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImageCollectionCreatePage;
