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
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

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

const initialData: AllowedRegistryFormData = {
  registry: "",
};

interface Props {
  isLoading?: boolean;
  onSubmit: (data: AllowedRegistryFormData) => void;
}

const CreateAllowedRegistry = ({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<AllowedRegistryFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(allowedRegistrySchema),
  });

  const handleFormSubmit = (data: AllowedRegistryFormData) => {
    onSubmit(data);
  };

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} autoComplete="off">
      <Stack gap={3}>
        <FormRow
          id="allowed-registry-form-registry"
          label={
            <FormattedMessage
              id="forms.CreateAllowedRegistry.registryLabel"
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

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateAllowedRegistry.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export default CreateAllowedRegistry;
