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
import { useParams } from "react-router-dom";
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
  BaseImageCreate_getBaseImageCollection_Query,
  BaseImageCreate_getBaseImageCollection_Query$data,
} from "api/__generated__/BaseImageCreate_getBaseImageCollection_Query.graphql";
import type { BaseImageCreate_createBaseImage_Mutation } from "api/__generated__/BaseImageCreate_createBaseImage_Mutation.graphql";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import CreateBaseImageForm from "forms/CreateBaseImage";
import type { BaseImageData } from "forms/CreateBaseImage";
import { Link, Route, useNavigate } from "Navigation";

const GET_BASE_IMAGE_COLLECTION_QUERY = graphql`
  query BaseImageCreate_getBaseImageCollection_Query($id: ID!) {
    baseImageCollection(id: $id) {
      ...CreateBaseImage_BaseImageCollectionFragment
    }
    tenantInfo {
      defaultLocale
    }
  }
`;

const CREATE_BASE_IMAGE_MUTATION = graphql`
  mutation BaseImageCreate_createBaseImage_Mutation(
    $input: CreateBaseImageInput!
  ) {
    createBaseImage(input: $input) {
      baseImage {
        __typename
      }
    }
  }
`;

type BaseImageCreateContentProps = {
  baseImageCollection: NonNullable<
    BaseImageCreate_getBaseImageCollection_Query$data["baseImageCollection"]
  >;
  locale: BaseImageCreate_getBaseImageCollection_Query$data["tenantInfo"]["defaultLocale"];
};

const BaseImageCreateContent = ({
  baseImageCollection,
  locale,
}: BaseImageCreateContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const [createBaseImage, isCreatingBaseImage] =
    useMutation<BaseImageCreate_createBaseImage_Mutation>(
      CREATE_BASE_IMAGE_MUTATION,
    );

  const handleCreateBaseImage = useCallback(
    (baseImage: BaseImageData) => {
      createBaseImage({
        variables: { input: baseImage },
        onCompleted(data, errors) {
          if (data.createBaseImage) {
            return navigate({
              route: Route.baseImageCollectionsEdit,
              params: {
                baseImageCollectionId: baseImage.baseImageCollectionId,
              },
            });
          }

          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.BaseImageCreate.creationErrorFeedback"
              defaultMessage="Could not create the Base Image, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data.createBaseImage) {
            return;
          }
          store
            .getRoot()
            .getLinkedRecord("baseImageCollection", {
              id: baseImage.baseImageCollectionId,
            })
            ?.invalidateRecord();
        },
      });
    },
    [createBaseImage, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.BaseImageCreate.title"
            defaultMessage="Create Base Image"
          />
        }
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
        <CreateBaseImageForm
          baseImageCollectionRef={baseImageCollection}
          locale={locale}
          onSubmit={handleCreateBaseImage}
          isLoading={isCreatingBaseImage}
        />
      </Page.Main>
    </Page>
  );
};

type BaseImageCreateWrapperProps = {
  getBaseImageCollectionQuery: PreloadedQuery<BaseImageCreate_getBaseImageCollection_Query>;
};

const BaseImageCreateWrapper = ({
  getBaseImageCollectionQuery,
}: BaseImageCreateWrapperProps) => {
  const { baseImageCollection, tenantInfo } = usePreloadedQuery(
    GET_BASE_IMAGE_COLLECTION_QUERY,
    getBaseImageCollectionQuery,
  );

  if (!baseImageCollection) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.BaseImageCreate.baseImageCollectionNotFound.title"
            defaultMessage="Base Image Collection not found."
          />
        }
      >
        <Link route={Route.baseImageCollections}>
          <FormattedMessage
            id="pages.BaseImageCreate.baseImageCollectionNotFound.message"
            defaultMessage="Return to the Base Image Collection list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <BaseImageCreateContent
      baseImageCollection={baseImageCollection}
      locale={tenantInfo.defaultLocale}
    />
  );
};

const BaseImageCreatePage = () => {
  const { baseImageCollectionId = "" } = useParams();

  const [getBaseImageCollectionQuery, getBaseImageCollection] =
    useQueryLoader<BaseImageCreate_getBaseImageCollection_Query>(
      GET_BASE_IMAGE_COLLECTION_QUERY,
    );

  const fetchBaseImageCollection = useCallback(() => {
    getBaseImageCollection(
      { id: baseImageCollectionId },
      { fetchPolicy: "network-only" },
    );
  }, [getBaseImageCollection, baseImageCollectionId]);

  useEffect(fetchBaseImageCollection, [fetchBaseImageCollection]);

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
        onReset={fetchBaseImageCollection}
      >
        {getBaseImageCollectionQuery && (
          <BaseImageCreateWrapper
            getBaseImageCollectionQuery={getBaseImageCollectionQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImageCreatePage;
