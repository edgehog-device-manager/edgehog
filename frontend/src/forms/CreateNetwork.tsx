/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

import React, { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { Controller, useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "@/components/ui/button/Button";
import Col from "@/components/ui/col/Col";
import Form from "@/components/ui/form/Form";
import Row from "@/components/ui/row/Row";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";

import MonacoJsonEditor from "@/components/ui/monaco-json-editor/MonacoJsonEditor";
import { FormRowWithMargin as FormRow } from "@/components/ui/form-row/FormRow";
import { NetworkFormData, networkSchema } from "@/forms/validation";
import FormFeedback from "@/forms/FormFeedback";

const initialData: NetworkFormData = {
  label: "",
};

interface Props {
  defaultValues?: NetworkFormData;
  isLoading?: boolean;
  onSubmit: (data: NetworkFormData) => void;
  onDelete?: () => void;
}

const CreateNetwork = ({
  defaultValues,
  isLoading = false,
  onSubmit,
  onDelete,
}: Props) => {
  const {
    register,
    reset,
    handleSubmit,
    control,
    formState: { errors, isDirty },
  } = useForm<NetworkFormData>({
    mode: "onTouched",
    defaultValues: defaultValues ?? initialData,
    resolver: zodResolver(networkSchema),
  });

  const [prevDefaultValues, setPrevDefaultValues] = useState(defaultValues);
  if (defaultValues && prevDefaultValues !== defaultValues) {
    reset(defaultValues);
    setPrevDefaultValues(defaultValues);
  }

  const canSubmit = !isLoading && (!defaultValues || isDirty);
  const canReset = isDirty && !isLoading;

  return (
    <form onSubmit={handleSubmit(onSubmit)} autoComplete="off">
      <FormRow
        id="networkLabel"
        label={
          <FormattedMessage
            id="forms.CreateNetwork.labelLabel"
            defaultMessage="Label"
          />
        }
      >
        <Form.Control {...register("label")} isInvalid={!!errors.label} />
        <FormFeedback feedback={errors.label?.message} />
      </FormRow>

      <FormRow
        id="networkDriver"
        label={
          <FormattedMessage
            id="forms.CreateNetwork.driverLabel"
            defaultMessage="Driver"
          />
        }
      >
        <Form.Control {...register("driver")} isInvalid={!!errors.driver} />
        <FormFeedback feedback={errors.driver?.message} />
      </FormRow>

      <FormRow
        id="networkOptions"
        label={
          <FormattedMessage
            id="forms.CreateNetwork.optionsLabel"
            defaultMessage="Options"
          />
        }
      >
        <Controller
          control={control}
          name={"options"}
          render={({ field, fieldState }) => (
            <MonacoJsonEditor
              value={field.value ?? ""}
              onChange={(value) => {
                field.onChange(value ?? "");
              }}
              defaultValue={field.value || "{}"}
              error={fieldState.error?.message}
            />
          )}
        />
      </FormRow>

      <FormRow
        id="networkInternal"
        label={
          <FormattedMessage
            id="forms.CreateNetwork.internalLabel"
            defaultMessage="Internal"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("internal")}
          isInvalid={!!errors.internal}
        />
        <FormFeedback feedback={errors.internal?.message} />
      </FormRow>

      <FormRow
        id="networkEnableIpv6"
        label={
          <FormattedMessage
            id="forms.CreateNetwork.enableIpv6Label"
            defaultMessage="Enable IPv6"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("enableIpv6")}
          isInvalid={!!errors.enableIpv6}
        />
        <FormFeedback feedback={errors.enableIpv6?.message} />
      </FormRow>

      <Row className="mt-4">
        <Col
          sm={{ span: 10, offset: 2 }}
          className="d-flex justify-content-end"
        >
          {defaultValues ? (
            <Stack
              direction="horizontal"
              gap={3}
              className="justify-content-end align-items-center"
            >
              <Button variant="primary" type="submit" disabled={!canSubmit}>
                {isLoading && <Spinner size="sm" className="me-2" />}
                <FormattedMessage
                  id="forms.CreateNetwork.updateButton"
                  defaultMessage="Update"
                />
              </Button>
              <Button
                variant="secondary"
                disabled={!canReset}
                onClick={() => reset()}
              >
                <FormattedMessage
                  id="forms.CreateNetwork.resetButton"
                  defaultMessage="Reset"
                />
              </Button>
              {onDelete && (
                <Button variant="danger" onClick={onDelete}>
                  <FormattedMessage
                    id="forms.CreateNetwork.deleteButton"
                    defaultMessage="Delete"
                  />
                </Button>
              )}
            </Stack>
          ) : (
            <Button variant="primary" type="submit" disabled={!canSubmit}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="forms.CreateNetwork.submitButton"
                defaultMessage="Create"
              />
            </Button>
          )}
        </Col>
      </Row>
    </form>
  );
};

export default React.memo(CreateNetwork);
