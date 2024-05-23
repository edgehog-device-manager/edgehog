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

import { Suspense, useEffect, useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { BaseImageCollections_getBaseImageCollections_Query } from "api/__generated__/BaseImageCollections_getBaseImageCollections_Query.graphql";
import Button from "components/Button";
import Center from "components/Center";
import BaseImageCollectionsTable from "components/BaseImageCollectionsTable";
import Page from "components/Page";
import Spinner from "components/Spinner";
import { Link, Route } from "Navigation";

const GET_BASE_IMAGE_COLLECTIONS_QUERY = graphql`
  query BaseImageCollections_getBaseImageCollections_Query {
    baseImageCollections {
      ...BaseImageCollectionsTable_BaseImageCollectionFragment
    }
  }
`;

interface BaseImageCollectionsContentProps {
  getBaseImageCollectionsQuery: PreloadedQuery<BaseImageCollections_getBaseImageCollections_Query>;
}

const BaseImageCollectionsContent = ({
  getBaseImageCollectionsQuery,
}: BaseImageCollectionsContentProps) => {
  const { baseImageCollections } = usePreloadedQuery(
    GET_BASE_IMAGE_COLLECTIONS_QUERY,
    getBaseImageCollectionsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.BaseImageCollections.title"
            defaultMessage="Base Image Collections"
          />
        }
      >
        <Button as={Link} route={Route.baseImageCollectionsNew}>
          <FormattedMessage
            id="pages.BaseImageCollections.createButton"
            defaultMessage="Create Base Image Collection"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <BaseImageCollectionsTable
          baseImageCollectionsRef={baseImageCollections}
        />
      </Page.Main>
    </Page>
  );
};

const BaseImageCollectionsPage = () => {
  const [getBaseImageCollectionsQuery, getBaseImageCollections] =
    useQueryLoader<BaseImageCollections_getBaseImageCollections_Query>(
      GET_BASE_IMAGE_COLLECTIONS_QUERY,
    );

  const fetchBaseImageCollections = useCallback(
    () => getBaseImageCollections({}, { fetchPolicy: "store-and-network" }),
    [getBaseImageCollections],
  );

  useEffect(fetchBaseImageCollections, [fetchBaseImageCollections]);

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
        onReset={fetchBaseImageCollections}
      >
        {getBaseImageCollectionsQuery && (
          <BaseImageCollectionsContent
            getBaseImageCollectionsQuery={getBaseImageCollectionsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImageCollectionsPage;
