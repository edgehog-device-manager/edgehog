/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import { useState } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { zodResolver } from "@hookform/resolvers/zod";

import Button from "@/components/ui/button/Button";
import Form from "@/components/ui/form/Form";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import { FormRow } from "@/components/ui/form-row/FormRow";
import { ApplicationFormData, applicationSchema } from "@/forms/validation";
import FormFeedback from "@/forms/FormFeedback";

const initialData: ApplicationFormData = {
  name: "",
};

type Props = {
  defaultValues?: ApplicationFormData;
  isLoading?: boolean;
  onSubmit: (data: ApplicationFormData) => void;
};

const CreateApplication = ({
  defaultValues,
  isLoading = false,
  onSubmit,
}: Props) => {
  const {
    register,
    reset,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<ApplicationFormData>({
    mode: "onTouched",
    defaultValues: defaultValues ?? initialData,
    resolver: zodResolver(applicationSchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (defaultValues && prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const canSubmit = !isLoading && (!defaultValues || isDirty);
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="application-form-name"
          label={
            <FormattedMessage
              id="forms.CreateApplication.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>

        <FormRow
          id="application-form-description"
          label={
            <FormattedMessage
              id="forms.CreateApplication.descriptionLabel"
              defaultMessage="Description"
            />
          }
        >
          <Form.Control
            as="textarea"
            rows={5}
            {...register("description")}
            isInvalid={!!errors.description}
          />
          <FormFeedback feedback={errors.description?.message} />
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          {defaultValues ? (
            <Stack
              direction="horizontal"
              gap={3}
              className="justify-content-end align-items-center"
            >
              <Button variant="primary" type="submit" disabled={!canSubmit}>
                {isLoading && <Spinner size="sm" className="me-2" />}
                <FormattedMessage
                  id="forms.CreateApplication.updateButton"
                  defaultMessage="Update"
                />
              </Button>
              <Button
                variant="secondary"
                disabled={!canReset}
                onClick={() => reset()}
              >
                <FormattedMessage
                  id="forms.CreateApplication.resetButton"
                  defaultMessage="Reset"
                />
              </Button>
            </Stack>
          ) : (
            <Button variant="primary" type="submit" disabled={!canSubmit}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="forms.CreateApplication.submitButton"
                defaultMessage="Create"
              />
            </Button>
          )}
        </div>
      </Stack>
    </form>
  );
};

export default CreateApplication;
