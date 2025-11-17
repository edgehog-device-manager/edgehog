/*
  This file is part of Edgehog.

  Copyright 2022 - 2025 SECO Mind Srl

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
import Form from "components/Form";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { handleSchema, yup } from "forms";

type DeviceGroupData = {
  name: string;
  handle: string;
  selector: string;
};

const deviceGroupSchema = yup
  .object({
    name: yup.string().required(),
    handle: handleSchema.required(),
    selector: yup.string().required(),
  })
  .required();

const initialData: DeviceGroupData = {
  name: "",
  handle: "",
  selector: "",
};

type Props = {
  isLoading?: boolean;
  onSubmit: (data: DeviceGroupData) => void;
};

const CreateDeviceGroup = ({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<DeviceGroupData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(deviceGroupSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="device-group-form-name"
          label={
            <FormattedMessage
              id="components.CreateDeviceGroup.nameLabel"
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
              id="components.CreateDeviceGroup.handleLabel"
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
              id="components.CreateDeviceGroup.selectorLabel"
              defaultMessage="Selector"
            />
          }
        >
          <Form.Control
            as="textarea"
            rows={2}
            {...register("selector")}
            isInvalid={!!errors.selector}
          />
          <Form.Control.Feedback type="invalid">
            {errors.selector?.message && (
              <FormattedMessage id={errors.selector?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateDeviceGroup.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { DeviceGroupData };

export default CreateDeviceGroup;
