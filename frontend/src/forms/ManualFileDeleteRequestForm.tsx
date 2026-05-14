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
import { Controller, useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
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
  fileDownloadRequestId: string;
  force: boolean;
};

type ManualFileDeleteRequestFormProps = {
  className?: string;
  isLoading: boolean;
  onSubmit: (values: ManualFileDeleteRequestFormValues) => void;
  deleteOptions: StorageSourceOption[];
};

const ManualFileDeleteRequestForm = ({
  className,
  isLoading,
  onSubmit,
  deleteOptions,
}: ManualFileDeleteRequestFormProps) => {
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
      fileDownloadRequestId: "",
      force: false,
    },
  });

  const submitHandler = handleSubmit((data) => {
    onSubmit(data);
    reset();
  });

  return (
    <form className={className} onSubmit={submitHandler} autoComplete="off">
      <FormRow
        id="fileDownloadRequestId"
        label={
          <FormattedMessage
            id="forms.ManualFileDeleteRequestForm.fileLabel"
            defaultMessage="Select File"
          />
        }
      >
        <Controller
          control={control}
          name="fileDownloadRequestId"
          render={({ field }) => {
            const selectedOption =
              deleteOptions.find((opt) => opt.value === field.value) || null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => field.onChange(option?.value ?? "")}
                options={deleteOptions}
                isClearable
              />
            );
          }}
        />

        <FormFeedback feedback={errors.fileDownloadRequestId?.message} />
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
