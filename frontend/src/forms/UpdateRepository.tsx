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
import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { UpdateRepository_RepositoryFragment$key } from "@/api/__generated__/UpdateRepository_RepositoryFragment.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import {
  RepositoryUpdateFormData,
  repositoryUpdateSchema,
} from "@/forms/validation";
import FormFeedback from "./FormFeedback";

const UPDATE_REPOSITORY_FRAGMENT = graphql`
  fragment UpdateRepository_RepositoryFragment on Repository {
    id
    name
    handle
    description
  }
`;

type RepositoryOutputData = {
  name: string;
  handle: string;
  description: string | null;
};

const transformOutputData = ({
  id: _id,
  ...rest
}: RepositoryUpdateFormData): RepositoryOutputData => ({
  ...rest,
});

type Props = {
  repositoryRef: UpdateRepository_RepositoryFragment$key;
  isLoading?: boolean;
  onSubmit: (data: RepositoryOutputData) => void;
  onDelete: () => void;
};

const UpdateRepository = ({
  repositoryRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const repository = useFragment(UPDATE_REPOSITORY_FRAGMENT, repositoryRef);

  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
  } = useForm<RepositoryUpdateFormData>({
    mode: "onTouched",
    defaultValues: {
      ...repository,
    },
    resolver: zodResolver(repositoryUpdateSchema),
  });

  useEffect(() => {
    reset({
      ...repository,
    });
  }, [reset, repository]);

  const onFormSubmit = (data: RepositoryUpdateFormData) => {
    onSubmit(transformOutputData(data));
  };

  const canSubmit = !isLoading && isDirty;
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="update-repository-form-name"
          label={
            <FormattedMessage
              id="forms.UpdateRepository.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>

        <FormRow
          id="update-repository-form-handle"
          label={
            <FormattedMessage
              id="forms.UpdateRepository.handleLabel"
              defaultMessage="Handle"
            />
          }
        >
          <Form.Control {...register("handle")} isInvalid={!!errors.handle} />
          <FormFeedback feedback={errors.handle?.message} />
        </FormRow>

        <FormRow
          id="update-repository-form-description"
          label={
            <FormattedMessage
              id="forms.UpdateRepository.descriptionLabel"
              defaultMessage="Description"
            />
          }
        >
          <Form.Control
            as="textarea"
            {...register("description")}
            isInvalid={!!errors.description}
          />
          <FormFeedback feedback={errors.description?.message} />
        </FormRow>

        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateRepository.submitButton"
              defaultMessage="Update"
            />
          </Button>

          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateRepository.resetButton"
              defaultMessage="Reset"
            />
          </Button>

          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateRepository.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export type { RepositoryOutputData };

export default UpdateRepository;
