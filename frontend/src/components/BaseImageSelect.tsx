/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2026 SECO Mind Srl
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
import type { FallbackProps } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import Select from "react-select";

import {
  BaseImageSelect_BaseImagesFragment$data,
  BaseImageSelect_BaseImagesFragment$key,
} from "@/api/__generated__/BaseImageSelect_BaseImagesFragment.graphql";
import { BaseImageSelect_BaseImagesPaginationQuery } from "@/api/__generated__/BaseImageSelect_BaseImagesPaginationQuery.graphql";
import { BaseImageSelect_getBaseImageCollection_Query } from "@/api/__generated__/BaseImageSelect_getBaseImageCollection_Query.graphql";

import Button from "@/components/Button";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { BaseImageCollectionRecord } from "@/forms/CreateUpdateCampaign";

const GET_BASE_IMAGE_COLLECTION_QUERY = graphql`
  query BaseImageSelect_getBaseImageCollection_Query(
    $baseImageCollectionId: ID!
    $first: Int
    $after: String
    $filter: BaseImageFilterInput = {}
  ) {
    baseImageCollection(id: $baseImageCollectionId) {
      ...BaseImageSelect_BaseImagesFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

const BASE_IMAGE_SELECT_OPTIONS_FRAGMENT = graphql`
  fragment BaseImageSelect_BaseImagesFragment on BaseImageCollection
  @refetchable(queryName: "BaseImageSelect_BaseImagesPaginationQuery")
  @argumentDefinitions(
    first: { type: Int }
    after: { type: String }
    filter: { type: "BaseImageFilterInput" }
  ) {
    baseImages(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateUpdateCampaign_baseImages") {
      edges {
        node {
          id
          name
          version
          url
        }
      }
    }
  }
`;

type BaseImageNode = NonNullable<
  NonNullable<BaseImageSelect_BaseImagesFragment$data["baseImages"]>["edges"]
>[number]["node"];
type OmitUrl = Omit<BaseImageNode, "url">;
export type BaseImageRecord = OmitUrl & { readonly url?: string };

type BaseImageSelectProps = {
  updateCampaignBaseImageOptionsRef: BaseImageSelect_BaseImagesFragment$key | null;
  controllerProps: ControllerProps;
};

const BaseImageSelect = ({
  updateCampaignBaseImageOptionsRef,
  controllerProps,
}: BaseImageSelectProps) => {
  const intl = useIntl();

  const {
    data: paginationData,
    loadNext: loadNext,
    hasNext: hasNext,
    isLoadingNext: isLoadingNext,
    refetch: refetch,
  } = usePaginationFragment<
    BaseImageSelect_BaseImagesPaginationQuery,
    BaseImageSelect_BaseImagesFragment$key
  >(BASE_IMAGE_SELECT_OPTIONS_FRAGMENT, updateCampaignBaseImageOptionsRef);

  const [searchText, setSearchText] = useState<string | null>(null);

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
              filter: { version: { ilike: `%${text}%` } },
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

  const loadNextOptions = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const baseImages = useMemo(() => {
    return (
      paginationData?.baseImages?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is BaseImageNode => node != null) ?? []
    );
  }, [paginationData]);

  const getBaseImageLabel = (baseImage: BaseImageRecord) =>
    baseImage.name || baseImage.version;
  const getBaseImageValue = (baseImage: BaseImageRecord) => baseImage.id;
  const noBaseImageOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "components.BaseImageSelect.noBaseImagesFoundMatching",
            defaultMessage: 'No base images found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "components.BaseImageSelect.noBaseImagesAvailable",
          defaultMessage: "No base images available",
        });

  return (
    <Select
      value={controllerProps.value}
      onChange={controllerProps.onChange}
      className={controllerProps.invalid ? "is-invalid" : ""}
      placeholder={intl.formatMessage({
        id: "components.BaseImageSelect.baseImageOption",
        defaultMessage: "Search or select a base image...",
      })}
      options={baseImages}
      getOptionLabel={getBaseImageLabel}
      getOptionValue={getBaseImageValue}
      noOptionsMessage={({ inputValue }) =>
        noBaseImageOptionsMessage(inputValue)
      }
      isLoading={isLoadingNext}
      onMenuScrollToBottom={hasNext ? loadNextOptions : undefined}
      onInputChange={(text) => setSearchText(text)}
    />
  );
};

type BaseImageSelectContentProps = {
  baseImageCollectionQuery: PreloadedQuery<BaseImageSelect_getBaseImageCollection_Query>;
  controllerProps: ControllerProps;
};

const BaseImageSelectContent = ({
  baseImageCollectionQuery,
  controllerProps,
}: BaseImageSelectContentProps) => {
  const { baseImageCollection } = usePreloadedQuery(
    GET_BASE_IMAGE_COLLECTION_QUERY,
    baseImageCollectionQuery,
  );

  return (
    <BaseImageSelect
      updateCampaignBaseImageOptionsRef={baseImageCollection}
      controllerProps={controllerProps}
    />
  );
};

const ErrorFallback = ({ resetErrorBoundary }: FallbackProps) => (
  <Stack direction="horizontal">
    <span>
      <FormattedMessage
        id="components.BaseImageSelect.ErrorFallback.message"
        defaultMessage="Failed to load Base Images list."
      />
    </span>
    <Button variant="link" onClick={resetErrorBoundary}>
      <FormattedMessage
        id="components.BaseImageSelect.ErrorFallback.reloadButton"
        defaultMessage="Reload"
      />
    </Button>
  </Stack>
);

type ControllerProps = {
  value: BaseImageRecord;
  invalid: boolean;
  onChange: (...event: any[]) => void;
};

type BaseImageSelectWrapperProps = {
  selectedBaseImageCollection: BaseImageCollectionRecord;
  controllerProps: ControllerProps;
};

const BaseImageSelectWrapper = ({
  selectedBaseImageCollection,
  controllerProps,
}: BaseImageSelectWrapperProps) => {
  const [getBaseImageCollectionQuery, getBaseImageCollection] =
    useQueryLoader<BaseImageSelect_getBaseImageCollection_Query>(
      GET_BASE_IMAGE_COLLECTION_QUERY,
    );

  const fetchBaseImageCollection = useCallback(() => {
    getBaseImageCollection(
      {
        baseImageCollectionId: selectedBaseImageCollection.id,
        first: RECORDS_TO_LOAD_FIRST,
      },
      { fetchPolicy: "network-only" },
    );
  }, [getBaseImageCollection, selectedBaseImageCollection]);

  useEffect(fetchBaseImageCollection, [fetchBaseImageCollection]);

  return (
    <ErrorBoundary
      onReset={fetchBaseImageCollection}
      FallbackComponent={ErrorFallback}
    >
      <Suspense fallback={<Spinner />}>
        {getBaseImageCollectionQuery && (
          <BaseImageSelectContent
            baseImageCollectionQuery={getBaseImageCollectionQuery}
            controllerProps={controllerProps}
          />
        )}
      </Suspense>
    </ErrorBoundary>
  );
};

export default BaseImageSelectWrapper;
