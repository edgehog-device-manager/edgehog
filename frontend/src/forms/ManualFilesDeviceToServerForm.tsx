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
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import Select from "react-select";

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

type ManualFilesDeviceToServerFormProps = {
  className?: string;
  isLoading: boolean;
  onSubmit: (values: ManualFileUploadRequestData) => void;
  supportedEncodingsBySourceType: Record<FileSourceType, string[]>;
  sourceTypeOptions: SourceTypeOption[];
  storageSourceOptions: StorageSourceOption[];
  onLoadMoreStorageOptions?: () => void;
};

const ManualFilesDeviceToServerForm = ({
  className,
  isLoading,
  onSubmit,
  supportedEncodingsBySourceType,
  sourceTypeOptions,
  storageSourceOptions,
  onLoadMoreStorageOptions,
}: ManualFilesDeviceToServerFormProps) => {
  const intl = useIntl();

  const {
    control,
    formState: { errors },
    handleSubmit,
    register,
    setValue,
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

  const sourcePlaceholderByType = useMemo<Record<FileSourceType, string>>(
    () => ({
      STORAGE: intl.formatMessage({
        id: "forms.ManualFilesDeviceToServerForm.sourceStoragePlaceholder",
        defaultMessage: "Select storage file by its name...",
      }),
      FILESYSTEM: "/tmp/file.bin",
    }),
    [intl],
  );

  const encodingOptions = useMemo<CompressionOption[]>(() => {
    const encodings = supportedEncodingsBySourceType[effectiveSourceType] ?? [];
    return [
      {
        value: "",
        label: intl.formatMessage({
          id: "forms.ManualFilesDeviceToServerForm.encodingNone",
          defaultMessage: "None",
        }),
      },
      ...encodings.map((encoding) => ({ value: encoding, label: encoding })),
    ];
  }, [supportedEncodingsBySourceType, effectiveSourceType, intl]);

  const onFormSubmit = handleSubmit((data) => {
    onSubmit(data);
    reset();
  });

  return (
    <form className={className} onSubmit={onFormSubmit} autoComplete="off">
      <FormRow
        id="sourceType"
        label={
          <FormattedMessage
            id="forms.ManualFilesDeviceToServerForm.sourceTypeLabel"
            defaultMessage="Source Type"
          />
        }
      >
        <Controller
          control={control}
          name="sourceType"
          render={({ field }) => (
            <Select
              value={
                sourceTypeOptions.find((opt) => opt.value === field.value) ??
                null
              }
              onChange={(option) => {
                field.onChange(option?.value ?? null);
                setValue("encoding", ""); // Cleanly resets encoding without triggering a full form rerender loop
              }}
              options={sourceTypeOptions}
            />
          )}
        />
      </FormRow>

      <FormRow
        id="source"
        label={
          <FormattedMessage
            id="forms.ManualFilesDeviceToServerForm.sourceLabel"
            defaultMessage="Source"
          />
        }
      >
        <Controller
          control={control}
          name="source"
          render={({ field, fieldState }) => {
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
                <>
                  <Select
                    value={selectedOption}
                    onChange={(option) => {
                      field.onChange(option?.value ?? null);
                    }}
                    onBlur={field.onBlur}
                    options={storageSourceOptions}
                    filterOption={(option, inputValue) => {
                      // Only search by name (label), not by ID (value)
                      return option.label
                        .toLowerCase()
                        .includes(inputValue.toLowerCase());
                    }}
                    onMenuScrollToBottom={onLoadMoreStorageOptions}
                    placeholder={sourcePlaceholderByType[effectiveSourceType]}
                    noOptionsMessage={({ inputValue }) =>
                      inputValue
                        ? intl.formatMessage(
                            {
                              id: "forms.ManualFilesDeviceToServerForm.sourceStorageNoMatch",
                              defaultMessage:
                                'No file found with name "{value}"',
                            },
                            { value: inputValue },
                          )
                        : intl.formatMessage({
                            id: "forms.ManualFilesDeviceToServerForm.sourceStorageEmpty",
                            defaultMessage:
                              "No known storage file names for this device yet.",
                          })
                    }
                    isClearable
                    className={fieldState.invalid ? "is-invalid" : ""}
                  />

                  {fieldState.error && (
                    <FormFeedback feedback={fieldState.error.message} />
                  )}
                </>
              );
            }

            return (
              <>
                <Form.Control
                  type="text"
                  value={(field.value as string | null) ?? ""}
                  onChange={(event) => field.onChange(event.target.value)}
                  onBlur={field.onBlur}
                  placeholder={sourcePlaceholderByType[effectiveSourceType]}
                  isInvalid={fieldState.invalid}
                />

                {fieldState.error ? (
                  <FormFeedback feedback={fieldState.error.message} />
                ) : (
                  <Form.Text muted>
                    <FormattedMessage
                      id="forms.ManualFilesDeviceToServerForm.sourcePathHint"
                      defaultMessage="Absolute path to the file on the device that should be uploaded."
                    />
                  </Form.Text>
                )}
              </>
            );
          }}
        />
      </FormRow>

      <FormRow
        id="encoding"
        label={
          <FormattedMessage
            id="forms.ManualFilesDeviceToServerForm.encodingLabel"
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
              id="forms.ManualFilesDeviceToServerForm.encodingHint"
              defaultMessage="Optional encoding format, based on device capabilities. Leave empty for no encoding."
            />
          </Form.Text>
        )}
      </FormRow>

      <FormRow
        id="progressTracked"
        label={
          <FormattedMessage
            id="forms.ManualFilesDeviceToServerForm.progressLabel"
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
              id="forms.ManualFilesDeviceToServerForm.uploadButton"
              defaultMessage="Request Upload"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export type { SourceTypeOption, StorageSourceOption };

export default ManualFilesDeviceToServerForm;
