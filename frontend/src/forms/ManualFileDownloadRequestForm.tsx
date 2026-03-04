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
import { useRef, useState } from "react";
import CloseButton from "react-bootstrap/CloseButton";
import { Controller, FieldError, useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import Select from "react-select";

import Button from "@/components/Button";
import Col from "@/components/Col";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import Tag from "@/components/Tag";
import { fileDownloadRequestFormSchema } from "@/forms/validation";

type FileDestination = "STORAGE" | "STREAMING";

type FileDownloadRequestFormValues = {
  files: File[];
  archiveName?: string;
  destination: FileDestination;
  ttlSeconds: number;
  progress: boolean;
};

type ManualFileDownloadRequestFormProps = {
  className?: string;
  isLoading: boolean;
  onFileSubmit: (values: FileDownloadRequestFormValues) => void;
};

const destinationOptions = [
  { value: "STORAGE", label: "Storage" },
  { value: "STREAMING", label: "Streaming" },
];

const ErrorMessage = ({ error }: { error?: FieldError }) => {
  if (!error?.message) return null;
  return (
    <Form.Control.Feedback type="invalid" role="alert">
      <FormattedMessage id={error.message} defaultMessage={error.message} />
    </Form.Control.Feedback>
  );
};

const ManualFileDownloadRequestForm = ({
  className,
  isLoading,
  onFileSubmit,
}: ManualFileDownloadRequestFormProps) => {
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const {
    formState: { errors },
    handleSubmit,
    register,
    control,
    setValue,
    reset,
  } = useForm({
    mode: "onTouched",
    defaultValues: {
      file: undefined,
      archiveName: "",
      destination: "STORAGE" as FileDestination,
      ttlSeconds: 0,
      progress: false,
    },
    resolver: zodResolver(fileDownloadRequestFormSchema),
  });

  const handleFilesChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newFiles = e.target.files ? Array.from(e.target.files) : [];
    const existingNames = new Set(selectedFiles.map((f) => f.name));
    const deduplicated = newFiles.filter((f) => !existingNames.has(f.name));
    const merged = [...selectedFiles, ...deduplicated];
    setSelectedFiles(merged);
    // Build a new DataTransfer to sync with react-hook-form
    const dt = new DataTransfer();
    merged.forEach((f) => dt.items.add(f));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    setValue("file", dt.files as any, { shouldValidate: true });
    // Reset native input so selecting the same file again triggers onChange
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const removeFile = (index: number) => {
    const updated = selectedFiles.filter((_, i) => i !== index);
    setSelectedFiles(updated);
    const dt = new DataTransfer();
    updated.forEach((f) => dt.items.add(f));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    setValue("file", dt.files as any, { shouldValidate: true });
  };

  const onSubmit = handleSubmit((data) => {
    if (selectedFiles.length > 0) {
      onFileSubmit({
        files: selectedFiles,
        archiveName:
          selectedFiles.length > 1 && data.archiveName
            ? data.archiveName
            : undefined,
        destination: data.destination as FileDestination,
        ttlSeconds: data.ttlSeconds,
        progress: data.progress,
      });
      setSelectedFiles([]);
      reset();
    }
  });

  const fileRegisterProps = register("file");

  return (
    <form className={className} onSubmit={onSubmit} autoComplete="off">
      <FormRow
        id="file"
        label={
          <FormattedMessage
            id="components.ManualFileDownloadRequestForm.fileLabel"
            defaultMessage="Files"
          />
        }
      >
        <input
          {...fileRegisterProps}
          ref={fileInputRef}
          type="file"
          multiple
          onChange={handleFilesChange}
          className="d-none"
        />
        <div
          role="button"
          tabIndex={0}
          className={`form-control d-flex flex-wrap align-items-center gap-1${
            errors.file ? " is-invalid" : ""
          }`}
          style={{ cursor: "pointer", minHeight: "38px" }}
          onClick={() => fileInputRef.current?.click()}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              fileInputRef.current?.click();
            }
          }}
        >
          {selectedFiles.length === 0 ? (
            <span className="text-muted">
              <FormattedMessage
                id="components.ManualFileDownloadRequestForm.filePlaceholder"
                defaultMessage="Click to select files..."
              />
            </span>
          ) : (
            selectedFiles.map((file, index) => (
              <Tag
                key={`${file.name}-${index}`}
                className="d-inline-flex align-items-center gap-1 px-2"
              >
                {file.name}
                <CloseButton
                  variant="white"
                  className="ms-1"
                  style={{ fontSize: "0.75em" }}
                  onClick={(e) => {
                    e.stopPropagation();
                    removeFile(index);
                  }}
                />
              </Tag>
            ))
          )}
        </div>
        {errors.file ? (
          <ErrorMessage error={errors.file as FieldError} />
        ) : (
          <Form.Text muted>
            <FormattedMessage
              id="components.ManualFileDownloadRequestForm.fileHint"
              defaultMessage="Select one or more files. Multiple files will be compressed into a tar.gz archive."
            />
          </Form.Text>
        )}
      </FormRow>

      {selectedFiles.length > 1 && (
        <FormRow
          id="archiveName"
          label={
            <FormattedMessage
              id="components.ManualFileDownloadRequestForm.archiveNameLabel"
              defaultMessage="Archive Name"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("archiveName")}
            placeholder="files-archive"
          />
          <Form.Text muted>
            <FormattedMessage
              id="components.ManualFileDownloadRequestForm.archiveNameHint"
              defaultMessage="Optional name for the tar.gz archive. Defaults to 'files-archive' if left empty."
            />
          </Form.Text>
        </FormRow>
      )}

      <FormRow
        id="destination"
        label={
          <FormattedMessage
            id="components.ManualFileDownloadRequestForm.destinationLabel"
            defaultMessage="Destination"
          />
        }
      >
        <Controller
          control={control}
          name={`destination`}
          render={({ field }) => {
            const selectedOption =
              destinationOptions.find((opt) => opt.value === field.value) ||
              null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => {
                  field.onChange(option ? option.value : null);
                }}
                options={destinationOptions}
              />
            );
          }}
        />
      </FormRow>

      <FormRow
        id="ttlSeconds"
        label={
          <FormattedMessage
            id="components.ManualFileDownloadRequestForm.ttlLabel"
            defaultMessage="TTL (seconds)"
          />
        }
      >
        <Form.Control
          type="text"
          {...register(`ttlSeconds`, {
            setValueAs: (v) => (v === "" ? undefined : Number(v)),
          })}
          isInvalid={!!errors.ttlSeconds}
        />

        {errors.ttlSeconds ? (
          <ErrorMessage error={errors.ttlSeconds as FieldError} />
        ) : (
          <Form.Text muted>
            <FormattedMessage
              id="components.ManualFileDownloadRequestForm.ttlHint"
              defaultMessage="Set to 0 for no expiry."
            />
          </Form.Text>
        )}
      </FormRow>

      <FormRow
        id="progress"
        label={
          <FormattedMessage
            id="components.ManualFileDownloadRequestForm.progressLabel"
            defaultMessage="Report Progress"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("progress")}
          isInvalid={!!errors.progress}
        />
        <ErrorMessage error={errors.progress as FieldError} />
      </FormRow>

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.ManualFileDownloadRequestForm.uploadButton"
              defaultMessage="Upload"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export default ManualFileDownloadRequestForm;
export type { FileDownloadRequestFormValues };
