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
import { useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import Select from "react-select";

import Button from "@/components/Button";
import Col from "@/components/Col";
import CollapseItem, { useCollapseToggle } from "@/components/CollapseItem";
import type { DestinationTypeOption } from "@/components/DeviceTabs/FilesUploadTab";
import FileDropzone from "@/components/FileDropzone";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import FormFeedback from "@/forms/FormFeedback";
import {
  fileDownloadRequestFormSchema,
  type FileDestinationType,
} from "@/forms/validation";

type FileDownloadRequestFormValues = {
  files: File[];
  archiveName?: string;
  destinationType: FileDestinationType;
  destination: string | null;
  ttlSeconds: number;
  progressTracked: boolean;
  fileMode?: number;
  userId?: number;
  groupId?: number;
};

type ManualFileDownloadRequestFormProps = {
  className?: string;
  isLoading: boolean;
  onFileSubmit: (values: FileDownloadRequestFormValues) => void;
  showAdvancedOptions?: boolean;
  destinationTypeOptions: DestinationTypeOption[];
};

const ManualFileDownloadRequestForm = ({
  className,
  isLoading,
  onFileSubmit,
  showAdvancedOptions = false,
  destinationTypeOptions,
}: ManualFileDownloadRequestFormProps) => {
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const { open: advancedOptionsOpen, toggle: toggleAdvancedOptions } =
    useCollapseToggle();

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
      destinationType: "STORAGE",
      destination: null,
      ttlSeconds: 0,
      progress: false,
      fileMode: undefined,
      userId: undefined,
      groupId: undefined,
    },
    resolver: zodResolver(fileDownloadRequestFormSchema),
  });

  const selectedDestinationType = useWatch({
    control,
    name: "destinationType",
  });

  const handleFilesChanged = (files: File[]) => {
    setSelectedFiles(files);
    const dt = new DataTransfer();
    files.forEach((f) => dt.items.add(f));
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
        destinationType: data.destinationType,
        destination: data.destination,
        ttlSeconds: data.ttlSeconds,
        progressTracked: data.progress,
        fileMode: data.fileMode,
        userId: data.userId,
        groupId: data.groupId,
      });
      setSelectedFiles([]);
      reset();
    }
  });

  const hasRelativePaths = selectedFiles.some((f) => f.webkitRelativePath);
  const showArchiveName = selectedFiles.length > 1 || hasRelativePaths;

  return (
    <form className={className} onSubmit={onSubmit} autoComplete="off">
      <FormRow
        id="file"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestForm.fileLabel"
            defaultMessage="Files"
          />
        }
      >
        <FileDropzone
          files={selectedFiles}
          onChange={handleFilesChanged}
          isInvalid={!!errors.file}
        />
        {errors.file ? (
          <FormFeedback feedback={errors.file.message} />
        ) : (
          <Form.Text muted>
            <FormattedMessage
              id="forms.ManualFileDownloadRequestForm.fileHint"
              defaultMessage="Select files or a folder. Multiple items will be compressed into a tar.gz archive."
            />
          </Form.Text>
        )}
      </FormRow>

      {showArchiveName && (
        <FormRow
          id="archiveName"
          label={
            <FormattedMessage
              id="forms.ManualFileDownloadRequestForm.archiveNameLabel"
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
              id="forms.ManualFileDownloadRequestForm.archiveNameHint"
              defaultMessage="Optional name for the tar.gz archive. Defaults to 'files-archive' if left empty."
            />
          </Form.Text>
        </FormRow>
      )}

      <FormRow
        id="destinationType"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestForm.destinationLabel"
            defaultMessage="Destination"
          />
        }
      >
        <Controller
          control={control}
          name={`destinationType`}
          render={({ field }) => {
            const selectedOption =
              destinationTypeOptions.find((opt) => opt.value === field.value) ||
              null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => {
                  field.onChange(option ? option.value : null);
                }}
                options={destinationTypeOptions}
              />
            );
          }}
        />
      </FormRow>

      {selectedDestinationType === "FILESYSTEM" && (
        <FormRow
          id="destination"
          label={
            <FormattedMessage
              id="forms.ManualFileDownloadRequestForm.destinationPathLabel"
              defaultMessage="Destination Path"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("destination")}
            placeholder="/tmp/file.bin"
            isInvalid={!!errors.destination}
          />

          {errors.destination ? (
            <FormFeedback feedback={errors.destination.message} />
          ) : (
            <Form.Text muted>
              <FormattedMessage
                id="forms.ManualFileDownloadRequestForm.destinationPathHint"
                defaultMessage="Absolute path on the target device where the file should be written."
              />
            </Form.Text>
          )}
        </FormRow>
      )}

      <FormRow
        id="ttlSeconds"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestForm.ttlLabel"
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
          <FormFeedback feedback={errors.ttlSeconds.message} />
        ) : (
          <Form.Text muted>
            <FormattedMessage
              id="forms.ManualFileDownloadRequestForm.ttlHint"
              defaultMessage="Set to 0 for no expiry."
            />
          </Form.Text>
        )}
      </FormRow>

      <FormRow
        id="progress"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestForm.progressLabel"
            defaultMessage="Report Progress"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("progress")}
          isInvalid={!!errors.progress}
        />
        <FormFeedback feedback={errors.progress?.message} />
      </FormRow>

      {showAdvancedOptions && (
        <div className="mb-3">
          <CollapseItem
            type="flat"
            open={advancedOptionsOpen}
            onToggle={toggleAdvancedOptions}
            isInsideTable={true}
            title={
              <FormattedMessage
                id="forms.ManualFileDownloadRequestForm.advancedOptionsTitle"
                defaultMessage="Advanced Options"
              />
            }
          >
            <FormRow
              id="userId"
              label={
                <FormattedMessage
                  id="forms.ManualFileDownloadRequestForm.userIdLabel"
                  defaultMessage="User ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`userId` as const, {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.userId}
              />
              <FormFeedback feedback={errors.userId?.message} />
            </FormRow>

            <FormRow
              id="groupId"
              label={
                <FormattedMessage
                  id="forms.ManualFileDownloadRequestForm.groupIdLabel"
                  defaultMessage="Group ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`groupId` as const, {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.groupId}
              />
              <FormFeedback feedback={errors.groupId?.message} />
            </FormRow>

            <FormRow
              id="fileMode"
              label={
                <FormattedMessage
                  id="forms.ManualFileDownloadRequestForm.fileModeLabel"
                  defaultMessage="File Mode"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`fileMode` as const, {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.fileMode}
              />
              <FormFeedback feedback={errors.fileMode?.message} />
            </FormRow>
          </CollapseItem>
        </div>
      )}

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.ManualFileDownloadRequestForm.uploadButton"
              defaultMessage="Upload"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export type { FileDownloadRequestFormValues };

export default ManualFileDownloadRequestForm;
