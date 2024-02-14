/*
  This file is part of Edgehog.

  Copyright 2022-2024 SECO Mind Srl

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
import { deviceGroupHandleSchema, yup } from "forms";
import { graphql, useFragment } from "react-relay/hooks";
import type { UpdateDeviceGroup_DeviceGroupFragment$key } from "api/__generated__/UpdateDeviceGroup_DeviceGroupFragment.graphql";

const UPDATE_DEVICE_GROUP_FRAGMENT = graphql`
  fragment UpdateDeviceGroup_DeviceGroupFragment on DeviceGroup {
    name
    handle
    selector
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

type DeviceGroupData = {
  name: string;
  handle: string;
  selector: string;
};

const deviceGroupSchema = yup
  .object({
    name: yup.string().required(),
    handle: deviceGroupHandleSchema.required(),
    selector: yup.string().required(),
  })
  .required();

type Props = {
  deviceGroupRef: UpdateDeviceGroup_DeviceGroupFragment$key;
  isLoading?: boolean;
  onSubmit: (data: DeviceGroupData) => void;
  onDelete: () => void;
};

const UpdateDeviceGroupForm = ({
  deviceGroupRef,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const deviceGroupData = useFragment(
    UPDATE_DEVICE_GROUP_FRAGMENT,
    deviceGroupRef,
  );

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<DeviceGroupData>({
    mode: "onTouched",
    defaultValues: deviceGroupData,
    resolver: yupResolver(deviceGroupSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="device-group-form-name"
          label={
            <FormattedMessage
              id="components.UpdateDeviceGroupForm.nameLabel"
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
          id="device-group-form-handle"
          label={
            <FormattedMessage
              id="components.UpdateDeviceGroupForm.handleLabel"
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
          id="device-group-form-selector"
          label={
            <FormattedMessage
              id="components.UpdateDeviceGroupForm.selectorLabel"
              defaultMessage="Selector"
            />
          }
        >
          <Form.Control
            as="textarea"
            {...register("selector")}
            isInvalid={!!errors.selector}
          />
          <Form.Control.Feedback type="invalid">
            {errors.selector?.message && (
              <FormattedMessage id={errors.selector?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center gap-2">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.UpdateDeviceGroupForm.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="components.UpdateDeviceGroupForm.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { DeviceGroupData };

export default UpdateDeviceGroupForm;
