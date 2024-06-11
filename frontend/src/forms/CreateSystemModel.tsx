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

import React, { useCallback } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import CloseButton from "components/CloseButton";
import Col from "components/Col";
import Figure from "components/Figure";
import Form from "components/Form";
import Icon from "components/Icon";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { systemModelHandleSchema, messages, yup } from "forms";

import type { CreateSystemModel_OptionsFragment$key } from "api/__generated__/CreateSystemModel_OptionsFragment.graphql";

const CREATE_SYSTEM_MODEL_FRAGMENT = graphql`
  fragment CreateSystemModel_OptionsFragment on RootQueryType {
    hardwareTypes {
      id
      name
    }
    tenantInfo {
      defaultLocale
    }
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

type SystemModelChanges = {
  name: string;
  handle: string;
  localizedDescriptions?: {
    languageTag: string;
    value: string;
  }[];
  hardwareTypeId: string;
  partNumbers: string[];
  pictureFile?: File;
};

type PartNumber = { value: string };

type FormData = {
  name: string;
  handle: string;
  description: string;
  hardwareTypeId: string;
  partNumbers: PartNumber[];
  pictureFile?: FileList | null;
};

const systemModelSchema = yup
  .object({
    name: yup.string().required(),
    handle: systemModelHandleSchema.required(),
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
                pn.value === partNumber.value && index < itemIndex,
            );
          }),
      ),
  })
  .required();

const transformOutputData = (
  locale: string,
  data: FormData,
): SystemModelChanges => {
  const systemModel: SystemModelChanges = {
    name: data.name,
    handle: data.handle,
    hardwareTypeId: data.hardwareTypeId,
    partNumbers: data.partNumbers.map((pn) => pn.value),
  };

  if (data.pictureFile && data.pictureFile.length) {
    systemModel.pictureFile = data.pictureFile[0];
  }

  if (data.description) {
    systemModel.localizedDescriptions = [
      {
        languageTag: locale,
        value: data.description,
      },
    ];
  }

  return systemModel;
};

const initialData: FormData = {
  name: "",
  handle: "",
  description: "",
  hardwareTypeId: "",
  partNumbers: [{ value: "" }],
};

type Props = {
  optionsRef: CreateSystemModel_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: SystemModelChanges) => void;
};

const CreateSystemModelForm = ({
  optionsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();
  const {
    hardwareTypes,
    tenantInfo: { defaultLocale: locale },
  } = useFragment(CREATE_SYSTEM_MODEL_FRAGMENT, optionsRef);

  const {
    control,
    register,
    reset,
    setValue,
    handleSubmit,
    formState: { isDirty, errors },
    watch,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(systemModelSchema),
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
    [partNumbers],
  );

  const pictureFile = watch("pictureFile");
  const picture =
    pictureFile instanceof FileList && pictureFile.length > 0
      ? URL.createObjectURL(pictureFile[0]) // picture is the new file
      : null;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <Row>
          <Col md="5" lg="4" xl="3">
            <Stack>
              <div className="d-flex justify-content-end position-relative">
                {picture && (
                  <CloseButton
                    className="position-absolute bg-white border"
                    onClick={() => setValue("pictureFile", null)}
                  />
                )}
                <Figure alt={initialData.name} src={picture || undefined} />
              </div>
              <Form.Group controlId="pictureFile">
                <Form.Control
                  type="file"
                  accept=".jpg,.jpeg,.gif,.png,.svg"
                  {...register("pictureFile")}
                />
              </Form.Group>
            </Stack>
          </Col>
          <Col md="7" lg="8" xl="9">
            <Stack gap={3}>
              <FormRow
                id="system-model-form-name"
                label={
                  <FormattedMessage
                    id="components.CreateSystemModelForm.nameLabel"
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
                id="system-model-form-handle"
                label={
                  <FormattedMessage
                    id="components.CreateSystemModelForm.handleLabel"
                    defaultMessage="Handle"
                  />
                }
              >
                <Form.Control
                  {...register("handle")}
                  isInvalid={!!errors.handle}
                />
                <Form.Control.Feedback type="invalid">
                  {errors.handle?.message && (
                    <FormattedMessage id={errors.handle?.message} />
                  )}
                </Form.Control.Feedback>
              </FormRow>
              <FormRow
                id="system-model-form-description"
                label={
                  <>
                    <FormattedMessage
                      id="components.CreateSystemModelForm.descriptionLabel"
                      defaultMessage="Description"
                    />
                    <span className="small text-muted"> ({locale})</span>
                  </>
                }
              >
                <Form.Control as="textarea" {...register("description")} />
              </FormRow>
              <FormRow
                id="system-model-form-hardware-type"
                label={
                  <FormattedMessage
                    id="components.CreateSystemModelForm.hardwareTypeLabel"
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
                      id: "components.CreateSystemModelForm.hardwareTypeOption",
                      defaultMessage: "Select a Hardware Type",
                    })}
                  </option>
                  {hardwareTypes.map((hardwareType) => (
                    <option key={hardwareType.id} value={hardwareType.id}>
                      {hardwareType.name}
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
                id="system-model-form-part-numbers"
                label={
                  <FormattedMessage
                    id="components.CreateSystemModelForm.partNumbersLabel"
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
                      id="components.CreateSystemModelForm.addPartNumberButton"
                      defaultMessage="Add part number"
                    />
                  </Button>
                </Stack>
              </FormRow>
            </Stack>
          </Col>
        </Row>
        <div className="d-flex justify-content-end align-items-center">
          <Stack direction="horizontal" gap={3}>
            <Button
              disabled={!isDirty}
              variant="secondary"
              onClick={() => reset()}
            >
              <FormattedMessage
                id="components.CreateSystemModelForm.resetButton"
                defaultMessage="Reset"
              />
            </Button>
            <Button variant="primary" type="submit" disabled={isLoading}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="components.CreateSystemModelForm.submitButton"
                defaultMessage="Create"
              />
            </Button>
          </Stack>
        </div>
      </Stack>
    </form>
  );
};

export type { SystemModelChanges };

export default CreateSystemModelForm;
