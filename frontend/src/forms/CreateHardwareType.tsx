// This file is part of Edgehog.
//
// Copyright 2021 - 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { useCallback } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { zodResolver } from "@hookform/resolvers/zod";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Icon from "@/components/Icon";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";
import { HardwareTypeFormData, hardwareTypeSchema } from "@/forms/validation";
import FormFeedback from "@/forms/FormFeedback";

type HardwareTypeOutputData = {
  name: string;
  handle: string;
  partNumbers: string[];
};

const transformOutputData = (
  data: HardwareTypeFormData,
): HardwareTypeOutputData => ({
  ...data,
  partNumbers: data.partNumbers.map((pn) => pn.value),
});

const initialData: HardwareTypeFormData = {
  name: "",
  handle: "",
  partNumbers: [{ value: "" }],
};

type Props = {
  isLoading?: boolean;
  onSubmit: (data: HardwareTypeOutputData) => void;
};

const CreateHardwareTypeForm = ({ isLoading = false, onSubmit }: Props) => {
  const {
    control,
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<HardwareTypeFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(hardwareTypeSchema),
  });

  const partNumbers = useFieldArray({
    control,
    name: "partNumbers",
  });

  const onFormSubmit = (data: HardwareTypeFormData) =>
    onSubmit(transformOutputData(data));

  const handleAddPartNumber = useCallback(() => {
    partNumbers.append({ value: "" });
  }, [partNumbers]);

  const handleDeletePartNumber = useCallback(
    (index: number) => {
      if (partNumbers.fields.length > 1) {
        partNumbers.remove(index);
      } else {
        partNumbers.update(index, { value: "" });
      }
    },
    [partNumbers],
  );

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="hardware-type-form-name"
          label={
            <FormattedMessage
              id="forms.CreateHardwareType.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>
        <FormRow
          id="hardware-type-form-handle"
          label={
            <FormattedMessage
              id="forms.CreateHardwareType.handleLabel"
              defaultMessage="Handle"
            />
          }
        >
          <Form.Control {...register("handle")} isInvalid={!!errors.handle} />
          <FormFeedback feedback={errors.handle?.message} />
        </FormRow>
        <FormRow
          id="hardware-type-form-part-numbers"
          label={
            <FormattedMessage
              id="forms.CreateHardwareType.partNumbersLabel"
              defaultMessage="Part Numbers"
            />
          }
        >
          <Stack gap={3}>
            {partNumbers.fields.map((partNumber, index) => (
              <Stack direction="horizontal" gap={3} key={partNumber.id}>
                <Stack>
                  <Form.Control
                    {...register(`partNumbers.${index}.value`)}
                    isInvalid={!!errors.partNumbers?.[index]}
                  />
                  <FormFeedback
                    feedback={errors.partNumbers?.[index]?.value?.message}
                  />
                </Stack>
                <Button
                  className="mb-auto"
                  variant="danger"
                  onClick={() => handleDeletePartNumber(index)}
                >
                  <Icon icon="delete" />
                </Button>
              </Stack>
            ))}
            <Button
              className="me-auto"
              variant="secondary"
              onClick={handleAddPartNumber}
            >
              <FormattedMessage
                id="forms.CreateHardwareType.addPartNumberButton"
                defaultMessage="Add Part Number"
              />
            </Button>
          </Stack>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateHardwareType.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { HardwareTypeOutputData };

export default CreateHardwareTypeForm;
