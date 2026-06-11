/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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
import { useMemo } from "react";
import { Controller, useForm } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import Select from "react-select";

import Button from "@/components/Button";
import Col from "@/components/Col";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import FormFeedback from "@/forms/FormFeedback";

import { fileDeleteRequestFormSchema } from "./validation";

type StorageSourceOption = {
  value: string;
  label: string;
};

type ManualFileDeleteRequestFormValues = {
  deviceFileId: string;
  force: boolean;
};

type ManualFileDeleteRequestFormProps = {
  className?: string;
  isLoading: boolean;
  onSubmit: (values: ManualFileDeleteRequestFormValues) => void;
  deleteOptions: StorageSourceOption[];
  onLoadMoreDeleteOptions?: () => void;
};

const ManualFileDeleteRequestForm = ({
  className,
  isLoading,
  onSubmit,
  deleteOptions,
  onLoadMoreDeleteOptions,
}: ManualFileDeleteRequestFormProps) => {
  const intl = useIntl();
  const {
    formState: { errors },
    handleSubmit,
    register,
    control,
    reset,
  } = useForm<ManualFileDeleteRequestFormValues>({
    mode: "onTouched",
    resolver: zodResolver(fileDeleteRequestFormSchema),
    defaultValues: {
      deviceFileId: "",
      force: false,
    },
  });

  const deleteOptionsMap = useMemo(
    () => new Map(deleteOptions.map((opt) => [opt.value, opt])),
    [deleteOptions],
  );

  const submitHandler = handleSubmit((data) => {
    onSubmit(data);
    reset();
  });

  return (
    <form className={className} onSubmit={submitHandler} autoComplete="off">
      <FormRow
        id="deviceFileId"
        label={
          <FormattedMessage
            id="forms.ManualFileDeleteRequestForm.fileLabel"
            defaultMessage="File"
          />
        }
      >
        <Controller
          control={control}
          name="deviceFileId"
          render={({ field, fieldState }) => {
            const selectedOption = deleteOptionsMap.get(field.value) ?? null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => field.onChange(option?.value ?? "")}
                options={deleteOptions}
                onMenuScrollToBottom={onLoadMoreDeleteOptions}
                placeholder={intl.formatMessage({
                  id: "forms.ManualFileDeleteRequestForm.filePlaceholder",
                  defaultMessage: "Select a file to delete...",
                })}
                noOptionsMessage={() =>
                  intl.formatMessage({
                    id: "forms.ManualFileDeleteRequestForm.fileNoOptions",
                    defaultMessage: "No files for delete.",
                  })
                }
                isClearable
                className={fieldState.invalid ? "is-invalid" : ""}
              />
            );
          }}
        />

        <FormFeedback feedback={errors.deviceFileId?.message} />
      </FormRow>

      <FormRow
        id="force"
        label={
          <FormattedMessage
            id="forms.ManualFileDeleteRequestForm.forceLabel"
            defaultMessage="Force delete"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("force")}
          isInvalid={!!errors.force}
        />

        <small className="text-muted mt-1">
          <FormattedMessage
            id="forms.ManualFileDeleteRequestForm.forceDescription"
            defaultMessage="Deletes files even if they are currently in use, this could cause errors."
          />
        </small>

        <FormFeedback feedback={errors.force?.message} />
      </FormRow>

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="danger" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}

            <FormattedMessage
              id="forms.ManualFileDeleteRequestForm.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export type { ManualFileDeleteRequestFormValues, StorageSourceOption };

export default ManualFileDeleteRequestForm;
