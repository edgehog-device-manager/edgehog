/*
 * This file is part of Edgehog.
 *
 * Copyright 2024, 2025 SECO Mind Srl
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

import { Suspense, useCallback, useEffect } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay";

import type { ImageCredentials_imageCredentials_Query } from "@/api/__generated__/ImageCredentials_imageCredentials_Query.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import ImageCredentialsTable from "@/components/ImageCredentialsTable";
import Page from "@/components/Page";
import Spinner from "@/components/Spinner";
import { Link, Route } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const IMAGE_CREDENTIALS_QUERY = graphql`
  query ImageCredentials_imageCredentials_Query(
    $first: Int
    $after: String
    $filter: ImageCredentialsFilterInput = {}
  ) {
    ...ImageCredentialsTable_imageCredentials_Fragment
      @arguments(filter: $filter)
  }
`;

interface ImageCredentialsContentProps {
  getImageCredentialsQuery: PreloadedQuery<ImageCredentials_imageCredentials_Query>;
}

const ImageCredentialsContent = ({
  getImageCredentialsQuery,
}: ImageCredentialsContentProps) => {
  const listImageCredentialsRef =
    usePreloadedQuery<ImageCredentials_imageCredentials_Query>(
      IMAGE_CREDENTIALS_QUERY,
      getImageCredentialsQuery,
    );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ImageCredentials.title"
            defaultMessage="Image Credentials"
          />
        }
      >
        <Button as={Link} route={Route.imageCredentialsNew}>
          <FormattedMessage
            id="pages.ImageCredentials.createButton"
            defaultMessage="Create Image Credentials"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <ImageCredentialsTable
          listImageCredentialsRef={listImageCredentialsRef}
        />
      </Page.Main>
    </Page>
  );
};

const ImageCredentialsPage = () => {
  const [getImageCredentialsQuery, getImageCredentials] =
    useQueryLoader<ImageCredentials_imageCredentials_Query>(
      IMAGE_CREDENTIALS_QUERY,
    );

  const fetchImageCredentials = useCallback(
    () =>
      getImageCredentials(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getImageCredentials],
  );

  useEffect(fetchImageCredentials, [fetchImageCredentials]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={({ resetErrorBoundary }) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchImageCredentials}
      >
        {getImageCredentialsQuery && (
          <ImageCredentialsContent
            getImageCredentialsQuery={getImageCredentialsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ImageCredentialsPage;
