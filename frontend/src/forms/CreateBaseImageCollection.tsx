/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2025 SECO Mind Srl
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
import { useCallback, useEffect, useMemo, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import { zodResolver } from "@hookform/resolvers/zod";
import Select from "react-select";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { BaseImageCollectionRecord } from "@/pages/BaseImageCollectionCreate";

import type {
  CreateBaseImageCollection_OptionsFragment$data,
  CreateBaseImageCollection_OptionsFragment$key,
} from "@/api/__generated__/CreateBaseImageCollection_OptionsFragment.graphql";
import type { CreateBaseImageCollection_PaginationQuery } from "@/api/__generated__/CreateBaseImageCollection_PaginationQuery.graphql";
import {
  BaseImageCollectionFormData,
  baseImageCollectionSchema,
} from "@/forms/validation";

const CREATE_BASE_IMAGE_COLLECTION_FRAGMENT = graphql`
  fragment CreateBaseImageCollection_OptionsFragment on RootQueryType
  @refetchable(queryName: "CreateBaseImageCollection_PaginationQuery")
  @argumentDefinitions(filter: { type: "SystemModelFilterInput" }) {
    systemModels(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateBaseImageCollection_systemModels") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type SystemModelRecord = NonNullable<
  NonNullable<
    CreateBaseImageCollection_OptionsFragment$data["systemModels"]
  >["edges"]
>[number]["node"];

type BaseImageCollectionOutputData = {
  name: string;
  handle: string;
  systemModelId: string;
};

const initialData: BaseImageCollectionFormData = {
  name: "",
  handle: "",
  systemModel: { id: "", name: "" },
};

const transformOutputData = (
  data: BaseImageCollectionFormData,
): BaseImageCollectionOutputData => {
  const baseImageCollection: BaseImageCollectionOutputData = {
    name: data.name,
    handle: data.handle,
    systemModelId: data.systemModel.id,
  };
  return baseImageCollection;
};

type Props = {
  optionsRef: CreateBaseImageCollection_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: BaseImageCollectionOutputData) => void;
  baseImageCollections?: BaseImageCollectionRecord[];
};

const CreateBaseImageCollectionForm = ({
  optionsRef,
  isLoading = false,
  onSubmit,
  baseImageCollections = [],
}: Props) => {
  const intl = useIntl();

  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    CreateBaseImageCollection_PaginationQuery,
    CreateBaseImageCollection_OptionsFragment$key
  >(CREATE_BASE_IMAGE_COLLECTION_FRAGMENT, optionsRef);

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
              filter: { name: { ilike: `%${text}%` } },
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

  const loadNextBaseImageCollectionOptions = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const systemModels = useMemo(() => {
    return (
      paginationData.systemModels?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is SystemModelRecord => node != null) ?? []
    );
  }, [paginationData]);

  const {
    control,
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<BaseImageCollectionFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(baseImageCollectionSchema),
  });

  const isSystemModelUsedByOtherBaseImageCollection = (
    systemModel: SystemModelRecord,
  ) =>
    baseImageCollections.find(
      (baseImageCollection: BaseImageCollectionRecord) =>
        baseImageCollection.systemModel.id === systemModel.id,
    ) !== undefined;

  // Sort system models: available first, used ones last
  const systemModelOptions = useMemo(() => {
    return systemModels.sort((model1, model2) => {
      const model1Used = isSystemModelUsedByOtherBaseImageCollection(model1);
      const model2Used = isSystemModelUsedByOtherBaseImageCollection(model2);
      return Number(model1Used) - Number(model2Used);
    });
  }, [systemModels]);

  const getSystemModelLabel = useCallback(
    (systemModel: SystemModelRecord) => {
      const usedInBaseImageCollection = baseImageCollections.find(
        (baseImageCollection) =>
          baseImageCollection.systemModel.id === systemModel.id,
      );

      if (usedInBaseImageCollection) {
        return intl.formatMessage(
          {
            id: "forms.CreateBaseImageCollection.systemModelWithBaseImageCollectionLabel",
            defaultMessage:
              "{systemModelName} (used for {baseImageCollectionName})",
            description:
              "System model label of select option with base image collection name it is used for.",
          },
          {
            systemModelName: systemModel.name,
            baseImageCollectionName: usedInBaseImageCollection?.name ?? "",
          },
        );
      } else {
        return systemModel.name;
      }
    },
    [intl],
  );
  const getSystemModelValue = (systemModel: SystemModelRecord) =>
    systemModel.id;
  const noSystemModelOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.CreateBaseImageCollection.noSystemModelsFoundMatching",
            defaultMessage: 'No system models found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.CreateBaseImageCollection.noSystemModelsAvailable",
          defaultMessage: "No system models available",
        });

  const onFormSubmit = (data: BaseImageCollectionFormData) =>
    onSubmit(transformOutputData(data));

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="create-base-image-collection-form-name"
          label={
            <FormattedMessage
              id="forms.CreateBaseImageCollection.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <Form.Control.Feedback type="invalid">
            {errors.name?.message && (
              <FormattedMessage id={errors.name?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-base-image-collection-form-handle"
          label={
            <FormattedMessage
              id="forms.CreateBaseImageCollection.handleLabel"
              defaultMessage="Handle"
            />
          }
        >
          <Form.Control {...register("handle")} isInvalid={!!errors.handle} />
          <Form.Control.Feedback type="invalid">
            {errors.handle?.message && (
              <FormattedMessage id={errors.handle?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-base-image-collection-form-system-model"
          label={
            <FormattedMessage
              id="forms.CreateBaseImageCollection.systemModelLabel"
              defaultMessage="System Model"
            />
          }
        >
          <Controller
            name="systemModel"
            control={control}
            render={({
              field: { value, onChange },
              fieldState: { invalid },
            }) => (
              <Select
                value={value}
                onChange={onChange}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "forms.CreateBaseImageCollection.systemModelOption",
                  defaultMessage: "Search or select a system model...",
                })}
                options={systemModelOptions}
                getOptionLabel={getSystemModelLabel}
                getOptionValue={getSystemModelValue}
                noOptionsMessage={({ inputValue }) =>
                  noSystemModelOptionsMessage(inputValue)
                }
                isOptionDisabled={isSystemModelUsedByOtherBaseImageCollection}
                isLoading={isLoadingNext}
                onMenuScrollToBottom={
                  hasNext ? loadNextBaseImageCollectionOptions : undefined
                }
                onInputChange={(text) => setSearchText(text)}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.systemModel && (
              <FormattedMessage id={errors.systemModel?.id?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateBaseImageCollection.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { BaseImageCollectionOutputData };

export default CreateBaseImageCollectionForm;
