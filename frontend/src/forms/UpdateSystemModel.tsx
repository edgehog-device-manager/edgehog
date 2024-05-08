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
import CloseButton from "components/CloseButton";
import Col from "components/Col";
import Figure from "components/Figure";
import Form from "components/Form";
import Icon from "components/Icon";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { systemModelHandleSchema, messages, yup } from "forms";

import type {
  UpdateSystemModel_SystemModelFragment$key,
  UpdateSystemModel_SystemModelFragment$data,
} from "api/__generated__/UpdateSystemModel_SystemModelFragment.graphql";
import type { UpdateSystemModel_OptionsFragment$key } from "api/__generated__/UpdateSystemModel_OptionsFragment.graphql";

const UPDATE_SYSTEM_MODEL_FRAGMENT = graphql`
  fragment UpdateSystemModel_SystemModelFragment on SystemModel {
    name
    handle
    description
    hardwareType {
      name
    }
    partNumbers
    pictureUrl
  }
`;

const UPDATE_SYSTEM_MODEL_OPTIONS_FRAGMENT = graphql`
  fragment UpdateSystemModel_OptionsFragment on RootQueryType {
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

type SystemModelChanges = Partial<{
  name: string;
  handle: string;
  description: {
    locale: string;
    text: string;
  };
  partNumbers: string[];
  pictureFile: File;
  pictureUrl: string | null;
}>;

type PartNumber = { value: string };

type FormData = {
  name: string;
  handle: string;
  description: string;
  hardwareType: string;
  partNumbers: PartNumber[];
  pictureFile?: FileList | null;
};

const systemModelSchema = yup
  .object({
    name: yup.string().required(),
    handle: systemModelHandleSchema.required(),
    description: yup.string(),
    hardwareType: yup.string().required(),
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
  data: UpdateSystemModel_SystemModelFragment$data,
): FormData => ({
  ...data,
  description: data.description || "",
  hardwareType: data.hardwareType.name,
  partNumbers:
    data.partNumbers.length > 0
      ? data.partNumbers.map((pn) => ({ value: pn }))
      : [{ value: "" }], // default with at least one empty part number
});

const transformOutputData = (
  systemModel: UpdateSystemModel_SystemModelFragment$data,
  locale: string,
  data: FormData,
): SystemModelChanges => {
  const diff: SystemModelChanges = {};
  if (systemModel.name !== data.name) {
    diff.name = data.name;
  }
  if (systemModel.handle !== data.handle) {
    diff.handle = data.handle;
  }
  if (data.pictureFile) {
    diff.pictureFile = data.pictureFile[0];
  } else if (systemModel.pictureUrl !== null && data.pictureFile === null) {
    diff.pictureUrl = null;
  }
  if (systemModel.description !== null || data.description !== "") {
    diff.description = {
      locale,
      text: data.description,
    };
  }

  const partNumbers = data.partNumbers.map((pn) => pn.value);
  const systemModelPartNumbers = new Set(systemModel.partNumbers);
  const formPartNumbers = new Set(partNumbers);
  const partNumbersEqual =
    formPartNumbers.size === systemModelPartNumbers.size &&
    [...formPartNumbers].every((pn) => systemModelPartNumbers.has(pn));
  if (!partNumbersEqual) {
    diff.partNumbers = partNumbers;
  }

  return diff;
};

type Props = {
  systemModelRef: UpdateSystemModel_SystemModelFragment$key;
  optionsRef: UpdateSystemModel_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: SystemModelChanges) => void;
  onDelete: () => void;
};

const UpdateSystemModelForm = ({
  systemModelRef,
  optionsRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const systemModel = useFragment(UPDATE_SYSTEM_MODEL_FRAGMENT, systemModelRef);
  const {
    tenantInfo: { defaultLocale: locale },
  } = useFragment(UPDATE_SYSTEM_MODEL_OPTIONS_FRAGMENT, optionsRef);

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
    defaultValues: transformInputData(systemModel),
    resolver: yupResolver(systemModelSchema),
  });

  const partNumbers = useFieldArray({
    control,
    name: "partNumbers",
  });

  const onFormSubmit = (data: FormData) =>
    onSubmit(transformOutputData(systemModel, locale, data));
  const canSubmit = !isLoading && isDirty;
  const canReset = isDirty && !isLoading;

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

  useEffect(() => {
    reset(transformInputData(systemModel));
  }, [systemModel, reset]);

  const pictureFile = watch("pictureFile");
  const picture =
    pictureFile instanceof FileList && pictureFile.length > 0
      ? URL.createObjectURL(pictureFile[0]) // picture is the new file
      : pictureFile === null
      ? null // picture is removed
      : systemModel.pictureUrl; // picture is unchanged

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
                <Figure alt={systemModel.name} src={picture || undefined} />
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
                    id="forms.UpdateSystemModel.nameLabel"
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
                    id="forms.UpdateSystemModel.handleLabel"
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
                      id="forms.UpdateSystemModel.descriptionLabel"
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
                    id="forms.UpdateSystemModel.hardwareTypeLabel"
                    defaultMessage="Hardware Type"
                  />
                }
              >
                <Form.Control
                  {...register("hardwareType")}
                  plaintext
                  readOnly
                />
              </FormRow>
              <FormRow
                id="system-model-form-part-numbers"
                label={
                  <FormattedMessage
                    id="forms.UpdateSystemModel.partNumbersLabel"
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
                      id="forms.UpdateSystemModel.addPartNumberButton"
                      defaultMessage="Add part number"
                    />
                  </Button>
                </Stack>
              </FormRow>
            </Stack>
          </Col>
        </Row>
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateSystemModel.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            disabled={!canReset}
            variant="secondary"
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateSystemModel.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateSystemModel.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export type { SystemModelChanges };

export default UpdateSystemModelForm;
