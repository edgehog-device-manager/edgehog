/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import React from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { baseImageCollectionHandleSchema, yup } from "forms";
import { graphql, useFragment } from "react-relay";
import type { CreateBaseImageCollection_SystemModelsFragment$key } from "api/__generated__/CreateBaseImageCollection_SystemModelsFragment.graphql";

const CREATE_BASE_IMAGE_COLLECTION_FRAGMENT = graphql`
  fragment CreateBaseImageCollection_SystemModelsFragment on SystemModel
  @relay(plural: true) {
    id
    name
  }
`;

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

type BaseImageCollectionData = {
  name: string;
  handle: string;
  systemModelId: string;
};

const baseImageCollectionSchema = yup
  .object({
    name: yup.string().required(),
    handle: baseImageCollectionHandleSchema.required(),
    systemModelId: yup.string().required(),
  })
  .required();

const initialData: BaseImageCollectionData = {
  name: "",
  handle: "",
  systemModelId: "",
};

type Props = {
  systemModelsRef: CreateBaseImageCollection_SystemModelsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: BaseImageCollectionData) => void;
};

const CreateBaseImageCollectionForm = ({
  systemModelsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();
  const systemModelsData = useFragment(
    CREATE_BASE_IMAGE_COLLECTION_FRAGMENT,
    systemModelsRef,
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
            {systemModelsData.map((systemModelOption) => (
              <option key={systemModelOption.id} value={systemModelOption.id}>
                {systemModelOption.name}
              </option>
            ))}
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
