/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import React from "react";
import { yupResolver } from "@hookform/resolvers/yup";
import { Controller, FieldError, useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";

import { yup, envSchema } from "forms";
import MonacoJsonEditor from "components/MonacoJsonEditor";

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <Form.Group as={Row} controlId={id} className="mb-4">
    <Form.Label column sm={3} className="fw-bold">
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

type VolumeData = {
  label: string;
  driver?: string;
  options?: string;
};

const volumeSchema = yup
  .object({
    label: yup.string().required(),
    driver: yup.string().nullable(),
    options: envSchema.nullable().notRequired(),
  })
  .required();

const initialData: VolumeData = {
  label: "",
  driver: "",
  options: "",
};

interface Props {
  isLoading?: boolean;
  onSubmit: (data: VolumeData) => void;
}

const ErrorMessage = ({ error }: { error?: FieldError }) => {
  if (!error?.message) return null;
  return (
    <Form.Control.Feedback type="invalid" role="alert">
      <FormattedMessage id={error.message} defaultMessage={error.message} />
    </Form.Control.Feedback>
  );
};

const CreateVolume = React.memo(({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isValid, isSubmitting },
  } = useForm<VolumeData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(volumeSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} autoComplete="off">
      <FormRow
        id="volumeLabel"
        label={
          <FormattedMessage
            id="components.CreateVolumeForm.labelLabel"
            defaultMessage="Label"
          />
        }
      >
        <Form.Control
          as="textarea"
          rows={1}
          {...register("label")}
          isInvalid={!!errors.label}
        />
        <ErrorMessage error={errors.label} />
      </FormRow>

      <FormRow
        id="volumeDriver"
        label={
          <FormattedMessage
            id="components.CreateVolumeForm.driverLabel"
            defaultMessage="Driver"
          />
        }
      >
        <Form.Control
          as="textarea"
          rows={1}
          {...register("driver")}
          isInvalid={!!errors.driver}
        />
        <ErrorMessage error={errors.driver} />
      </FormRow>

      <FormRow
        id="volumeOptions"
        label={
          <FormattedMessage
            id="components.CreateVolumeForm.optionsLabel"
            defaultMessage="Options"
          />
        }
      >
        <Controller
          control={control}
          name={"options"}
          render={({ field, fieldState: _fieldState }) => (
            <MonacoJsonEditor
              value={field.value ?? ""}
              onChange={(value) => {
                field.onChange(value ?? "");
              }}
              defaultValue={field.value || "{}"}
            />
          )}
        />
      </FormRow>

      <Row className="mt-4">
        <Col
          sm={{ span: 10, offset: 2 }}
          className="d-flex justify-content-end"
        >
          <Button
            variant="primary"
            type="submit"
            disabled={isLoading || isSubmitting || !isValid}
          >
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateVolumeForm.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
});

export type { VolumeData };
export default CreateVolume;
