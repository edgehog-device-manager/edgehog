/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import { Link, Route } from "Navigation";
import type { ImageCredentials_imageCredentials_Query } from "api/__generated__/ImageCredentials_imageCredentials_Query.graphql";
import Button from "components/Button";
import Center from "components/Center";
import ImageCredentialsTable from "components/ImageCredentialsTable";
import Page from "components/Page";
import Spinner from "components/Spinner";
import { FunctionComponent, Suspense, useCallback, useEffect } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay";

const { LoadingError, Header, Main } = Page;
const { imageCredentialsNew } = Route;

const IMAGE_CREDENTIALS_QUERY = graphql`
  query ImageCredentials_imageCredentials_Query {
    listImageCredentials {
      # eslint-disable-next-line relay/unused-fields
      results {
        ...ImageCredentialsTable_imageCredentials_Fragment
      }
    }
  }
`;

interface ContentProps {
  initialQueryRef: PreloadedQuery<ImageCredentials_imageCredentials_Query>;
}

const ImageCredentialsContent: FunctionComponent<ContentProps> = ({
  initialQueryRef,
}) => {
  const { listImageCredentials } =
    usePreloadedQuery<ImageCredentials_imageCredentials_Query>(
      IMAGE_CREDENTIALS_QUERY,
      initialQueryRef,
    );

  return (
    <Page>
      <Header
        title={
          <FormattedMessage
            id="pages.ImageCredentials.title"
            defaultMessage="Image Credentials"
          />
        }
      >
        <Button as={Link} route={imageCredentialsNew}>
          <FormattedMessage
            id="pages.ImageCredentials.createButton"
            description="Create a new Application Credentials"
          />
        </Button>
      </Header>
      <Main>
        <ImageCredentialsTable
          listImageCredentialsRef={listImageCredentials!.results!}
        />
      </Main>
    </Page>
  );
};

interface PageProps {}

const ImageCredentialsPage: FunctionComponent<PageProps> = () => {
  const [listImageCredentialsQuery, getImageCredentials] =
    useQueryLoader<ImageCredentials_imageCredentials_Query>(
      IMAGE_CREDENTIALS_QUERY,
    );

  const fetchImageCredentials = useCallback(
    () => getImageCredentials({}, { fetchPolicy: "store-and-network" }),
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
            <LoadingError onRetry={resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchImageCredentials}
      >
        {listImageCredentialsQuery && (
          <ImageCredentialsContent
            initialQueryRef={listImageCredentialsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ImageCredentialsPage;
