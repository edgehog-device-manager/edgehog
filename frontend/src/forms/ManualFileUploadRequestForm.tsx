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
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import Select from "react-select";
import CreatableSelect from "react-select/creatable";

import Button from "@/components/Button";
import Col from "@/components/Col";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import FormFeedback from "@/forms/FormFeedback";
import {
  fileUploadRequestFormSchema,
  type FileSourceType,
  type ManualFileUploadRequestData,
} from "@/forms/validation";

type SourceTypeOption = {
  value: FileSourceType;
  label: string;
};

type CompressionOption = {
  value: string;
  label: string;
};

type StorageSourceOption = {
  value: string;
  label: string;
};

type ManualFileUploadRequestFormProps = {
  className?: string;
  isLoading: boolean;
  onSubmit: (values: ManualFileUploadRequestData) => void;
  supportedEncodings: string[];
  sourceTypeOptions: SourceTypeOption[];
  storageSourceOptions: StorageSourceOption[];
};

const ManualFileUploadRequestForm = ({
  className,
  isLoading,
  onSubmit,
  supportedEncodings,
  sourceTypeOptions,
  storageSourceOptions,
}: ManualFileUploadRequestFormProps) => {
  const intl = useIntl();

  const {
    control,
    formState: { errors },
    handleSubmit,
    register,
    reset,
  } = useForm({
    mode: "onTouched",
    defaultValues: {
      sourceType: "STORAGE",
      source: null,
      encoding: "",
      progressTracked: false,
    },
    resolver: zodResolver(fileUploadRequestFormSchema),
  });

  const selectedSourceType = useWatch({
    control,
    name: "sourceType",
  });

  const effectiveSourceType = selectedSourceType ?? "STORAGE";

  const sourcePlaceholderByType: Record<FileSourceType, string> = {
    STORAGE: intl.formatMessage({
      id: "forms.ManualFileUploadRequestForm.sourceStoragePlaceholder",
      defaultMessage: "Select or enter a storage file ID",
    }),
    FILESYSTEM: "/tmp/file.bin",
  };

  const encodingOptions: CompressionOption[] = [
    {
      value: "",
      label: intl.formatMessage({
        id: "forms.ManualFileUploadRequestForm.encodingNone",
        defaultMessage: "None",
      }),
    },
    ...supportedEncodings.map((encoding) => ({
      value: encoding,
      label: encoding,
    })),
  ];

  const onFormSubmit = handleSubmit((data) => {
    onSubmit(data);
    reset({
      sourceType: data.sourceType,
      source: data.source,
      encoding: data.encoding ?? "",
      progressTracked: data.progressTracked,
    });
  });

  return (
    <form className={className} onSubmit={onFormSubmit} autoComplete="off">
      <FormRow
        id="sourceType"
        label={
          <FormattedMessage
            id="forms.ManualFileUploadRequestForm.sourceTypeLabel"
            defaultMessage="Source Type"
          />
        }
      >
        <Controller
          control={control}
          name="sourceType"
          render={({ field }) => {
            const selectedOption =
              sourceTypeOptions.find((opt) => opt.value === field.value) ||
              null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => {
                  field.onChange(option ? option.value : null);
                }}
                options={sourceTypeOptions}
              />
            );
          }}
        />
      </FormRow>

      <FormRow
        id="source"
        label={
          <FormattedMessage
            id="forms.ManualFileUploadRequestForm.sourceLabel"
            defaultMessage="Source"
          />
        }
      >
        <Controller
          control={control}
          name="source"
          render={({ field }) => {
            if (effectiveSourceType === "STORAGE") {
              const selectedOption =
                storageSourceOptions.find((opt) => opt.value === field.value) ??
                (field.value
                  ? {
                      value: field.value,
                      label: field.value,
                    }
                  : null);

              return (
                <CreatableSelect
                  value={selectedOption}
                  onChange={(option) => {
                    field.onChange(option?.value ?? null);
                  }}
                  onBlur={field.onBlur}
                  options={storageSourceOptions}
                  placeholder={sourcePlaceholderByType[effectiveSourceType]}
                  formatCreateLabel={(inputValue) =>
                    intl.formatMessage(
                      {
                        id: "forms.ManualFileUploadRequestForm.sourceStorageCreateOption",
                        defaultMessage: 'Use "{value}"',
                      },
                      { value: inputValue },
                    )
                  }
                  noOptionsMessage={() =>
                    intl.formatMessage({
                      id: "forms.ManualFileUploadRequestForm.sourceStorageNoOptions",
                      defaultMessage:
                        "No known storage file IDs for this device yet.",
                    })
                  }
                  isClearable
                />
              );
            }

            return (
              <Form.Control
                type="text"
                value={(field.value as string | null) ?? ""}
                onChange={(event) => field.onChange(event.target.value)}
                onBlur={field.onBlur}
                placeholder={sourcePlaceholderByType[effectiveSourceType]}
                isInvalid={!!errors.source}
              />
            );
          }}
        />

        {errors.source ? (
          <FormFeedback feedback={errors.source.message} />
        ) : (
          <Form.Text muted>
            {effectiveSourceType === "STORAGE" ? (
              <FormattedMessage
                id="forms.ManualFileUploadRequestForm.sourceStorageHint"
                defaultMessage="Select a known storage file ID from previous storage downloads, or type one manually."
              />
            ) : (
              <FormattedMessage
                id="forms.ManualFileUploadRequestForm.sourcePathHint"
                defaultMessage="Absolute path to the file on the device that should be uploaded."
              />
            )}
          </Form.Text>
        )}
      </FormRow>

      <FormRow
        id="encoding"
        label={
          <FormattedMessage
            id="forms.ManualFileUploadRequestForm.encodingLabel"
            defaultMessage="Encoding"
          />
        }
      >
        <Controller
          control={control}
          name="encoding"
          render={({ field }) => {
            const selectedOption =
              encodingOptions.find((opt) => opt.value === field.value) ??
              encodingOptions[0] ??
              null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => {
                  field.onChange(option?.value ?? "");
                }}
                options={encodingOptions}
              />
            );
          }}
        />

        {errors.encoding ? (
          <FormFeedback feedback={errors.encoding.message} />
        ) : (
          <Form.Text muted>
            <FormattedMessage
              id="forms.ManualFileUploadRequestForm.encodingHint"
              defaultMessage="Optional encoding format. Leave empty for no encoding."
            />
          </Form.Text>
        )}
      </FormRow>

      <FormRow
        id="progressTracked"
        label={
          <FormattedMessage
            id="forms.ManualFileUploadRequestForm.progressLabel"
            defaultMessage="Report Progress"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("progressTracked")}
          isInvalid={!!errors.progressTracked}
        />
        <FormFeedback feedback={errors.progressTracked?.message} />
      </FormRow>

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.ManualFileUploadRequestForm.uploadButton"
              defaultMessage="Request Upload"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export type { SourceTypeOption };
export type { StorageSourceOption };

export default ManualFileUploadRequestForm;
