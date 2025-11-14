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

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Form from "components/Form";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { handleSchema, yup } from "forms";

import type { UpdateDeviceGroup_DeviceGroupFragment$key } from "api/__generated__/UpdateDeviceGroup_DeviceGroupFragment.graphql";

const UPDATE_DEVICE_GROUP_FRAGMENT = graphql`
  fragment UpdateDeviceGroup_DeviceGroupFragment on DeviceGroup {
    name
    handle
    selector
  }
`;

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
  const { name, handle, selector } = useFragment(
    UPDATE_DEVICE_GROUP_FRAGMENT,
    deviceGroupRef,
  );

  const defaultValues = useMemo(
    () => ({ name, handle, selector }),
    [name, handle, selector],
  );

  const {
    register,
    reset,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<DeviceGroupData>({
    mode: "onTouched",
    defaultValues,
    resolver: yupResolver(deviceGroupSchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const canSubmit = !isLoading && isDirty;
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="device-group-form-name"
          label={
            <FormattedMessage
              id="forms.UpdateDeviceGroup.nameLabel"
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
              id="forms.UpdateDeviceGroup.handleLabel"
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
              id="forms.UpdateDeviceGroup.selectorLabel"
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
        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="primary" type="submit" disabled={!canSubmit}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.UpdateDeviceGroup.submitButton"
              defaultMessage="Update"
            />
          </Button>
          <Button
            variant="secondary"
            disabled={!canReset}
            onClick={() => reset()}
          >
            <FormattedMessage
              id="forms.UpdateDeviceGroup.resetButton"
              defaultMessage="Reset"
            />
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <FormattedMessage
              id="forms.UpdateDeviceGroup.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>
      </Stack>
    </form>
  );
};

export type { DeviceGroupData };

export default UpdateDeviceGroupForm;
