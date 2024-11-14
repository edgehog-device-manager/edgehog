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

import React from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { yup } from "forms";

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

type ApplicationData = {
  name: string;
  description: string;
};

const applicationSchema = yup
  .object({
    name: yup.string().required(),
    description: yup.string(),
  })
  .required();

const initialData: ApplicationData = {
  name: "",
  description: "",
};

type Props = {
  isLoading?: boolean;
  onSubmit: (data: ApplicationData) => void;
};

const CreateApplication = ({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ApplicationData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(applicationSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="application-form-name"
          label={
            <FormattedMessage
              id="components.CreateApplication.nameLabel"
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
          id="application-form-description"
          label={
            <FormattedMessage
              id="components.CreateApplication.descriptionLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.description?.message && (
              <FormattedMessage id={errors.description?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateApplication.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { ApplicationData };

export default CreateApplication;
