/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { forwardRef, Suspense } from "react";
import type { ComponentProps } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { useIntl } from "react-intl";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import type {
  BaseImageSelect_getBaseImages_Query,
  BaseImageSelect_getBaseImages_Query$data,
} from "api/__generated__/BaseImageSelect_getBaseImages_Query.graphql";

import Form from "components/Form";

type SelectProps = ComponentProps<typeof Form.Select>;
type BaseImage = NonNullable<
  BaseImageSelect_getBaseImages_Query$data["baseImageCollection"]
>["baseImages"][number];

const GET_BASE_IMAGES_QUERY = graphql`
  query BaseImageSelect_getBaseImages_Query($baseImageCollectionId: ID!) {
    baseImageCollection(id: $baseImageCollectionId) {
      baseImages {
        id
        version
        releaseDisplayName
      }
    }
  }
`;

const getBaseImageSelectOptionLabel = ({
  version,
  releaseDisplayName,
}: BaseImage) => {
  if (releaseDisplayName === null) {
    return version;
  }
  return `${version} (${releaseDisplayName})`;
};

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
            {getBaseImageSelectOptionLabel(baseImage)}
          </option>
        ))}
      </Form.Select>
    );
  }
);
BaseImageSelect.displayName = "BaseImageSelect";

type BaseImageSelectLoaderProps = {
  baseImageCollectionId: string;
} & SelectProps;

const BaseImageSelectLoader = forwardRef<
  HTMLSelectElement,
  BaseImageSelectLoaderProps
>(({ baseImageCollectionId, ...selectProps }, ref) => {
  const { baseImageCollection } =
    useLazyLoadQuery<BaseImageSelect_getBaseImages_Query>(
      GET_BASE_IMAGES_QUERY,
      { baseImageCollectionId },
      { fetchPolicy: "network-only" }
    );

  if (baseImageCollection === null) {
    return <BaseImageSelect {...selectProps} disabled ref={ref} />;
  }

  return (
    <BaseImageSelect
      {...selectProps}
      baseImages={baseImageCollection.baseImages}
      ref={ref}
    />
  );
});
BaseImageSelectLoader.displayName = "BaseImageSelectLoader";

type BaseImageSelectWrapperProps = {
  baseImageCollectionId?: string;
} & SelectProps;

const BaseImageSelectWrapper = forwardRef<
  HTMLSelectElement,
  BaseImageSelectWrapperProps
>((props, ref) => {
  const { baseImageCollectionId, ...selectProps } = props;

  if (!baseImageCollectionId) {
    return <BaseImageSelect {...selectProps} disabled />;
  }

  return (
    <Suspense fallback={<BaseImageSelect {...selectProps} disabled />}>
      <ErrorBoundary
        FallbackComponent={() => <span>Failed to load Base Images list</span>}
      >
        <BaseImageSelectLoader
          {...selectProps}
          baseImageCollectionId={baseImageCollectionId}
          ref={ref}
        />
      </ErrorBoundary>
    </Suspense>
  );
});
BaseImageSelectWrapper.displayName = "BaseImageSelectWrapper";

export default BaseImageSelectWrapper;
