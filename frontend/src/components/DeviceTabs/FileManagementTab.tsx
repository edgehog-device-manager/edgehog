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
import { FormattedMessage, useIntl } from "react-intl";
import { useParams } from "react-router-dom";
import {
  ConnectionHandler,
  graphql,
  useFragment,
  useSubscription,
} from "react-relay/hooks";
import Select from "react-select";
import { Card } from "react-bootstrap";

import type { FileManagementTab_fileManagement$key } from "@/api/__generated__/FileManagementTab_fileManagement.graphql";
import type { FileManagementTab_DeviceFilesSubscription } from "@/api/__generated__/FileManagementTab_DeviceFilesSubscription.graphql";

import FilesDeleteTab from "@/components/DeviceTabs/FilesDeleteTab";
import FilesDownloadTab from "@/components/DeviceTabs/FilesDeviceToServerTab";
import FilesServerToDeviceTab from "@/components/DeviceTabs/FilesServerToDeviceTab";
import Form from "@/components/Form";
import { Tab } from "@/components/Tabs";

type FileManagementMode =
  | "download-to-device-file"
  | "download-to-device-repository"
  | "upload-from-device"
  | "delete-from-device";

type FileManagementModeOption = {
  value: FileManagementMode;
  label: string;
};

const FILE_MANAGEMENT_FRAGMENT = graphql`
  fragment FileManagementTab_fileManagement on Device
  @argumentDefinitions(
    storageFirst: { type: "Int" }
    storageAfter: { type: "String" }
  ) {
    online
    capabilities
    fileTransferCapabilities {
      unixPermissions
      serverToDevice {
        storage
        streaming
        filesystem
      }
      deviceToServer {
        storage
        streaming
        filesystem
      }
    }
    ...FilesServerToDeviceTab_fileDownloadRequests
    ...FilesDeviceToServerTab_fileUploadRequests
    ...FilesDeviceToServerTab_deviceFiles
      @arguments(first: $storageFirst, after: $storageAfter)
    ...FilesDeleteTab_fileManagement
    ...FilesDeleteTab_deviceFiles
      @arguments(first: $storageFirst, after: $storageAfter)
  }
`;

const DEVICE_FILES_SUBSCRIPTION = graphql`
  subscription FileManagementTab_DeviceFilesSubscription($deviceId: ID!) {
    deviceFilesByDevice(deviceId: $deviceId) {
      created {
        id
        fileId
        pathOnDevice
        fileDownloadRequest {
          id
          fileName
        }
      }
      updated {
        id
        fileId
        deleted
        pathOnDevice
        fileDownloadRequest {
          id
          fileName
        }
      }
    }
  }
`;

type FileManagementTabProps = {
  deviceRef: FileManagementTab_fileManagement$key;
};

const FileManagementTab = ({ deviceRef }: FileManagementTabProps) => {
  const intl = useIntl();
  const { deviceId = "" } = useParams();
  const data = useFragment(FILE_MANAGEMENT_FRAGMENT, deviceRef);

  const isOnline = useMemo(() => data?.online ?? false, [data]);

  const [selectedMode, setSelectedMode] = useState<FileManagementMode>(
    "download-to-device-file",
  );

  useSubscription<FileManagementTab_DeviceFilesSubscription>(
    useMemo(
      () => ({
        subscription: DEVICE_FILES_SUBSCRIPTION,
        variables: { deviceId },
        updater: (store) => {
          const deviceRecord = store.get(deviceId);
          if (!deviceRecord) return;

          const payload = store.getRootField("deviceFilesByDevice");
          if (!payload) return;

          const connectionKeys = [
            "FilesDeleteTab_deviceFiles",
            "FilesDeviceToServerTab_deviceFiles",
          ];

          const createdFile = payload.getLinkedRecord("created");
          if (createdFile) {
            connectionKeys.forEach((key) => {
              const connection = ConnectionHandler.getConnection(
                deviceRecord,
                key,
                { filter: { deleted: { eq: false } } },
              );
              if (connection) {
                const edges = connection.getLinkedRecords("edges") ?? [];
                const exists = edges.some(
                  (edge) =>
                    edge?.getLinkedRecord("node")?.getDataID() ===
                    createdFile.getDataID(),
                );

                if (!exists) {
                  const edge = ConnectionHandler.createEdge(
                    store,
                    connection,
                    createdFile,
                    "DeviceFileEdge",
                  );
                  ConnectionHandler.insertEdgeBefore(connection, edge);
                }
              }
            });
          }

          const updatedFile = payload.getLinkedRecord("updated");

          if (updatedFile) {
            const isDeleted = updatedFile.getValue("deleted");

            if (isDeleted) {
              const destroyedId = updatedFile.getDataID();

              connectionKeys.forEach((key) => {
                const connection = ConnectionHandler.getConnection(
                  deviceRecord,
                  key,
                  { filter: { deleted: { eq: false } } },
                );

                if (connection) {
                  ConnectionHandler.deleteNode(connection, destroyedId);
                }
              });
            }
          }
        },
      }),
      [deviceId],
    ),
  );
  const supportsServerToDevice = Object.values(
    data.fileTransferCapabilities?.serverToDevice ?? {},
  ).some(Boolean);

  const supportsDeviceToServer = Object.values(
    data.fileTransferCapabilities?.deviceToServer ?? {},
  ).some(Boolean);

  const supportsDeleteFromDevice = data.capabilities.includes(
    "FILE_TRANSFER_DELETE",
  );

  const modeOptions = useMemo<Array<FileManagementModeOption>>(() => {
    const options: Array<FileManagementModeOption> = [];

    if (supportsServerToDevice) {
      options.push(
        {
          value: "download-to-device-file",
          label: intl.formatMessage({
            id: "components.DeviceTabs.FileManagementTab.toDeviceDirect",
            defaultMessage: "Download to Device - Direct File",
          }),
        },
        {
          value: "download-to-device-repository",
          label: intl.formatMessage({
            id: "components.DeviceTabs.FileManagementTab.toDeviceRepository",
            defaultMessage: "Download to Device - Repository",
          }),
        },
      );
    }

    if (supportsDeviceToServer) {
      options.push({
        value: "upload-from-device",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FileManagementTab.uploadFromDevice",
          defaultMessage: "Upload from Device",
        }),
      });
    }

    if (supportsDeleteFromDevice) {
      options.push({
        value: "delete-from-device",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FileManagementTab.deleteFromDevice",
          defaultMessage: "Delete from Device",
        }),
      });
    }

    return options;
  }, [
    intl,
    supportsDeviceToServer,
    supportsServerToDevice,
    supportsDeleteFromDevice,
  ]);

  if (modeOptions.length === 0) {
    return null;
  }

  const isSelectedModeValid = modeOptions.some((m) => m.value === selectedMode);
  const effectiveMode = isSelectedModeValid
    ? selectedMode
    : modeOptions[0].value;
  const selectedModeOption = modeOptions.find(
    (option) => option.value === effectiveMode,
  );

  const renderTabContent = () => {
    switch (effectiveMode) {
      case "download-to-device-file":
        return (
          <FilesServerToDeviceTab
            deviceRef={data}
            embedded
            embeddedMode="file"
            isOnline={isOnline}
          />
        );
      case "download-to-device-repository":
        return (
          <FilesServerToDeviceTab
            deviceRef={data}
            embedded
            embeddedMode="repository"
            isOnline={isOnline}
          />
        );
      case "upload-from-device":
        return (
          <FilesDownloadTab deviceRef={data} embedded isOnline={isOnline} />
        );
      case "delete-from-device":
        return <FilesDeleteTab deviceRef={data} embedded isOnline={isOnline} />;
      default:
        return null;
    }
  };

  return (
    <Tab
      className="pt-3 d-flex flex-column flex-grow-1"
      eventKey="device-file-management-tab"
      title="File Management"
    >
      {modeOptions.length > 1 && (
        <Card className="h-100 border-0 p-3 shadow-sm mb-3">
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
                if (option) setSelectedMode(option.value);
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
        </Card>
      )}

      {renderTabContent()}
    </Tab>
  );
};

export default FileManagementTab;
