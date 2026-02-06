/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import _ from "lodash";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay";

import type { ImageCredentials_getImageCredentials_Query } from "@/api/__generated__/ImageCredentials_getImageCredentials_Query.graphql";
import { ImageCredentials_ImageCredentialsFragment$key } from "@/api/__generated__/ImageCredentials_ImageCredentialsFragment.graphql";
import { ImageCredentials_PaginationQuery } from "@/api/__generated__/ImageCredentials_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import ImageCredentialsTable from "@/components/ImageCredentialsTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_IMAGE_CREDENTIALS_QUERY = graphql`
  query ImageCredentials_getImageCredentials_Query(
    $first: Int
    $after: String
    $filter: ImageCredentialsFilterInput = {}
  ) {
    ...ImageCredentials_ImageCredentialsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const IMAGE_CREDENTIALS_FRAGMENT = graphql`
  fragment ImageCredentials_ImageCredentialsFragment on RootQueryType
  @refetchable(queryName: "ImageCredentials_PaginationQuery") {
    listImageCredentials(first: $first, after: $after, filter: $filter)
      @connection(key: "ImageCredentials_listImageCredentials") {
      edges {
        node {
          __typename
        }
      }
      ...ImageCredentialsTable_ImageCredentialEdgeFragment
    }
  }
`;

interface ImageCredentialsLayoutContainerProps {
  imageCredentialsData: ImageCredentials_getImageCredentials_Query["response"];
  searchText: string | null;
}
const ImageCredentialsLayoutContainer = ({
  imageCredentialsData,
  searchText,
}: ImageCredentialsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      ImageCredentials_PaginationQuery,
      ImageCredentials_ImageCredentialsFragment$key
    >(IMAGE_CREDENTIALS_FRAGMENT, imageCredentialsData);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: {
                or: [
                  { label: { ilike: `%${text}%` } },
                  { username: { ilike: `%${text}%` } },
                ],
              },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextImageCredentials = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const imageCredentialsRef = data?.listImageCredentials;

  if (!imageCredentialsRef) {
    return null;
  }

  return (
    <ImageCredentialsTable
      imageCredentialsRef={imageCredentialsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextImageCredentials : undefined}
    />
  );
};

interface ImageCredentialsContentProps {
  getImageCredentialsQuery: PreloadedQuery<ImageCredentials_getImageCredentials_Query>;
}

const ImageCredentialsContent = ({
  getImageCredentialsQuery,
}: ImageCredentialsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const imageCredentialsData =
    usePreloadedQuery<ImageCredentials_getImageCredentials_Query>(
      GET_IMAGE_CREDENTIALS_QUERY,
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
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <ImageCredentialsLayoutContainer
          imageCredentialsData={imageCredentialsData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const ImageCredentialsPage = () => {
  const [getImageCredentialsQuery, getImageCredentials] =
    useQueryLoader<ImageCredentials_getImageCredentials_Query>(
      GET_IMAGE_CREDENTIALS_QUERY,
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
