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
import { FieldError, useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";

import { yup, envSchema } from "forms";

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

type NetworkData = {
  label: string;
  driver?: string;
  options?: string;
  internal?: boolean;
  enableIpv6?: boolean;
};

const networkSchema = yup
  .object({
    label: yup.string().required(),
    driver: yup.string().nullable(),
    options: envSchema.nullable(),
    internal: yup.boolean(),
    enableIpv6: yup.boolean(),
  })
  .required();

const initialData: NetworkData = {
  label: "",
  driver: "",
  options: "",
  internal: false,
  enableIpv6: false,
};

interface Props {
  isLoading?: boolean;
  onSubmit: (data: NetworkData) => void;
}

const ErrorMessage = ({ error }: { error?: FieldError }) => {
  if (!error?.message) return null;
  return (
    <Form.Control.Feedback type="invalid" role="alert">
      <FormattedMessage id={error.message} defaultMessage={error.message} />
    </Form.Control.Feedback>
  );
};

const CreateNetwork = React.memo(({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors, isValid, isSubmitting },
  } = useForm<NetworkData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(networkSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} autoComplete="off">
      <FormRow
        id="networkLabel"
        label={
          <FormattedMessage
            id="components.CreateNetworkForm.labelLabel"
            defaultMessage="Label"
          />
        }
      >
        <Form.Control {...register("label")} isInvalid={!!errors.label} />
        <ErrorMessage error={errors.label} />
      </FormRow>

      <FormRow
        id="networkDriver"
        label={
          <FormattedMessage
            id="components.CreateNetworkForm.driverLabel"
            defaultMessage="Driver"
          />
        }
      >
        <Form.Control {...register("driver")} isInvalid={!!errors.driver} />
        <ErrorMessage error={errors.driver} />
      </FormRow>

      <FormRow
        id="networkOptions"
        label={
          <FormattedMessage
            id="components.CreateNetworkForm.optionsLabel"
            defaultMessage="Options"
          />
        }
      >
        <Form.Control
          as="textarea"
          rows={5}
          {...register("options")}
          isInvalid={!!errors.options}
        />
        <ErrorMessage error={errors.options} />
      </FormRow>

      <FormRow
        id="networkInternal"
        label={
          <FormattedMessage
            id="components.CreateNetworkForm.internalLabel"
            defaultMessage="Internal"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("internal")}
          isInvalid={!!errors.internal}
        />
        <ErrorMessage error={errors.internal} />
      </FormRow>

      <FormRow
        id="networkEnableIpv6"
        label={
          <FormattedMessage
            id="components.CreateNetworkForm.enableIpv6Label"
            defaultMessage="Enable IPv6"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("enableIpv6")}
          isInvalid={!!errors.enableIpv6}
        />
        <ErrorMessage error={errors.enableIpv6} />
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
              id="components.CreateNetworkForm.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
});

export type { NetworkData };
export default CreateNetwork;
