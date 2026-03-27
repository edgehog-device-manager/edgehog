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
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { CreateFile_RepositoryFragment$key } from "@/api/__generated__/CreateFile_RepositoryFragment.graphql";

import Button from "@/components/Button";
import FileDropzone from "@/components/FileDropzone";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import FormFeedback from "@/forms/FormFeedback";
import { FileFormData, fileSchema } from "@/forms/validation";

const CREATE_FILE_FRAGMENT = graphql`
  fragment CreateFile_RepositoryFragment on Repository {
    id
    name
  }
`;

type FileFormOutputData = {
  files: File[];
  archiveName?: string;
  repositoryId: string;
};

type CreateFileFormProps = {
  repositoryRef: CreateFile_RepositoryFragment$key;
  isLoading?: boolean;
  onSubmit: (data: FileFormOutputData) => void;
};

const CreateFileForm = ({
  repositoryRef,
  isLoading = false,
  onSubmit,
}: CreateFileFormProps) => {
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);

  const repositoryData = useFragment(CREATE_FILE_FRAGMENT, repositoryRef);

  const {
    handleSubmit,
    register,
    setValue,
    formState: { errors },
  } = useForm<FileFormData>({
    mode: "onTouched",
    defaultValues: {
      file: undefined,
      archiveName: "",
      repository: repositoryData.name,
    },
    resolver: zodResolver(fileSchema),
  });

  const handleFilesChanged = (files: File[]) => {
    setSelectedFiles(files);
    const dt = new DataTransfer();
    files.forEach((f) => dt.items.add(f));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    setValue("file", dt.files as any, { shouldValidate: true });
  };

  const onFormSubmit = (data: FileFormData) => {
    if (data.file instanceof FileList && data.file[0]) {
      const formOutputData = {
        repositoryId: repositoryData.id,
        files: selectedFiles,
        archiveName:
          selectedFiles.length > 1 && data.archiveName
            ? data.archiveName
            : undefined,
      };
      onSubmit(formOutputData);
    }
  };

  const hasRelativePaths = selectedFiles.some((f) => f.webkitRelativePath);
  const showArchiveName = selectedFiles.length > 1 || hasRelativePaths;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="create-file-form-repository"
          label={
            <FormattedMessage
              id="forms.CreateFile.repositoryLabel"
              defaultMessage="Repository"
            />
          }
        >
          <Form.Control {...register("repository")} plaintext readOnly />
        </FormRow>

        <FormRow
          id="file"
          label={
            <FormattedMessage
              id="forms.CreateFile.fileLabel"
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
                id="forms.CreateFile.fileHint"
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
                id="forms.CreateFile.archiveNameLabel"
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
                id="forms.CreateFile.archiveNameHint"
                defaultMessage="Optional name for the tar.gz archive. Defaults to 'files-archive' if left empty."
              />
            </Form.Text>
          </FormRow>
        )}

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateFile.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { FileFormOutputData };
export default CreateFileForm;
