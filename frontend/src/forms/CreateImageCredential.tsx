/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import { yupResolver } from "@hookform/resolvers/yup";
import { FunctionComponent, PropsWithChildren, ReactNode } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { createImageCredentialSchema } from "schema/ImageCredential";
import type { CreateImageCredential } from "types/ImageCredential";
import "./CreateImageCredential.scss";

interface FormRowProps extends PropsWithChildren {
  controlId: string;
  label: ReactNode;
}

const FormRow: FunctionComponent<FormRowProps> = ({
  controlId,
  label,
  children,
}) => (
  <Form.Group as={Row} controlId={controlId}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

interface Props {
  isLoading?: boolean;
  onSubmit: (data: CreateImageCredential) => void;
}

const CreateImageCredentialForm: FunctionComponent<Props> = ({
  isLoading = false,
  onSubmit,
}) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<CreateImageCredential>({
    mode: "onTouched",
    defaultValues: {},
    resolver: yupResolver(createImageCredentialSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} autoComplete="off">
      <input
        id="username"
        type="text"
        name="fakeusernameremembered"
        autoComplete="username"
        style={{ display: "none" }}
      />
      <input
        id="password"
        type="password"
        name="fakepasswordremembered"
        autoComplete="new-password"
        style={{ display: "none" }}
      />
      <Stack gap={3}>
        <FormRow
          controlId="image-credential-form-label"
          label={
            <FormattedMessage
              id="components.CreateImageCredentialForm.labelLabel"
              defaultMessage="Label"
            />
          }
        >
          <Form.Control {...register("label")} isInvalid={!!errors.label} />
          <Form.Control.Feedback type="invalid">
            {errors.label?.message && (
              <FormattedMessage id={errors.label?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          controlId="image-credential-form-username"
          label={
            <FormattedMessage
              id="components.CreateImageCredentialForm.usernameLabel"
              defaultMessage="Username"
            />
          }
        >
          <Form.Control
            {...register("username")}
            autoComplete="off"
            isInvalid={!!errors.username}
          />
          <Form.Control.Feedback type="invalid">
            {errors.username?.message && (
              <FormattedMessage id={errors.username?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          controlId="image-credential-form-password"
          label={
            <FormattedMessage
              id="components.CreateImageCredentialForm.passwordLabel"
              defaultMessage="Password"
            />
          }
        >
          <Form.Control
            {...register("password")}
            className="security"
            isInvalid={!!errors.password}
            autoComplete="new-password"
            onCopy={(e) => e.preventDefault()}
            onCut={(e) => e.preventDefault()}
          />

          <Form.Control.Feedback type="invalid">
            {errors.password?.message && (
              <FormattedMessage id={errors.password?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateImageCredentialForm.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export default CreateImageCredentialForm;
