/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { Controller, useForm } from "react-hook-form";
import { graphql, usePaginationFragment } from "react-relay";
import _ from "lodash";
import Select from "react-select";
import { zodResolver } from "@hookform/resolvers/zod";

import type { ManualOtaFromCollectionForm_BaseImageCollectionsPagination_Query } from "@/api/__generated__/ManualOtaFromCollectionForm_BaseImageCollectionsPagination_Query.graphql";
import type {
  ManualOtaFromCollectionForm_baseImageCollections_Fragment$data,
  ManualOtaFromCollectionForm_baseImageCollections_Fragment$key,
} from "@/api/__generated__/ManualOtaFromCollectionForm_baseImageCollections_Fragment.graphql";

import BaseImageSelect from "@/components/BaseImageSelect";
import Col from "@/components/Col";
import Form from "@/components/Form";
import Button from "@/components/Button";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { manualOtaFromCollectionSchema } from "@/forms/validation";
import { ManualOtaFromCollectionData } from "@/forms/validation";

const BASE_IMAGE_COLLECTIONS_FRAGMENT = graphql`
  fragment ManualOtaFromCollectionForm_baseImageCollections_Fragment on RootQueryType
  @refetchable(
    queryName: "ManualOtaFromCollectionForm_BaseImageCollectionsPagination_Query"
  )
  @argumentDefinitions(filter: { type: "BaseImageCollectionFilterInput" }) {
    baseImageCollections(first: $first, after: $after, filter: $filter)
      @connection(key: "ManualOtaFromCollectionForm_baseImageCollections") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type BaseImageCollectionRecord = NonNullable<
  NonNullable<
    ManualOtaFromCollectionForm_baseImageCollections_Fragment$data["baseImageCollections"]
  >["edges"]
>[number]["node"];

type FromCollectionFormProps = {
  className?: string;
  baseImageCollectionsData?: ManualOtaFromCollectionForm_baseImageCollections_Fragment$key;
  isLoading: boolean;
  onManualOTAImageSubmit: ManualOtaOperation;
};

type ManualOtaOperation = (input: {
  imageFile?: File;
  imageUrl?: string;
}) => void;

const getBaseImageCollLabel = (
  baseImageCollection: BaseImageCollectionRecord,
) => baseImageCollection.name;
const getBaseImageCollValue = (
  baseImageCollection: BaseImageCollectionRecord,
) => baseImageCollection.id;

const fromCollectionInitialData: ManualOtaFromCollectionData = {
  baseImageCollection: { id: "", name: "" },
  baseImage: { id: "", name: "", version: "", url: "" },
};

const ManualOtaFromCollectionForm = ({
  baseImageCollectionsData,
  className,
  isLoading,
  onManualOTAImageSubmit,
}: FromCollectionFormProps) => {
  const intl = useIntl();

  const {
    control,
    formState: { errors },
    handleSubmit,
    register,
    resetField,
    watch,
  } = useForm({
    mode: "onTouched",
    defaultValues: fromCollectionInitialData,
    resolver: zodResolver(manualOtaFromCollectionSchema),
  });

  const selectedBaseImageCollection = watch("baseImageCollection");

  const {
    data: baseImageCollPaginationData,
    loadNext: loadNextBaseImageColls,
    hasNext: hasNextBaseImageColl,
    isLoadingNext: isLoadingNextBaseImageColl,
    refetch: refetchBaseImageColls,
  } = usePaginationFragment<
    ManualOtaFromCollectionForm_BaseImageCollectionsPagination_Query,
    ManualOtaFromCollectionForm_baseImageCollections_Fragment$key
  >(BASE_IMAGE_COLLECTIONS_FRAGMENT, baseImageCollectionsData);

  const [searchBaseImageCollText, setSearchBaseImageCollText] = useState<
    string | null
  >("");

  const debounceBaseImageCollRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetchBaseImageColls(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetchBaseImageColls(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetchBaseImageColls],
  );

  useEffect(() => {
    if (searchBaseImageCollText !== null) {
      debounceBaseImageCollRefetch(searchBaseImageCollText);
    }
  }, [debounceBaseImageCollRefetch, searchBaseImageCollText]);

  const loadNextBaseImageCollOptions = useCallback(() => {
    if (hasNextBaseImageColl && !isLoadingNextBaseImageColl) {
      loadNextBaseImageColls(RECORDS_TO_LOAD_NEXT);
    }
  }, [
    hasNextBaseImageColl,
    isLoadingNextBaseImageColl,
    loadNextBaseImageColls,
  ]);

  const baseImageCollections = useMemo(() => {
    return (
      (
        baseImageCollPaginationData as ManualOtaFromCollectionForm_baseImageCollections_Fragment$data
      ).baseImageCollections?.edges?.map((edge) => edge?.node) ?? []
    );
  }, [baseImageCollPaginationData]);

  const noBaseImageCollOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.ManualOtaFromFileCollection.noBaseImageCollsFoundMatching",
            defaultMessage:
              'No base image collections found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.ManualOtaFromFileCollection.noBaseImageCollsAvailable",
          defaultMessage: "No base image collections available",
        });

  const { onChange: onBaseImageCollectionChange } = register(
    "baseImageCollection",
  );
  const { onChange: onBaseImageChange } = register("baseImage");

  const onSubmit = handleSubmit((data) => {
    onManualOTAImageSubmit({ imageUrl: data.baseImage.url });
  });

  return (
    <form className={className} onSubmit={onSubmit}>
      <Stack direction="vertical" gap={2} className="align-items-start">
        <Form.Group as={Col} controlId="baseImageCollection" className="w-100">
          <Form.Label column sm={3} className="text-nowrap">
            <FormattedMessage
              id="components.ManualOtaFromFileCollection.baseImageFromCollectionLabel"
              defaultMessage="Base Image Collection"
            />
          </Form.Label>
          <Controller
            name="baseImageCollection"
            control={control}
            render={({
              field: { value, onChange },
              fieldState: { invalid },
            }) => (
              <Select
                value={value}
                onChange={(e) => {
                  onChange(e);
                  onBaseImageCollectionChange({ target: e });
                  resetField("baseImage");
                }}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "forms.ManualOtaFromFileCollection.baseImageCollectionOption",
                  defaultMessage: "Search or select a base image collection...",
                })}
                options={baseImageCollections}
                getOptionLabel={getBaseImageCollLabel}
                getOptionValue={getBaseImageCollValue}
                noOptionsMessage={({ inputValue }) =>
                  noBaseImageCollOptionsMessage(inputValue)
                }
                isLoading={isLoadingNextBaseImageColl}
                onMenuScrollToBottom={
                  hasNextBaseImageColl
                    ? loadNextBaseImageCollOptions
                    : undefined
                }
                onInputChange={(text) => setSearchBaseImageCollText(text)}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.baseImageCollection && (
              <FormattedMessage id={errors.baseImageCollection.id?.message} />
            )}
          </Form.Control.Feedback>
        </Form.Group>
        <Form.Group as={Col} controlId="baseImage" className="w-100">
          <Form.Label column sm={3} className="text-nowrap">
            <FormattedMessage
              id="forms.ManualOtaFromFileCollection.baseImageFromCollectionLabel"
              defaultMessage="Base Image"
            />
          </Form.Label>
          {selectedBaseImageCollection?.id ? (
            <>
              <Controller
                name="baseImage"
                control={control}
                render={({
                  field: { value, onChange },
                  fieldState: { invalid },
                }) => (
                  <BaseImageSelect
                    selectedBaseImageCollection={selectedBaseImageCollection}
                    controllerProps={{
                      value: value,
                      invalid: invalid,
                      onChange: (e) => {
                        onChange(e);
                        onBaseImageChange(e);
                      },
                    }}
                  />
                )}
              />
              <Form.Control.Feedback type="invalid">
                {errors.baseImage && (
                  <FormattedMessage id={errors.baseImage.id?.message} />
                )}
              </Form.Control.Feedback>
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.ManualOtaFromFileCollection.selectBaseImageCollection"
                defaultMessage="Select a base image collection before selecting an image..."
              />
            </div>
          )}
        </Form.Group>
        <Button variant="primary" type="submit" disabled={isLoading}>
          {isLoading && <Spinner size="sm" className="me-2" />}
          <FormattedMessage
            id="components.ManualOtaFromFileCollection.update"
            defaultMessage="Update"
          />
        </Button>
      </Stack>
    </form>
  );
};

export default ManualOtaFromCollectionForm;
