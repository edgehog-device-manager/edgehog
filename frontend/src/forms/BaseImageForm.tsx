/*
 * This file is part of Edgehog.
 *
 * Copyright 2022, 2025 SECO Mind Srl
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

import React, { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import Form from "@/components/Form";
import Button from "@/components/Button";
import BaseImageSelect from "@/components/BaseImageSelect";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";

// import { yup } from "@/forms";
import * as z from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Controller, useForm } from "react-hook-form";
import Select from "react-select";
import { graphql, usePaginationFragment } from "react-relay";
import {
  BaseImageForm_baseImageCollections_Fragment$data,
  BaseImageForm_baseImageCollections_Fragment$key,
} from "@/api/__generated__/BaseImageForm_baseImageCollections_Fragment.graphql";
import { BaseImageForm_BaseImageCollectionsPagination_Query } from "@/api/__generated__/BaseImageForm_BaseImageCollectionsPagination_Query.graphql";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import _ from "lodash";
import Col from "@/components/Col";
import { baseImageFileSchema } from "@/forms/validation";

const BASE_IMAGE_COLLECTIONS_FRAGMENT = graphql`
  fragment BaseImageForm_baseImageCollections_Fragment on RootQueryType
  @refetchable(queryName: "BaseImageForm_BaseImageCollectionsPagination_Query")
  @argumentDefinitions(filter: { type: "BaseImageCollectionFilterInput" }) {
    baseImageCollections(first: $first, after: $after, filter: $filter)
      @connection(key: "BaseImageForm_baseImageCollections") {
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
    BaseImageForm_baseImageCollections_Fragment$data["baseImageCollections"]
  >["edges"]
>[number]["node"];

type FromCollectionFormProps = {
  className?: string;
  baseImageCollectionsData?: BaseImageForm_baseImageCollections_Fragment$key;
  isLoading: boolean;
  onManualOTAImageSubmit: (...input: (string | File)[]) => void;
};

type FromFileFormProps = {
  className?: string;
  isLoading: boolean;
  onManualOTAImageSubmit: (...input: (string | File)[]) => void;
};

type BaseImageFormProps = {
  className?: string;
  baseImageCollectionsData?: BaseImageForm_baseImageCollections_Fragment$key;
  isLoading: boolean;
  onManualOTAImageSubmit: (...input: (string | File)[]) => void;
};

const fromCollectionSchema = z.object({
  baseImageCollection: z.object({
    id: z.string().min(1),
    name: z.string().min(1),
  }),
  baseImage: z.object({
    id: z.string().min(1),
    name: z.string(),
    version: z.string(),
    url: z.string().min(1),
  }),
});

const fromFileSchema = z.object({ baseImageFile: baseImageFileSchema });

const debugResolver =
  (schema: any) => async (data: any, context: any, options: any) => {
    console.log("formData", data);
    console.log(
      "validation result",
      await zodResolver(schema)(data, context, options),
    );
    return zodResolver(schema)(data, context, options);
  };

const getBaseImageCollLabel = (
  baseImageCollection: BaseImageCollectionRecord,
) => baseImageCollection.name;
const getBaseImageCollValue = (
  baseImageCollection: BaseImageCollectionRecord,
) => baseImageCollection.id;

const FromCollectionForm = ({
  baseImageCollectionsData,
  className,
  isLoading,
  onManualOTAImageSubmit,
}: FromCollectionFormProps) => {
  const intl = useIntl();

  const {
    control,
    formState,
    handleSubmit,
    register,
    resetField,
    watch,
    getValues,
  } = useForm({
    mode: "onTouched",
    // resolver: debugResolver(fromCollectionSchema)
    resolver: zodResolver(fromCollectionSchema),
  });
  const { errors } = formState;
  // console.log(formState.dirtyFields, formState.touchedFields, errors, formState.isValid);
  // console.log("coll errors:", errors)

  const selectedBaseImageCollection = watch("baseImageCollection");

  const {
    data: baseImageCollPaginationData,
    loadNext: loadNextBaseImageColls,
    hasNext: hasNextBaseImageColl,
    isLoadingNext: isLoadingNextBaseImageColl,
    refetch: refetchBaseImageColls,
  } = usePaginationFragment<
    BaseImageForm_BaseImageCollectionsPagination_Query,
    BaseImageForm_baseImageCollections_Fragment$key
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
        baseImageCollPaginationData as BaseImageForm_baseImageCollections_Fragment$data
      ).baseImageCollections?.edges?.map((edge) => edge?.node) ?? []
    );
  }, [baseImageCollPaginationData]);

  const noBaseImageCollOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.BaseImageForm.noBaseImageCollsFoundMatching",
            defaultMessage:
              'No base image collections found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.BaseImageForm.noBaseImageCollsAvailable",
          defaultMessage: "No base image collections available",
        });

  const { onChange: onBaseImageCollectionChange } = register(
    "baseImageCollection",
  );
  const { onChange: onBaseImageChange } = register("baseImage");
  const onSubmit = useCallback(
    handleSubmit(
      (data) => {
        console.log("coll submit:", data);
        onManualOTAImageSubmit(data.baseImage.url);
      } /*, onError*/,
    ),
    [handleSubmit],
  );

  return (
    <form className={className + " w-75"} onSubmit={onSubmit}>
      <Stack direction="vertical" gap={2} className="align-items-start">
        <Form.Group as={Col} controlId="baseImageCollection" className="w-100">
          <Form.Label column sm={3} className="text-nowrap">
            <FormattedMessage
              id="components.BaseImageForm.baseImageFromCollectionLabel"
              defaultMessage="Select from a collection"
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
                  id: "forms.BaseImageForm.baseImageCollectionOption",
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
              id="forms.BaseImageForm.baseImageFromCollectionLabel"
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
                {errors.baseImageCollection && (
                  <FormattedMessage
                    id={errors.baseImageCollection.id?.message}
                  />
                )}
              </Form.Control.Feedback>
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.BaseImageForm.selectBaseImageCollection"
                defaultMessage="Select a base image collection before selecting an image..."
              />
            </div>
          )}
        </Form.Group>
        <Button variant="primary" type="submit" disabled={isLoading}>
          {isLoading && <Spinner size="sm" className="me-2" />}
          <FormattedMessage
            id="components.BaseImageForm.update"
            defaultMessage="Update"
          />
        </Button>
      </Stack>
    </form>
  );
};

const FromFileSchema = ({
  className,
  isLoading,
  onManualOTAImageSubmit,
}: FromFileFormProps) => {
  const {
    control,
    formState,
    handleSubmit,
    register,
    resetField,
    watch,
    getValues,
  } = useForm({
    mode: "onTouched",
    resolver: debugResolver(fromFileSchema),
  });
  const { errors } = formState;
  // console.log(formState.dirtyFields, formState.touchedFields, errors, formState.isValid);
  // console.log("file errors:", errors)

  const onSubmit = useCallback(
    handleSubmit(
      (data) => {
        console.log("file submit:", data);
        onManualOTAImageSubmit(data.baseImageFile[0]);
      } /*, onError*/,
    ),
    [handleSubmit, onManualOTAImageSubmit],
  );

  return (
    <form className={className + " w-75"} onSubmit={onSubmit}>
      <Form.Group controlId="baseImageFile">
        <Stack direction="vertical" gap={2} className="align-items-start">
          <Form.Label column sm={3} className="text-nowrap">
            <FormattedMessage
              id="components.BaseImageForm.baseImageLabel"
              defaultMessage="Base image file"
            />
          </Form.Label>
          <Form.Control {...register("baseImageFile")} type="file" />
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.BaseImageForm.update"
              defaultMessage="Update"
            />
          </Button>
        </Stack>
      </Form.Group>
    </form>
  );
};

const BaseImageForm = ({
  baseImageCollectionsData,
  className,
  isLoading,
  onManualOTAImageSubmit,
}: BaseImageFormProps) => {
  const [updateMode, setUpdateMode] = useState<"collection" | "file">(
    "collection",
  );

  const modeOnChange =
    (mode: "collection" | "file") =>
    (_event: React.ChangeEvent<HTMLInputElement>) =>
      setUpdateMode(mode);

  return (
    <Stack
      // direction="horizontal"
      // gap={3}
      // className="justify-content-between align-items-stretch"
      direction="vertical"
      className="mt-3"
    >
      <Form.Group key="updateMode">
        <Form.Check
          name="updateMode"
          inline
          type="radio"
          label="Collection"
          onChange={modeOnChange("collection")}
        />
        <Form.Check
          name="updateMode"
          inline
          type="radio"
          label="File"
          onChange={modeOnChange("file")}
        />
      </Form.Group>
      {updateMode === "collection" ? (
        <FromCollectionForm
          baseImageCollectionsData={baseImageCollectionsData}
          className={className}
          isLoading={isLoading}
          onManualOTAImageSubmit={onManualOTAImageSubmit}
        />
      ) : (
        // <div className="fw-semibold">
        //   <FormattedMessage
        //     id="components.BaseImageForm.or"
        //     defaultMessage="or"
        //   />
        // </div>
        <FromFileSchema
          className={className}
          isLoading={isLoading}
          onManualOTAImageSubmit={onManualOTAImageSubmit}
        />
      )}
    </Stack>
  );
};

export default BaseImageForm;
export type { BaseImageFormProps };
