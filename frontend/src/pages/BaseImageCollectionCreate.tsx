/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { BaseImageCollectionCreate_getSystemModels_Query } from "api/__generated__/BaseImageCollectionCreate_getSystemModels_Query.graphql";
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

const GET_SYSTEM_MODELS_QUERY = graphql`
  query BaseImageCollectionCreate_getSystemModels_Query {
    systemModels {
      ...CreateBaseImageCollection_SystemModelsFragment
    }
  }
`;

const CREATE_BASE_IMAGE_COLLECTION_MUTATION = graphql`
  mutation BaseImageCollectionCreate_createBaseImageCollection_Mutation(
    $input: CreateBaseImageCollectionInput!
  ) {
    createBaseImageCollection(input: $input) {
      baseImageCollection {
        id
        name
        handle
        systemModel {
          name
        }
      }
    }
  }
`;

type BaseImageCollectionProps = {
  getSystemModelsQuery: PreloadedQuery<BaseImageCollectionCreate_getSystemModels_Query>;
};

const BaseImageCollection = ({
  getSystemModelsQuery,
}: BaseImageCollectionProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const { systemModels } = usePreloadedQuery(
    GET_SYSTEM_MODELS_QUERY,
    getSystemModelsQuery,
  );

  const [createBaseImageCollection, isCreatingBaseImageCollection] =
    useMutation<BaseImageCollectionCreate_createBaseImageCollection_Mutation>(
      CREATE_BASE_IMAGE_COLLECTION_MUTATION,
    );

  // TODO: handle readonly type without mapping to mutable type
  // const systemModels = useMemo(
  //   () =>
  //     systemModelsData.systemModels.map((systemModel) => ({
  //       ...systemModel,
  //     })),
  //   [systemModelsData],
  // );

  const handleCreateBaseImageCollection = useCallback(
    (baseImageCollection: BaseImageCollectionData) => {
      createBaseImageCollection({
        variables: { input: baseImageCollection },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          const baseImageCollectionId =
            data.createBaseImageCollection?.baseImageCollection.id;
          if (baseImageCollectionId) {
            navigate({
              route: Route.baseImageCollectionsEdit,
              params: { baseImageCollectionId },
            });
          } else {
            navigate({ route: Route.baseImageCollections });
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
          if (!data.createBaseImageCollection) {
            return;
          }

          const baseImageCollection = store
            .getRootField("createBaseImageCollection")
            .getLinkedRecord("baseImageCollection");
          const root = store.getRoot();

          const baseImageCollections = root.getLinkedRecords(
            "baseImageCollections",
          );
          if (baseImageCollections) {
            root.setLinkedRecords(
              [...baseImageCollections, baseImageCollection],
              "baseImageCollections",
            );
          }
        },
      });
    },
    [createBaseImageCollection, navigate],
  );

  return (
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
        {systemModels.length === 0 ? (
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
        ) : (
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
              systemModelsRef={systemModels}
              onSubmit={handleCreateBaseImageCollection}
              isLoading={isCreatingBaseImageCollection}
            />
          </>
        )}
      </Page.Main>
    </Page>
  );
};

const BaseImageCollectionCreatePage = () => {
  const [getSystemModelsQuery, getSystemModels] =
    useQueryLoader<BaseImageCollectionCreate_getSystemModels_Query>(
      GET_SYSTEM_MODELS_QUERY,
    );

  useEffect(() => getSystemModels({}), [getSystemModels]);

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
        onReset={() => getSystemModels({})}
      >
        {getSystemModelsQuery && (
          <BaseImageCollection getSystemModelsQuery={getSystemModelsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImageCollectionCreatePage;
