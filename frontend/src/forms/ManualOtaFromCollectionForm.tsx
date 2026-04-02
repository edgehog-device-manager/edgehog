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

import { zodResolver } from "@hookform/resolvers/zod";
import _ from "lodash";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay";
import Select from "react-select";

import type { ManualOtaFromCollectionForm_BaseImageCollectionsPagination_Query } from "@/api/__generated__/ManualOtaFromCollectionForm_BaseImageCollectionsPagination_Query.graphql";
import type {
  ManualOtaFromCollectionForm_baseImageCollections_Fragment$data,
  ManualOtaFromCollectionForm_baseImageCollections_Fragment$key,
} from "@/api/__generated__/ManualOtaFromCollectionForm_baseImageCollections_Fragment.graphql";

import BaseImageSelect from "@/components/BaseImageSelect";
import Button from "@/components/Button";
import Col from "@/components/Col";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import FormFeedback from "@/forms/FormFeedback";
import {
  ManualOtaFromCollectionData,
  manualOtaFromCollectionSchema,
} from "@/forms/validation";

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

const fromCollectionInitialData: ManualOtaFromCollectionData = {
  baseImageCollection: { id: "", name: "" },
  baseImage: { id: "", name: "", version: "", url: "" },
};

type ManualOtaFromCollectionFormProps = {
  className?: string;
  baseImageCollectionsData?: ManualOtaFromCollectionForm_baseImageCollections_Fragment$key;
  isLoading: boolean;
  onManagedOTAImageSubmit: (imageUrl: string) => void;
};

const ManualOtaFromCollectionForm = ({
  baseImageCollectionsData,
  className,
  isLoading,
  onManagedOTAImageSubmit,
}: ManualOtaFromCollectionFormProps) => {
  const intl = useIntl();

  const {
    control,
    formState: { errors },
    handleSubmit,
    register,
    resetField,
  } = useForm({
    mode: "onTouched",
    defaultValues: fromCollectionInitialData,
    resolver: zodResolver(manualOtaFromCollectionSchema),
  });

  const selectedBaseImageCollection = useWatch({
    control,
    name: "baseImageCollection",
  });

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
  >(null);

  const debounceBaseImageCollRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        refetchBaseImageColls(
          {
            first: RECORDS_TO_LOAD_FIRST,
            ...(text && { filter: { name: { ilike: `%${text}%` } } }),
          },
          { fetchPolicy: "network-only" },
        );
      }, 500),
    [refetchBaseImageColls],
  );

  useEffect(() => {
    return () => {
      debounceBaseImageCollRefetch.cancel();
    };
  }, [debounceBaseImageCollRefetch]);

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

  const baseImageCollections = useMemo(
    () =>
      baseImageCollPaginationData?.baseImageCollections?.edges?.map(
        (edge) => edge?.node,
      ) ?? [],
    [baseImageCollPaginationData],
  );

  const noBaseImageCollOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.ManualOtaFromCollectionForm.noBaseImageCollsFoundMatching",
            defaultMessage:
              'No base image collections found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.ManualOtaFromCollectionForm.noBaseImageCollsAvailable",
          defaultMessage: "No base image collections available",
        });

  const { onChange: onBaseImageCollectionChange } = register(
    "baseImageCollection",
  );
  const { onChange: onBaseImageChange } = register("baseImage");

  const onSubmit = handleSubmit((data) => {
    onManagedOTAImageSubmit(data.baseImage.url);
  });

  return (
    <form className={className} onSubmit={onSubmit}>
      <FormRow
        id="baseImageCollection"
        label={
          <FormattedMessage
            id="forms.ManualOtaFromCollectionForm.baseImageFromCollectionLabel"
            defaultMessage="Base Image Collection"
          />
        }
      >
        <Controller
          name="baseImageCollection"
          control={control}
          render={({ field: { value, onChange }, fieldState: { invalid } }) => (
            <Select
              value={value}
              onChange={(e) => {
                onChange(e);
                onBaseImageCollectionChange({ target: e });
                resetField("baseImage");
              }}
              className={invalid ? "is-invalid" : ""}
              placeholder={intl.formatMessage({
                id: "forms.ManualOtaFromCollectionForm.baseImageCollectionOption",
                defaultMessage: "Search or select a base image collection...",
              })}
              options={baseImageCollections}
              getOptionLabel={(opt) => opt.name}
              getOptionValue={(opt) => opt.id}
              noOptionsMessage={({ inputValue }) =>
                noBaseImageCollOptionsMessage(inputValue)
              }
              isLoading={isLoadingNextBaseImageColl}
              onMenuScrollToBottom={
                hasNextBaseImageColl ? loadNextBaseImageCollOptions : undefined
              }
              onInputChange={(text) => setSearchBaseImageCollText(text)}
            />
          )}
        />
        <FormFeedback feedback={errors.baseImageCollection?.id?.message} />
      </FormRow>

      <FormRow
        id="baseImage"
        label={
          <FormattedMessage
            id="forms.ManualOtaFromCollectionForm.baseImageLabel"
            defaultMessage="Base Image"
          />
        }
      >
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
            <FormFeedback feedback={errors.baseImage?.id?.message} />
          </>
        ) : (
          <div className="d-flex align-content-center fst-italic text-muted">
            <FormattedMessage
              id="forms.ManualOtaFromCollectionForm.selectBaseImageCollection"
              defaultMessage="Select a base image collection before selecting an image..."
            />
          </div>
        )}
      </FormRow>

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.ManualOtaFromCollectionForm.update"
              defaultMessage="Update"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export type { BaseImageCollectionRecord };

export default ManualOtaFromCollectionForm;
