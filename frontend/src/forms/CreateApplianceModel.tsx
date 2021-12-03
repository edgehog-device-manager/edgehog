/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import React, { useCallback } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Icon from "components/Icon";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { applianceModelHandleSchema, messages, yup } from "forms";

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

type ApplianceModelData = {
  name: string;
  handle: string;
  description?: {
    locale: string;
    text: string;
  };
  hardwareTypeId: string;
  partNumbers: string[];
};

type PartNumber = { value: string };

type FormData = {
  name: string;
  handle: string;
  description: string;
  hardwareTypeId: string;
  partNumbers: PartNumber[];
};

const applianceModelSchema = yup
  .object({
    name: yup.string().required(),
    handle: applianceModelHandleSchema.required(),
    description: yup.string(),
    hardwareTypeId: yup.string().required(),
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
                pn.value === partNumber.value && index < itemIndex
            );
          })
      ),
  })
  .required();

const transformOutputData = (
  locale: string,
  data: FormData
): ApplianceModelData => {
  let applianceModel: ApplianceModelData = {
    name: data.name,
    handle: data.handle,
    hardwareTypeId: data.hardwareTypeId,
    partNumbers: data.partNumbers.map((pn) => pn.value),
  };

  if (data.description) {
    applianceModel.description = {
      locale,
      text: data.description,
    };
  }

  return applianceModel;
};

const initialData: FormData = {
  name: "",
  handle: "",
  description: "",
  hardwareTypeId: "",
  partNumbers: [{ value: "" }],
};

type HardwareTypeOption = {
  id: string;
  name: string;
};

type Props = {
  hardwareTypes: HardwareTypeOption[];
  locale: string;
  isLoading?: boolean;
  onSubmit: (data: ApplianceModelData) => void;
};

const CreateApplianceModelForm = ({
  hardwareTypes,
  locale,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();
  const {
    control,
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(applianceModelSchema),
  });

  const partNumbers = useFieldArray({
    control,
    name: "partNumbers",
  });

  const onFormSubmit = (data: FormData) =>
    onSubmit(transformOutputData(locale, data));

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
    [partNumbers]
  );

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="appliance-model-form-name"
          label={
            <FormattedMessage
              id="components.CreateApplianceModelForm.nameLabel"
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
          id="appliance-model-form-handle"
          label={
            <FormattedMessage
              id="components.CreateApplianceModelForm.handleLabel"
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
          id="appliance-model-form-description"
          label={
            <>
              <FormattedMessage
                id="components.CreateApplianceModelForm.descriptionLabel"
                defaultMessage="Description"
              />
              <span className="small text-muted"> ({locale})</span>
            </>
          }
        >
          <Form.Control as="textarea" {...register("description")} />
        </FormRow>
        <FormRow
          id="appliance-model-form-hardware-type"
          label={
            <FormattedMessage
              id="components.CreateApplianceModelForm.hardwareTypeLabel"
              defaultMessage="Hardware Type"
            />
          }
        >
          <Form.Select
            {...register("hardwareTypeId")}
            isInvalid={!!errors.hardwareTypeId}
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "components.CreateApplianceModelForm.hardwareTypeOption",
                defaultMessage: "Select a Hardware Type",
              })}
            </option>
            {hardwareTypes.map((hardwareTypeOption) => (
              <option key={hardwareTypeOption.id} value={hardwareTypeOption.id}>
                {hardwareTypeOption.name}
              </option>
            ))}
          </Form.Select>
          <Form.Control.Feedback type="invalid">
            {errors.hardwareTypeId?.message && (
              <FormattedMessage id={errors.hardwareTypeId?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="appliance-model-form-part-numbers"
          label={
            <FormattedMessage
              id="components.CreateApplianceModelForm.partNumbersLabel"
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
                id="components.CreateApplianceModelForm.addPartNumberButton"
                defaultMessage="Add part number"
              />
            </Button>
          </Stack>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateApplianceModelForm.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { ApplianceModelData };

export default CreateApplianceModelForm;
