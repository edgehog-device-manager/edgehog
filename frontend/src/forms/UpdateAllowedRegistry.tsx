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
import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { UpdateAllowedRegistry_allowedRegistry_Fragment$key } from "@/api/__generated__/UpdateAllowedRegistry_allowedRegistry_Fragment.graphql";
import Button from "@/components/ui/button/Button";
import Form from "@/components/ui/form/Form";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import { FormRow } from "@/components/ui/form-row/FormRow";
import {
  AllowedRegistryFormData,
  allowedRegistrySchema,
} from "@/forms/validation";
import FormFeedback from "@/forms/FormFeedback";

const ALLOWED_REGISTRY_FRAGMENT = graphql`
  fragment UpdateAllowedRegistry_allowedRegistry_Fragment on AllowedRegistry {
    id
    registry
  }
`;

interface Props {
  allowedRegistryRef: UpdateAllowedRegistry_allowedRegistry_Fragment$key;
  isLoading?: boolean;
  onSubmit: (data: AllowedRegistryFormData, onSuccess?: () => void) => void;
  onDelete(): void;
}

const UpdateAllowedRegistryForm = ({
  allowedRegistryRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const { registry } = useFragment(
    ALLOWED_REGISTRY_FRAGMENT,
    allowedRegistryRef,
  );

  const defaultValues = useMemo<AllowedRegistryFormData>(
    () => ({
      registry,
    }),
    [registry],
  );

  const {
    register,
    reset,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<AllowedRegistryFormData>({
    mode: "onTouched",
    defaultValues,
    resolver: zodResolver(allowedRegistrySchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const handleFormSubmit = (data: AllowedRegistryFormData) => {
    onSubmit(data, () => {
      reset(data);
    });
  };

  const canSubmit = !isLoading && isDirty;
  const canReset = !isLoading && isDirty;

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} autoComplete="off">
      <Stack gap={3}>
        <FormRow
          id="allowed-registry-form-registry"
          label={
            <FormattedMessage
              id="forms.UpdateAllowedRegistry.registryLabel"
              defaultMessage="Registry Host"
            />
          }
        >
          <Form.Control
            {...register("registry")}
            placeholder="e.g. docker.io"
            isInvalid={!!errors.registry}
          />
          <FormFeedback feedback={errors.registry?.message} />
        </FormRow>

        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateAllowedRegistry.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateAllowedRegistry.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateAllowedRegistry.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export default UpdateAllowedRegistryForm;
