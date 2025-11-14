/*
  This file is part of Edgehog.

  Copyright 2021 - 2025 SECO Mind Srl

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

import { useCallback, useMemo, useState } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import type { UpdateHardwareType_HardwareTypeFragment$key } from "api/__generated__/UpdateHardwareType_HardwareTypeFragment.graphql";

import Button from "components/Button";
import Form from "components/Form";
import Icon from "components/Icon";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { handleSchema, messages, yup } from "forms";

const UPDATE_HARDWARE_TYPE_FRAGMENT = graphql`
  fragment UpdateHardwareType_HardwareTypeFragment on HardwareType {
    name
    handle
    partNumbers {
      count
      edges {
        node {
          partNumber
        }
      }
    }
  }
`;

type HardwareTypeData = {
  name: string;
  handle: string;
  partNumbers: string[];
};

type PartNumber = { value: string };

type FormData = {
  name: string;
  handle: string;
  partNumbers: PartNumber[];
};

const hardwareTypeSchema = yup
  .object({
    name: yup.string().required(),
    handle: handleSchema.required(),
    partNumbers: yup
      .array()
      .required()
      .min(1)
      .of(
        yup
          .object({ value: yup.string().required() })
          .required()
          .test("unique", messages.unique.id, (partNumber, context) => {
            const itemIndex = context.parent.indexOf(partNumber);
            return !context.parent.find(
              (pn: PartNumber, index: number) =>
                pn.value === partNumber.value && index < itemIndex,
            );
          }),
      ),
  })
  .required();

const transformOutputData = (data: FormData): HardwareTypeData => ({
  ...data,
  partNumbers: data.partNumbers.map((pn) => pn.value),
});

type Props = {
  hardwareTypeRef: UpdateHardwareType_HardwareTypeFragment$key;
  isLoading?: boolean;
  onSubmit: (data: HardwareTypeData) => void;
  onDelete: () => void;
};

const UpdateHardwareTypeForm = ({
  hardwareTypeRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const hardwareType = useFragment(
    UPDATE_HARDWARE_TYPE_FRAGMENT,
    hardwareTypeRef,
  );

  const defaultValues = useMemo<FormData>(
    () => ({
      name: hardwareType.name,
      handle: hardwareType.handle,
      partNumbers:
        hardwareType.partNumbers?.count && hardwareType.partNumbers.count > 0
          ? (hardwareType.partNumbers.edges?.map(
              ({ node: { partNumber } }) => ({
                value: partNumber,
              }),
            ) ?? [])
          : [{ value: "" }], // default with at least one empty part number
    }),
    [hardwareType.name, hardwareType.handle, hardwareType.partNumbers],
  );

  const {
    control,
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues,
    resolver: yupResolver(hardwareTypeSchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const partNumbers = useFieldArray({
    control,
    name: "partNumbers",
  });

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

  const canReset = isDirty && !isLoading;
  const canSubmit = !isLoading && isDirty;
  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="hardware-type-form-name"
          label={
            <FormattedMessage
              id="forms.UpdateHardwareType.nameLabel"
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
          id="hardware-type-form-handle"
          label={
            <FormattedMessage
              id="forms.UpdateHardwareType.handleLabel"
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
          id="hardware-type-form-part-numbers"
          label={
            <FormattedMessage
              id="forms.UpdateHardwareType.partNumbersLabel"
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
                  <Form.Control.Feedback type="invalid">
                    {errors.partNumbers?.[index]?.value?.message && (
                      <FormattedMessage
                        id={errors.partNumbers?.[index]?.value?.message}
                      />
                    )}
                  </Form.Control.Feedback>
                </Stack>
                <Button
                  className="mb-auto"
                  variant="danger"
                  disabled={isLoading}
                  onClick={() => handleDeletePartNumber(index)}
                >
                  <Icon icon="delete" />
                </Button>
              </Stack>
            ))}
            <Button
              className="me-auto"
              variant="secondary"
              disabled={isLoading}
              onClick={handleAddPartNumber}
            >
              <FormattedMessage
                id="forms.UpdateHardwareType.addPartNumberButton"
                defaultMessage="Add Part Number"
              />
            </Button>
          </Stack>
        </FormRow>
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateHardwareType.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateHardwareType.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateHardwareType.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export type { HardwareTypeData };

export default UpdateHardwareTypeForm;
