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

import { useMemo, useState } from "react";
import { graphql, useFragment } from "react-relay/hooks";
import { FormattedMessage, useIntl } from "react-intl";
import Select from "react-select";

import type { FileManagementTab_fileManagement$key } from "@/api/__generated__/FileManagementTab_fileManagement.graphql";

import FilesDownloadTab from "@/components/DeviceTabs/FilesDownloadTab";
import FilesUploadTab from "@/components/DeviceTabs/FilesUploadTab";
import Form from "@/components/Form";
import { Tab } from "@/components/Tabs";

type FileManagementTabProps = {
  deviceRef: FileManagementTab_fileManagement$key;
};

type FileManagementMode =
  | "to-device-file"
  | "to-device-repository"
  | "from-device";

type FileManagementModeOption = {
  value: FileManagementMode;
  label: string;
};

const FILE_MANAGEMENT_FRAGMENT = graphql`
  fragment FileManagementTab_fileManagement on Device {
    capabilities
    fileTransferCapabilities {
      encodings
      unixPermissions
      targets
    }
    ...FilesUploadTab_fileDownloadRequests
    ...FilesDownloadTab_fileUploadRequests
  }
`;

const FileManagementTab = ({ deviceRef }: FileManagementTabProps) => {
  const intl = useIntl();
  const data = useFragment(FILE_MANAGEMENT_FRAGMENT, deviceRef);

  const supportsServerToDevice =
    data.capabilities.includes("FILE_TRANSFER_STORAGE") ||
    data.capabilities.includes("FILE_TRANSFER_STREAM");

  const supportsDeviceToServer =
    data.capabilities.includes("FILE_TRANSFER_READ");

  const modeOptions = useMemo<Array<FileManagementModeOption>>(() => {
    const options: Array<FileManagementModeOption> = [];

    if (supportsServerToDevice) {
      options.push(
        {
          value: "to-device-file",
          label: intl.formatMessage({
            id: "components.DeviceTabs.FileManagementTab.toDeviceDirect",
            defaultMessage: "To Device - Direct File",
          }),
        },
        {
          value: "to-device-repository",
          label: intl.formatMessage({
            id: "components.DeviceTabs.FileManagementTab.toDeviceRepository",
            defaultMessage: "To Device - Repository",
          }),
        },
      );
    }

    if (supportsDeviceToServer) {
      options.push({
        value: "from-device",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FileManagementTab.fromDevice",
          defaultMessage: "From Device",
        }),
      });
    }

    return options;
  }, [intl, supportsDeviceToServer, supportsServerToDevice]);

  const [selectedMode, setSelectedMode] =
    useState<FileManagementMode>("to-device-file");

  const fallbackMode = modeOptions[0]?.value ?? "to-device-file";

  const effectiveMode = modeOptions.some((m) => m.value === selectedMode)
    ? selectedMode
    : fallbackMode;

  const selectedModeOption =
    modeOptions.find((option) => option.value === effectiveMode) ?? null;

  const hasTransferTargets =
    (data.fileTransferCapabilities?.targets?.length ?? 0) > 0;

  if (modeOptions.length === 0 || !hasTransferTargets) {
    return null;
  }

  return (
    <Tab eventKey="device-file-management-tab" title="File Management">
      {modeOptions.length > 1 && (
        <div className="mt-3">
          <Form.Group controlId="file-management-mode" className="mb-0">
            <h5>
              <FormattedMessage
                id="components.DeviceTabs.FileManagementTab.fileManagementLabel"
                defaultMessage="File Management Mode"
              />
            </h5>
            <Select<FileManagementModeOption, false>
              value={selectedModeOption}
              onChange={(option) => {
                setSelectedMode(option?.value ?? fallbackMode);
              }}
              options={modeOptions}
              isSearchable={false}
              styles={{
                container: (base) => ({
                  ...base,
                  maxWidth: "20rem",
                  minWidth: "16rem",
                }),
              }}
            />
          </Form.Group>
        </div>
      )}

      {effectiveMode === "from-device" ? (
        <FilesDownloadTab deviceRef={data} embedded />
      ) : effectiveMode === "to-device-repository" ? (
        <FilesUploadTab deviceRef={data} embedded embeddedMode="repository" />
      ) : (
        <FilesUploadTab deviceRef={data} embedded embeddedMode="file" />
      )}
    </Tab>
  );
};

export default FileManagementTab;
