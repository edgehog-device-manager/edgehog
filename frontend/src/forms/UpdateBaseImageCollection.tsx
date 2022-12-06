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

import React from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { baseImageCollectionHandleSchema, yup } from "forms";

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
  systemModel: {
    name: string;
  } | null;
};

type FormData = {
  name: string;
  handle: string;
  systemModel: string;
};

type BaseImageCollectionChanges = {
  name: string;
  handle: string;
};

const baseImageCollectionSchema = yup
  .object({
    name: yup.string().required(),
    handle: baseImageCollectionHandleSchema.required(),
    systemModel: yup.string().required(),
  })
  .required();

const transformInputData = (data: BaseImageCollectionData): FormData => ({
  ...data,
  systemModel: data.systemModel?.name || "",
});

const transformOutputData = ({
  name,
  handle,
}: FormData): BaseImageCollectionChanges => ({
  name,
  handle,
});

type Props = {
  initialData: BaseImageCollectionData;
  isLoading?: boolean;
  onSubmit: (data: BaseImageCollectionChanges) => void;
  onDelete: () => void;
};

const UpdateBaseImageCollection = ({
  initialData,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData && transformInputData(initialData),
    resolver: yupResolver(baseImageCollectionSchema),
  });

  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

  const canSubmit = !isLoading && isDirty;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="base-image-collection-form-name"
          label={
            <FormattedMessage
              id="components.UpdateBaseImageCollection.nameLabel"
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
          id="base-image-collection-form-handle"
          label={
            <FormattedMessage
              id="components.UpdateBaseImageCollection.handleLabel"
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
          id="base-image-collection-form-system-model"
          label={
            <FormattedMessage
              id="components.UpdateBaseImageCollection.systemModelLabel"
              defaultMessage="System Model"
            />
          }
        >
          <Form.Control {...register("systemModel")} plaintext readOnly />
        </FormRow>

        <div className="d-flex justify-content-end align-items-center gap-2">
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.UpdateBaseImageCollection.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="components.UpdateBaseImageCollection.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { BaseImageCollectionData, BaseImageCollectionChanges };

export default UpdateBaseImageCollection;
