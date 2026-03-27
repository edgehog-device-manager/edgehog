// This file is part of Edgehog.
//
// Copyright 2022 - 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { zodResolver } from "@hookform/resolvers/zod";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";
import FormFeedback from "@/forms/FormFeedback";
import { DeviceGroupFormData, deviceGroupSchema } from "@/forms/validation";

const initialData: DeviceGroupFormData = {
  name: "",
  handle: "",
  selector: "",
};

type Props = {
  isLoading?: boolean;
  onSubmit: (data: DeviceGroupFormData) => void;
};

const CreateDeviceGroup = ({ isLoading = false, onSubmit }: Props) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<DeviceGroupFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(deviceGroupSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="device-group-form-name"
          label={
            <FormattedMessage
              id="forms.CreateDeviceGroup.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>
        <FormRow
          id="device-group-form-handle"
          label={
            <FormattedMessage
              id="forms.CreateDeviceGroup.handleLabel"
              defaultMessage="Handle"
            />
          }
        >
          <Form.Control {...register("handle")} isInvalid={!!errors.handle} />
          <FormFeedback feedback={errors.handle?.message} />
        </FormRow>
        <FormRow
          id="device-group-form-selector"
          label={
            <FormattedMessage
              id="forms.CreateDeviceGroup.selectorLabel"
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
          <FormFeedback feedback={errors.selector?.message} />
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateDeviceGroup.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export default CreateDeviceGroup;
