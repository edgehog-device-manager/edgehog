/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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
import { useMemo } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { UpdateImageCredential_imageCredential_Fragment$key } from "api/__generated__/UpdateImageCredential_imageCredential_Fragment.graphql";
import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Stack from "components/Stack";
import { yup } from "forms";

const IMAGE_CREDENTIAL_FRAGMENT = graphql`
  fragment UpdateImageCredential_imageCredential_Fragment on ImageCredentials {
    id
    label
    username
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

type FormData = {
  id: string;
  label: string;
  username: string;
};

const imageCredentialSchema = yup
  .object({
    id: yup.string().required(),
    label: yup.string().required(),
    username: yup.string().required(),
  })
  .required();

interface Props {
  imageCredentialRef: UpdateImageCredential_imageCredential_Fragment$key;
  isLoading?: boolean;
  onDelete(): void;
}

const UpdateImageCredentialForm = ({ imageCredentialRef, onDelete }: Props) => {
  const { id, label, username } = useFragment(
    IMAGE_CREDENTIAL_FRAGMENT,
    imageCredentialRef,
  );

  const defaultValues = useMemo<FormData>(
    () => ({
      id,
      label,
      username,
    }),
    [id, label, username],
  );

  const {
    register,
    formState: { errors },
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues,
    resolver: yupResolver(imageCredentialSchema),
  });

  return (
    <form>
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
          <Form.Control
            {...register("label")}
            readOnly
            isInvalid={!!errors.label}
          />

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
              id="forms.UpdateImageCredential.usernameLabel"
              defaultMessage="Username"
            />
          }
        >
          <Form.Control
            {...register("username")}
            readOnly
            isInvalid={!!errors.username}
          />
          <Form.Control.Feedback type="invalid">
            {errors.username?.message && (
              <FormattedMessage id={errors.username?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
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
