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

import React, { useMemo } from "react";
import { useIntl } from "react-intl";

import Form from "@/components/ui/form/Form";
import Select from "@/components/ui/select/Select";

export type EnvFileSource =
  | { type: "deviceFile"; id: string }
  | { type: "fileDownloadRequest"; id: string }
  | { type: "upload"; file: File | null };

type FileOption = { value: string; label: string };

type Props = {
  value: EnvFileSource;
  onChange: (v: EnvFileSource) => void;
  deviceFileOptions?: FileOption[];
  downloadRequestOptions?: FileOption[];
};

const EnvFileSelector = ({
  value,
  onChange,
  deviceFileOptions = [],
  downloadRequestOptions = [],
}: Props) => {
  const intl = useIntl();

  const selectedDeviceFile = useMemo(
    () =>
      value.type === "deviceFile"
        ? (deviceFileOptions.find((o) => o.value === value.id) ?? null)
        : null,
    [value, deviceFileOptions],
  );

  const selectedDownloadRequest = useMemo(
    () =>
      value.type === "fileDownloadRequest"
        ? (downloadRequestOptions.find((o) => o.value === value.id) ?? null)
        : null,
    [value, downloadRequestOptions],
  );

  type SourceOption = { value: EnvFileSource["type"]; label: string };
  const sourceOptions: SourceOption[] = [
    {
      value: "deviceFile",
      label: intl.formatMessage({
        id: "components.deploy.EnvFileSelector.deviceFile",
        defaultMessage: "Existing file on device",
      }),
    },
    {
      value: "fileDownloadRequest",
      label: intl.formatMessage({
        id: "components.deploy.EnvFileSelector.downloadRequest",
        defaultMessage: "File download request",
      }),
    },
    {
      value: "upload",
      label: intl.formatMessage({
        id: "components.deploy.EnvFileSelector.upload",
        defaultMessage: "Upload new file",
      }),
    },
  ];
  const selectedSource =
    sourceOptions.find((o) => o.value === value.type) ?? null;

  return (
    <div className="d-flex flex-column gap-2">
      <Select<SourceOption>
        value={selectedSource}
        onChange={(opt) => {
          const t = (opt as SourceOption)?.value;
          if (t === "deviceFile") onChange({ type: "deviceFile", id: "" });
          else if (t === "fileDownloadRequest")
            onChange({ type: "fileDownloadRequest", id: "" });
          else if (t === "upload") onChange({ type: "upload", file: null });
        }}
        options={sourceOptions}
        isClearable={false}
        menuPortalTarget={document.body}
        menuPosition="fixed"
        styles={{
          menuPortal: (base: any) => ({ ...base, zIndex: 9999 }) as any,
        }}
        placeholder={intl.formatMessage({
          id: "components.deploy.EnvFileSelector.sourcePlaceholder",
          defaultMessage: "Select source...",
        })}
        aria-label="env-file-source-select"
      />
      {value.type === "deviceFile" && (
        <Select<FileOption>
          value={selectedDeviceFile}
          onChange={(opt) =>
            onChange({
              type: "deviceFile",
              id: opt ? (opt as FileOption).value : "",
            })
          }
          options={deviceFileOptions}
          isClearable
          menuPortalTarget={document.body}
          menuPosition="fixed"
          styles={{
            menuPortal: (base: any) => ({ ...base, zIndex: 9999 }) as any,
          }}
          placeholder={intl.formatMessage({
            id: "components.deploy.EnvFileSelector.deviceFilePlaceholder",
            defaultMessage: "Search or select a file on device...",
          })}
          noOptionsMessage={({ inputValue }) =>
            inputValue
              ? intl.formatMessage(
                  {
                    id: "components.deploy.EnvFileSelector.noDeviceFilesMatching",
                    defaultMessage: 'No files found matching "{inputValue}"',
                  },
                  { inputValue },
                )
              : intl.formatMessage({
                  id: "components.deploy.EnvFileSelector.noDeviceFiles",
                  defaultMessage: "No files on device",
                })
          }
          filterOption={(option, inputValue) =>
            option.label.toLowerCase().includes(inputValue.toLowerCase())
          }
          aria-label="device-file-select"
        />
      )}
      {value.type === "fileDownloadRequest" && (
        <Select<FileOption>
          value={selectedDownloadRequest}
          onChange={(opt) =>
            onChange({
              type: "fileDownloadRequest",
              id: opt ? (opt as FileOption).value : "",
            })
          }
          options={downloadRequestOptions}
          isClearable
          menuPortalTarget={document.body}
          menuPosition="fixed"
          styles={{
            menuPortal: (base: any) => ({ ...base, zIndex: 9999 }) as any,
          }}
          placeholder={intl.formatMessage({
            id: "components.deploy.EnvFileSelector.downloadRequestPlaceholder",
            defaultMessage: "Search or select a download request...",
          })}
          noOptionsMessage={({ inputValue }) =>
            inputValue
              ? intl.formatMessage(
                  {
                    id: "components.deploy.EnvFileSelector.noDownloadRequestsMatching",
                    defaultMessage:
                      'No download requests found matching "{inputValue}"',
                  },
                  { inputValue },
                )
              : intl.formatMessage({
                  id: "components.deploy.EnvFileSelector.noDownloadRequests",
                  defaultMessage: "No download requests",
                })
          }
          filterOption={(option, inputValue) =>
            option.label.toLowerCase().includes(inputValue.toLowerCase())
          }
          aria-label="file-download-request-select"
        />
      )}
      {value.type === "upload" && (
        <Form.Control
          type="file"
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onChange({ type: "upload", file: e.target.files?.[0] ?? null })
          }
          aria-label="env-file-upload"
        />
      )}
      {value.type === "upload" && value.file && (
        <div className="small text-muted">{value.file.name}</div>
      )}
    </div>
  );
};

export default EnvFileSelector;
