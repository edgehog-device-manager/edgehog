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
import { useMemo, useState } from "react";
import { InputGroup } from "react-bootstrap";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { UpdateImageCredential_imageCredential_Fragment$key } from "@/api/__generated__/UpdateImageCredential_imageCredential_Fragment.graphql";
import Button from "@/components/ui/button/Button";
import Form from "@/components/ui/form/Form";
import Icon from "@/components/ui/icon/Icon";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import { FormRow } from "@/components/ui/form-row/FormRow";
import {
  ImageCredentialUpdateFormData,
  imageCredentialUpdateSchema,
} from "@/forms/validation";
import FormFeedback from "@/forms/FormFeedback";

const IMAGE_CREDENTIAL_FRAGMENT = graphql`
  fragment UpdateImageCredential_imageCredential_Fragment on ImageCredentials {
    id
    label
    username
  }
`;

interface Props {
  imageCredentialRef: UpdateImageCredential_imageCredential_Fragment$key;
  isLoading?: boolean;
  onSubmit: (
    data: ImageCredentialUpdateFormData,
    onSuccess?: () => void,
  ) => void;
  onDelete(): void;
}

const UpdateImageCredentialForm = ({
  imageCredentialRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const { id, label, username } = useFragment(
    IMAGE_CREDENTIAL_FRAGMENT,
    imageCredentialRef,
  );

  const defaultValues = useMemo<ImageCredentialUpdateFormData>(
    () => ({
      id,
      label,
      username,
      password: "",
    }),
    [id, label, username],
  );

  const {
    register,
    reset,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<ImageCredentialUpdateFormData>({
    mode: "onTouched",
    defaultValues,
    resolver: zodResolver(imageCredentialUpdateSchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const [showPassword, setShowPassword] = useState(false);

  const handleFormSubmit = (data: ImageCredentialUpdateFormData) => {
    setShowPassword(false);
    onSubmit(data, () => reset(defaultValues));
  };

  const canSubmit = !isLoading && isDirty;
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} autoComplete="off">
      <Stack gap={3}>
        <FormRow
          id="image-credential-form-label"
          label={
            <FormattedMessage
              id="forms.UpdateImageCredential.labelLabel"
              defaultMessage="Label"
            />
          }
        >
          <Form.Control {...register("label")} isInvalid={!!errors.label} />

          <FormFeedback feedback={errors.label?.message} />
        </FormRow>
        <FormRow
          id="image-credential-form-username"
          label={
            <FormattedMessage
              id="forms.UpdateImageCredential.usernameLabel"
              defaultMessage="Username"
            />
          }
        >
          <Form.Control
            {...register("username")}
            autoComplete="off"
            isInvalid={!!errors.username}
          />
          <FormFeedback feedback={errors.username?.message} />
        </FormRow>
        <FormRow
          id="image-credential-form-password"
          label={
            <FormattedMessage
              id="forms.UpdateImageCredential.passwordLabel"
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
            <FormFeedback feedback={errors.password?.message} />
          </InputGroup>
        </FormRow>
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateImageCredential.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateImageCredential.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateImageCredential.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export default UpdateImageCredentialForm;
