/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { zodResolver } from "@hookform/resolvers/zod";
import { InputGroup } from "react-bootstrap";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import Icon from "@/components/Icon";
import { FormRow } from "@/components/FormRow";
import {
  ImageCredentialFormData,
  imageCredentialSchema,
} from "@/forms/validation";

const initialData: ImageCredentialFormData = {
  label: "",
  username: "",
  password: "",
  serveraddress: "",
};

interface Props {
  isLoading?: boolean;
  onSubmit: (data: ImageCredentialFormData) => void;
}

const CreateImageCredential = ({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ImageCredentialFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(imageCredentialSchema),
  });

  const [showPassword, setShowPassword] = useState(false);

  const handleFormSubmit = (data: ImageCredentialFormData) => {
    setShowPassword(false);
    onSubmit(data);
  };

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} autoComplete="off">
      <Stack gap={3}>
        <FormRow
          id="image-credential-form-label"
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
          id="image-credential-form-username"
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
          id="image-credential-form-password"
          label={
            <FormattedMessage
              id="components.CreateImageCredentialForm.passwordLabel"
              defaultMessage="Password"
            />
          }
        >
          <InputGroup>
            <Form.Control
              {...register("password")}
              type={showPassword ? "text" : "password"}
              isInvalid={!!errors.password}
              autoComplete="off"
              onCopy={(e) => e.preventDefault()}
              onCut={(e) => e.preventDefault()}
            />
            <Button
              variant={"outlined"}
              onClick={() => setShowPassword(!showPassword)}
              style={{
                borderTopRightRadius: "0.25rem",
                borderBottomRightRadius: "0.25rem",
                borderTopLeftRadius: "0",
                borderBottomLeftRadius: "0",
                backgroundColor: "#e0e0e0",
              }}
            >
              <Icon
                icon={showPassword ? "showPassword" : "hidePassword"}
                style={{ width: "1.4em" }}
              />
            </Button>
            <Form.Control.Feedback type="invalid">
              {errors.password?.message && (
                <FormattedMessage id={errors.password?.message} />
              )}
            </Form.Control.Feedback>
          </InputGroup>
        </FormRow>

        <FormRow
          id="image-credential-form-serveraddress"
          label={
            <FormattedMessage
              id="components.CreateImageCredentialForm.ServeraddressLabel"
              defaultMessage="Server Address"
            />
          }
        >
          <Form.Control
            {...register("serveraddress")}
            autoComplete="off"
            isInvalid={!!errors.serveraddress}
          />
          <Form.Control.Feedback type="invalid">
            {errors.serveraddress?.message && (
              <FormattedMessage id={errors.serveraddress?.message} />
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

export default CreateImageCredential;
