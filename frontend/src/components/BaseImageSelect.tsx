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

import { forwardRef, Suspense, useCallback, useEffect, useMemo } from "react";
import type { ReactElement, ComponentProps } from "react";
import { ErrorBoundary } from "react-error-boundary";
import type { FallbackProps } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useQueryLoader, usePreloadedQuery } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type {
  BaseImageSelect_getBaseImages_Query,
  BaseImageSelect_getBaseImages_Query$data,
} from "api/__generated__/BaseImageSelect_getBaseImages_Query.graphql";

import Button from "components/Button";
import Form from "components/Form";
import Spinner from "components/Spinner";
import Stack from "components/Stack";

type SelectProps = ComponentProps<typeof Form.Select>;
type BaseImage = NonNullable<
  NonNullable<
    BaseImageSelect_getBaseImages_Query$data["baseImageCollection"]
  >["baseImages"]["edges"]
>[number]["node"];

const GET_BASE_IMAGES_QUERY = graphql`
  query BaseImageSelect_getBaseImages_Query($baseImageCollectionId: ID!) {
    baseImageCollection(id: $baseImageCollectionId) {
      baseImages {
        edges {
          node {
            id
            name
          }
        }
      }
    }
  }
`;

type BaseImageSelectProps = {
  baseImages?: readonly BaseImage[];
} & SelectProps;

const BaseImageSelect = forwardRef<HTMLSelectElement, BaseImageSelectProps>(
  ({ baseImages = [], ...selectProps }, ref) => {
    const intl = useIntl();

    return (
      <Form.Select {...selectProps} ref={ref}>
        <option value="" disabled>
          {intl.formatMessage({
            id: "components.BaseImageSelect.selectBaseImageOptionPlaceholder",
            defaultMessage: "Select a Base Image",
          })}
        </option>
        {baseImages.map((baseImage) => (
          <option key={baseImage.id} value={baseImage.id}>
            {baseImage.name}
          </option>
        ))}
      </Form.Select>
    );
  },
);
BaseImageSelect.displayName = "BaseImageSelect";

type BaseImageSelectContentProps = {
  baseImagesQuery: PreloadedQuery<BaseImageSelect_getBaseImages_Query>;
  notFoundComponent: ReactElement;
} & SelectProps;

const BaseImageSelectContent = forwardRef<
  HTMLSelectElement,
  BaseImageSelectContentProps
>(({ baseImagesQuery, notFoundComponent, ...selectProps }, ref) => {
  const { baseImageCollection } = usePreloadedQuery(
    GET_BASE_IMAGES_QUERY,
    baseImagesQuery,
  );

  if (baseImageCollection === null) {
    return notFoundComponent;
  }

  const baseImages =
    baseImageCollection.baseImages.edges?.map((edge) => edge.node) ?? [];

  return <BaseImageSelect {...selectProps} baseImages={baseImages} ref={ref} />;
});
BaseImageSelectContent.displayName = "BaseImageSelectContent";

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

type BaseImageSelectWrapperProps = {
  baseImageCollectionId?: string;
} & SelectProps;

const BaseImageSelectWrapper = forwardRef<
  HTMLSelectElement,
  BaseImageSelectWrapperProps
>((props, ref) => {
  const { baseImageCollectionId, ...selectProps } = props;

  const [getBaseImagesQuery, getBaseImages] =
    useQueryLoader<BaseImageSelect_getBaseImages_Query>(GET_BASE_IMAGES_QUERY);

  const fetchBaseImages = useCallback(() => {
    baseImageCollectionId &&
      getBaseImages({ baseImageCollectionId }, { fetchPolicy: "network-only" });
  }, [getBaseImages, baseImageCollectionId]);

  useEffect(fetchBaseImages, [fetchBaseImages]);

  const notFound = useMemo(
    () => (
      <ErrorFallback
        resetErrorBoundary={fetchBaseImages}
        error={new Error("Base Image Collection not found")}
      />
    ),
    [fetchBaseImages],
  );

  if (!baseImageCollectionId) {
    return <BaseImageSelect {...selectProps} ref={ref} disabled />;
  }

  return (
    <ErrorBoundary
      resetKeys={[baseImageCollectionId]}
      onReset={fetchBaseImages}
      FallbackComponent={ErrorFallback}
    >
      <Suspense fallback={<Spinner />}>
        {getBaseImagesQuery && (
          <BaseImageSelectContent
            {...selectProps}
            baseImagesQuery={getBaseImagesQuery}
            notFoundComponent={notFound}
            ref={ref}
          />
        )}
      </Suspense>
    </ErrorBoundary>
  );
});
BaseImageSelectWrapper.displayName = "BaseImageSelectWrapper";

export default BaseImageSelectWrapper;
