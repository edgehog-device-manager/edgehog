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

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Form from "components/Form";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { handleSchema, yup } from "forms";

import type { UpdateBaseImageCollection_SystemModelFragment$key } from "api/__generated__/UpdateBaseImageCollection_SystemModelFragment.graphql";

const UPDATE_BASE_IMAGE_COLLECTION_FRAGMENT = graphql`
  fragment UpdateBaseImageCollection_SystemModelFragment on BaseImageCollection {
    name
    handle
    systemModel {
      name
    }
  }
`;

type BaseImageCollectionData = {
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
    handle: handleSchema.required(),
    systemModel: yup.string().required(),
  })
  .required();

const transformOutputData = ({
  name,
  handle,
}: BaseImageCollectionData): BaseImageCollectionChanges => ({
  name,
  handle,
});

type Props = {
  baseImageCollectionRef: UpdateBaseImageCollection_SystemModelFragment$key;
  isLoading?: boolean;
  onSubmit: (data: BaseImageCollectionChanges) => void;
  onDelete: () => void;
};

const UpdateBaseImageCollection = ({
  baseImageCollectionRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const baseImageCollection = useFragment(
    UPDATE_BASE_IMAGE_COLLECTION_FRAGMENT,
    baseImageCollectionRef,
  );

  const { name, handle } = baseImageCollection;
  const systemModel = baseImageCollection.systemModel?.name || "";

  const defaultValues = useMemo(
    () => ({ name, handle, systemModel }),
    [name, handle, systemModel],
  );

  const {
    register,
    reset,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<BaseImageCollectionData>({
    mode: "onTouched",
    defaultValues,
    resolver: yupResolver(baseImageCollectionSchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const onFormSubmit = (data: BaseImageCollectionData) =>
    onSubmit(transformOutputData(data));

  const canSubmit = !isLoading && isDirty;
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="base-image-collection-form-name"
          label={
            <FormattedMessage
              id="forms.UpdateBaseImageCollection.nameLabel"
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
              id="forms.UpdateBaseImageCollection.handleLabel"
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
              id="forms.UpdateBaseImageCollection.systemModelLabel"
              defaultMessage="System Model"
            />
          }
        >
          <Form.Control {...register("systemModel")} plaintext readOnly />
        </FormRow>
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateBaseImageCollection.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateBaseImageCollection.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateBaseImageCollection.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export type { BaseImageCollectionChanges };

export default UpdateBaseImageCollection;
