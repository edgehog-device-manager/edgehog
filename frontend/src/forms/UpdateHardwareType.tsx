/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

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

import React, { useCallback, useEffect } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Icon from "components/Icon";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { hardwareTypeHandleSchema, messages, yup } from "forms";

import type {
  UpdateHardwareType_HardwareTypeFragment$key,
  UpdateHardwareType_HardwareTypeFragment$data,
} from "api/__generated__/UpdateHardwareType_HardwareTypeFragment.graphql";

const UPDATE_HARDWARE_TYPE_FRAGMENT = graphql`
  fragment UpdateHardwareType_HardwareTypeFragment on HardwareType {
    name
    handle
    partNumbers
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
    handle: hardwareTypeHandleSchema.required(),
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

const transformInputData = (
  data: UpdateHardwareType_HardwareTypeFragment$data,
): FormData => ({
  ...data,
  partNumbers:
    data.partNumbers.length > 0
      ? data.partNumbers.map((pn) => ({ value: pn }))
      : [{ value: "" }], // default with at least one empty part number
});

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
  const {
    control,
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: transformInputData(hardwareType),
    resolver: yupResolver(hardwareTypeSchema),
  });

  const partNumbers = useFieldArray({
    control,
    name: "partNumbers",
  });

  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

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

  useEffect(
    () => reset(transformInputData(hardwareType)),
    [hardwareType, reset],
  );

  const canSubmit = !isLoading && isDirty;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="hardware-type-form-name"
          label={
            <FormattedMessage
              id="components.UpdateHardwareTypeForm.nameLabel"
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
              id="components.UpdateHardwareTypeForm.handleLabel"
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
              id="components.UpdateHardwareTypeForm.partNumbersLabel"
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
                id="components.UpdateHardwareTypeForm.addPartNumberButton"
                defaultMessage="Add Part Number"
              />
            </Button>
          </Stack>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center gap-2">
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.UpdateHardwareTypeForm.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="components.UpdateHardwareTypeForm.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { HardwareTypeData };

export default UpdateHardwareTypeForm;
