/*
  This file is part of Edgehog.

  Copyright 2023 - 2025 SECO Mind Srl

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

import React, { useMemo } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Form from "components/Form";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { handleSchema, yup } from "forms";

import type { CreateBaseImageCollection_OptionsFragment$key } from "api/__generated__/CreateBaseImageCollection_OptionsFragment.graphql";

const CREATE_BASE_IMAGE_COLLECTION_FRAGMENT = graphql`
  fragment CreateBaseImageCollection_OptionsFragment on RootQueryType {
    systemModels {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type BaseImageCollectionData = {
  name: string;
  handle: string;
  systemModelId: string;
};

const baseImageCollectionSchema = yup
  .object({
    name: yup.string().required(),
    handle: handleSchema.required(),
    systemModelId: yup.string().required(),
  })
  .required();

const initialData: BaseImageCollectionData = {
  name: "",
  handle: "",
  systemModelId: "",
};

type Props = {
  optionsRef: CreateBaseImageCollection_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: BaseImageCollectionData) => void;
  usedSystemModelIds?: string[];
};

const CreateBaseImageCollectionForm = ({
  optionsRef,
  isLoading = false,
  onSubmit,
  usedSystemModelIds = [],
}: Props) => {
  const intl = useIntl();
  const { systemModels } = useFragment(
    CREATE_BASE_IMAGE_COLLECTION_FRAGMENT,
    optionsRef,
  );
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<BaseImageCollectionData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(baseImageCollectionSchema),
  });

  // Sort system models: available first, used ones last
  const systemModelOptions = useMemo(() => {
    const nodes = systemModels?.edges?.map((edge) => edge.node) ?? [];
    return nodes.sort((model1, model2) => {
      const model1Used = usedSystemModelIds.includes(model1.id);
      const model2Used = usedSystemModelIds.includes(model2.id);
      return Number(model1Used) - Number(model2Used);
    });
  }, [systemModels, usedSystemModelIds]);

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="create-base-image-collection-form-name"
          label={
            <FormattedMessage
              id="components.CreateBaseImageCollectionForm.nameLabel"
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
              id="components.CreateBaseImageCollectionForm.handleLabel"
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
              id="components.CreateBaseImageCollectionForm.systemModelLabel"
              defaultMessage="System Model"
            />
          }
        >
          <Form.Select
            {...register("systemModelId")}
            isInvalid={!!errors.systemModelId}
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "components.CreateBaseImageCollectionForm.systemModelOption",
                defaultMessage: "Select a System Model",
              })}
            </option>

            {systemModelOptions.map((systemModel) => {
              const isUsed = usedSystemModelIds.includes(systemModel.id);
              return (
                <option
                  key={systemModel.id}
                  value={systemModel.id}
                  disabled={isUsed}
                >
                  {isUsed
                    ? intl.formatMessage(
                        {
                          id: "components.CreateBaseImageCollectionForm.systemModelOptionUsed",
                          defaultMessage: "{name} (already used)",
                        },
                        { name: systemModel.name },
                      )
                    : systemModel.name}
                </option>
              );
            })}
          </Form.Select>
          <Form.Control.Feedback type="invalid">
            {errors.systemModelId?.message && (
              <FormattedMessage id={errors.systemModelId?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateBaseImageCollectionForm.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { BaseImageCollectionData };

export default CreateBaseImageCollectionForm;
