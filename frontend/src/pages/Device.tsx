/*
  This file is part of Edgehog.

  Copyright 2021-2022 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import React, { Suspense, useEffect, useState, useMemo } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useFragment,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
  useMutation,
} from "react-relay/hooks";
import { FormattedDate, FormattedMessage, useIntl } from "react-intl";
import dayjs from "dayjs";

import type { Device_batteryStatus$key } from "api/__generated__/Device_batteryStatus.graphql";
import type { Device_hardwareInfo$key } from "api/__generated__/Device_hardwareInfo.graphql";
import type { Device_location$key } from "api/__generated__/Device_location.graphql";
import type { Device_baseImage$key } from "api/__generated__/Device_baseImage.graphql";
import type { Device_osInfo$key } from "api/__generated__/Device_osInfo.graphql";
import type { Device_runtimeInfo$key } from "api/__generated__/Device_runtimeInfo.graphql";
import type { Device_storageUsage$key } from "api/__generated__/Device_storageUsage.graphql";
import type { Device_systemStatus$key } from "api/__generated__/Device_systemStatus.graphql";
import type { Device_wifiScanResults$key } from "api/__generated__/Device_wifiScanResults.graphql";
import type { Device_otaOperations$key } from "api/__generated__/Device_otaOperations.graphql";
import type {
  Device_getDevice_Query,
  Device_getDevice_QueryResponse,
} from "api/__generated__/Device_getDevice_Query.graphql";
import type { Device_createManualOtaOperation_Mutation } from "api/__generated__/Device_createManualOtaOperation_Mutation.graphql";
import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import CellularConnectionTabs from "components/CellularConnectionTabs";
import Center from "components/Center";
import ConnectionStatus from "components/ConnectionStatus";
import Col from "components/Col";
import Figure from "components/Figure";
import Form from "components/Form";
import LastSeen from "components/LastSeen";
import Map from "components/Map";
import OperationTable from "components/OperationTable";
import Page from "components/Page";
import Result from "components/Result";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import StorageTable from "components/StorageTable";
import Tabs, { Tab } from "components/Tabs";
import WiFiScanResultsTable from "components/WiFiScanResultsTable";
import BatteryTable from "components/BatteryTable";
import BaseImageForm from "forms/BaseImageForm";

const DEVICE_HARDWARE_INFO_FRAGMENT = graphql`
  fragment Device_hardwareInfo on Device {
    hardwareInfo {
      cpuArchitecture
      cpuModel
      cpuModelName
      cpuVendor
      memoryTotalBytes
    }
  }
`;

const DEVICE_BASE_IMAGE_FRAGMENT = graphql`
  fragment Device_baseImage on Device {
    baseImage {
      name
      version
      buildId
      fingerprint
    }
  }
`;

const DEVICE_OS_INFO_FRAGMENT = graphql`
  fragment Device_osInfo on Device {
    osInfo {
      name
      version
    }
  }
`;

const DEVICE_LOCATION_FRAGMENT = graphql`
  fragment Device_location on Device {
    location {
      latitude
      longitude
      accuracy
      address
      timestamp
    }
  }
`;

const DEVICE_STORAGE_USAGE_FRAGMENT = graphql`
  fragment Device_storageUsage on Device {
    storageUsage {
      label
      totalBytes
      freeBytes
    }
  }
`;

const DEVICE_SYSTEM_STATUS_FRAGMENT = graphql`
  fragment Device_systemStatus on Device {
    systemStatus {
      memoryFreeBytes
      taskCount
      uptimeMilliseconds
      timestamp
    }
  }
`;

const DEVICE_WIFI_SCAN_RESULTS_FRAGMENT = graphql`
  fragment Device_wifiScanResults on Device {
    wifiScanResults {
      channel
      essid
      macAddress
      rssi
      timestamp
    }
  }
`;

const DEVICE_BATTERY_STATUS_FRAGMENT = graphql`
  fragment Device_batteryStatus on Device {
    batteryStatus {
      slot
      status
      levelPercentage
      levelAbsoluteError
    }
  }
`;

const DEVICE_OTA_OPERATIONS_FRAGMENT = graphql`
  fragment Device_otaOperations on Device {
    id
    otaOperations {
      id
      baseImageUrl
      status
    }

    ...OperationTable_otaOperations
  }
`;

const DEVICE_RUNTIME_INFO_FRAGMENT = graphql`
  fragment Device_runtimeInfo on Device {
    runtimeInfo {
      name
      version
      environment
      url
    }
  }
`;

const GET_DEVICE_QUERY = graphql`
  query Device_getDevice_Query($id: ID!) {
    device(id: $id) {
      id
      deviceId
      lastConnection
      lastDisconnection
      name
      online
      systemModel {
        name
        pictureUrl
        hardwareType {
          name
        }
      }
      cellularConnection {
        __typename
      }
      ...Device_hardwareInfo
      ...Device_baseImage
      ...Device_osInfo
      ...Device_runtimeInfo
      ...Device_location
      ...Device_storageUsage
      ...Device_systemStatus
      ...Device_wifiScanResults
      ...Device_batteryStatus
      ...Device_otaOperations
      ...CellularConnectionTabs_cellularConnection
    }
  }
`;

const DEVICE_CREATE_MANUAL_OTA_OPERATION_MUTATION = graphql`
  mutation Device_createManualOtaOperation_Mutation(
    $input: CreateManualOtaOperationInput!
  ) {
    createManualOtaOperation(input: $input) {
      otaOperation {
        id
        baseImageUrl
        createdAt
        status
        statusCode
        updatedAt
      }
    }
  }
`;

const FormRow: (params: {
  id: string;
  label: JSX.Element;
  children: JSX.Element;
}) => JSX.Element = ({ id, label, children }) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={4}>
      {label}
    </Form.Label>
    <Col sm={8}>{children}</Col>
  </Form.Group>
);

const FormValue = (params: { children: React.ReactNode }) => {
  return <div className="h-100 py-2">{params.children}</div>;
};

const formatBytes = (bytes: number, decimals = 2) => {
  if (bytes === 0) return "0 B";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
};

interface DeviceHardwareInfoTabProps {
  deviceRef: Device_hardwareInfo$key;
}

const DeviceHardwareInfoTab = ({ deviceRef }: DeviceHardwareInfoTabProps) => {
  const intl = useIntl();
  const { hardwareInfo } = useFragment(
    DEVICE_HARDWARE_INFO_FRAGMENT,
    deviceRef
  );
  if (!hardwareInfo) {
    return null;
  }
  return (
    <Tab
      eventKey="device-hardware-info-tab"
      title={intl.formatMessage({
        id: "pages.Device.hardwareInfoTab",
        defaultMessage: "Hardware Info",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {hardwareInfo.cpuArchitecture != null && (
            <FormRow
              id="device-hardware-info-cpu-architecture"
              label={
                <FormattedMessage
                  id="Device.hardwareInfo.cpuArchitecture"
                  defaultMessage="CPU architecture"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuArchitecture}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.cpuModel != null && (
            <FormRow
              id="device-hardware-info-cpu-model"
              label={
                <FormattedMessage
                  id="Device.hardwareInfo.cpuModel"
                  defaultMessage="CPU model code"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuModel}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.cpuModelName != null && (
            <FormRow
              id="device-hardware-info-cpu-model-name"
              label={
                <FormattedMessage
                  id="Device.hardwareInfo.cpuModelName"
                  defaultMessage="CPU model name"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuModelName}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.cpuVendor != null && (
            <FormRow
              id="device-hardware-info-cpu-vendor"
              label={
                <FormattedMessage
                  id="Device.hardwareInfo.cpuVendor"
                  defaultMessage="CPU vendor"
                />
              }
            >
              <Form.Control
                type="text"
                value={hardwareInfo.cpuVendor}
                readOnly
              />
            </FormRow>
          )}
          {hardwareInfo.memoryTotalBytes != null && (
            <FormRow
              id="device-hardware-info-memory-total-bytes"
              label={
                <FormattedMessage
                  id="Device.hardwareInfo.memoryTotalBytes"
                  defaultMessage="Total memory"
                />
              }
            >
              <Form.Control
                type="text"
                value={formatBytes(hardwareInfo.memoryTotalBytes)}
                readOnly
              />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

interface DeviceBaseImageTabProps {
  deviceRef: Device_baseImage$key;
}

const DeviceBaseImageTab = ({ deviceRef }: DeviceBaseImageTabProps) => {
  const intl = useIntl();
  const { baseImage } = useFragment(DEVICE_BASE_IMAGE_FRAGMENT, deviceRef);
  if (!baseImage || Object.values(baseImage).every((value) => value === null)) {
    return null;
  }
  return (
    <Tab
      eventKey="device-base-image-tab"
      title={intl.formatMessage({
        id: "pages.Device.baseImageTab",
        defaultMessage: "Base Image",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {baseImage.name !== null && (
            <FormRow
              id="device-base-image-name"
              label={
                <FormattedMessage
                  id="Device.baseImage.name"
                  defaultMessage="Name"
                />
              }
            >
              <Form.Control type="text" value={baseImage.name} readOnly />
            </FormRow>
          )}
          {baseImage.version !== null && (
            <FormRow
              id="device-base-image-version"
              label={
                <FormattedMessage
                  id="Device.baseImage.version"
                  defaultMessage="Version"
                />
              }
            >
              <Form.Control type="text" value={baseImage.version} readOnly />
            </FormRow>
          )}
          {baseImage.buildId !== null && (
            <FormRow
              id="device-base-image-buildId"
              label={
                <FormattedMessage
                  id="Device.baseImage.buildId"
                  defaultMessage="Build identifier"
                />
              }
            >
              <Form.Control type="text" value={baseImage.buildId} readOnly />
            </FormRow>
          )}
          {baseImage.fingerprint !== null && (
            <FormRow
              id="device-base-image-fingerprint"
              label={
                <FormattedMessage
                  id="Device.baseImage.fingerprint"
                  defaultMessage="Fingerprint"
                />
              }
            >
              <Form.Control
                type="text"
                value={baseImage.fingerprint}
                readOnly
              />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

interface DeviceOSInfoTabProps {
  deviceRef: Device_osInfo$key;
}

const DeviceOSInfoTab = ({ deviceRef }: DeviceOSInfoTabProps) => {
  const intl = useIntl();
  const { osInfo } = useFragment(DEVICE_OS_INFO_FRAGMENT, deviceRef);
  if (!osInfo || Object.values(osInfo).every((value) => value === null)) {
    return null;
  }
  return (
    <Tab
      eventKey="device-os-info-tab"
      title={intl.formatMessage({
        id: "pages.Device.osInfoTab",
        defaultMessage: "Operating System",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {osInfo.name !== null && (
            <FormRow
              id="device-os-info-name"
              label={
                <FormattedMessage
                  id="Device.osInfo.name"
                  defaultMessage="OS name"
                />
              }
            >
              <Form.Control type="text" value={osInfo.name} readOnly />
            </FormRow>
          )}
          {osInfo.version !== null && (
            <FormRow
              id="device-os-info-version"
              label={
                <FormattedMessage
                  id="Device.osInfo.version"
                  defaultMessage="OS version"
                />
              }
            >
              <Form.Control type="text" value={osInfo.version} readOnly />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

interface DeviceRuntimeInfoTabProps {
  deviceRef: Device_runtimeInfo$key;
}

const DeviceRuntimeInfoTab = ({ deviceRef }: DeviceRuntimeInfoTabProps) => {
  const intl = useIntl();
  const { runtimeInfo } = useFragment(DEVICE_RUNTIME_INFO_FRAGMENT, deviceRef);
  if (
    !runtimeInfo ||
    Object.values(runtimeInfo).every((value) => value === null)
  ) {
    return null;
  }
  return (
    <Tab
      eventKey="device-runtime-info-tab"
      title={intl.formatMessage({
        id: "pages.Device.runtimeInfoTab",
        defaultMessage: "Runtime",
      })}
    >
      <div className="mt-3">
        <Stack gap={3}>
          {runtimeInfo.name !== null && (
            <FormRow
              id="device-runtime-info-name"
              label={
                <FormattedMessage
                  id="Device.runtimeInfo.name"
                  defaultMessage="Name"
                />
              }
            >
              <Form.Control type="text" value={runtimeInfo.name} readOnly />
            </FormRow>
          )}
          {runtimeInfo.version !== null && (
            <FormRow
              id="device-runtime-info-version"
              label={
                <FormattedMessage
                  id="Device.runtimeInfo.version"
                  defaultMessage="Version"
                />
              }
            >
              <Form.Control type="text" value={runtimeInfo.version} readOnly />
            </FormRow>
          )}
          {runtimeInfo.environment !== null && (
            <FormRow
              id="device-runtime-info-environment"
              label={
                <FormattedMessage
                  id="Device.runtimeInfo.environment"
                  defaultMessage="Environment"
                />
              }
            >
              <Form.Control
                type="text"
                value={runtimeInfo.environment}
                readOnly
              />
            </FormRow>
          )}
          {runtimeInfo.url !== null && (
            <FormRow
              id="device-runtime-info-url"
              label={
                <FormattedMessage
                  id="Device.runtimeInfo.url"
                  defaultMessage="URL"
                />
              }
            >
              <Form.Control type="text" value={runtimeInfo.url} readOnly />
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

interface DeviceStorageUsageTabProps {
  deviceRef: Device_storageUsage$key;
}

const DeviceStorageUsageTab = ({ deviceRef }: DeviceStorageUsageTabProps) => {
  const intl = useIntl();
  const { storageUsage } = useFragment(
    DEVICE_STORAGE_USAGE_FRAGMENT,
    deviceRef
  );
  if (!storageUsage) {
    return null;
  }
  const storageUnits = storageUsage.map((storageUnit) => ({ ...storageUnit }));
  return (
    <Tab
      eventKey="device-storage-usage-tab"
      title={intl.formatMessage({
        id: "pages.Device.storageTab",
        defaultMessage: "Storage",
      })}
    >
      <div className="mt-3">
        {storageUnits.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.Device.storageTab.noStorage.title"
                defaultMessage="No storage"
              />
            }
          >
            <FormattedMessage
              id="pages.Device.storageTab.noResults.message"
              defaultMessage="The device has not detected any storage unit yet."
            />
          </Result.EmptyList>
        ) : (
          <StorageTable data={storageUnits} />
        )}
      </div>
    </Tab>
  );
};

interface DeviceLocationTabProps {
  deviceRef: Device_location$key;
}

const DeviceLocationTab = ({ deviceRef }: DeviceLocationTabProps) => {
  const intl = useIntl();
  const { location } = useFragment(DEVICE_LOCATION_FRAGMENT, deviceRef);
  if (!location) {
    return null;
  }
  return (
    <Tab
      eventKey="device-location-tab"
      title={intl.formatMessage({
        id: "pages.Device.geolocationTab",
        defaultMessage: "Geolocation",
      })}
    >
      <div className="mt-3">
        <p>
          <FormattedMessage
            id="pages.Device.location.lastUpdateAt"
            defaultMessage="Last known location, updated at {date}"
            values={{
              date: (
                <FormattedDate
                  value={new Date(location.timestamp)}
                  year="numeric"
                  month="long"
                  day="numeric"
                  hour="numeric"
                  minute="numeric"
                />
              ),
            }}
          />
        </p>
        <Map
          latitude={location.latitude}
          longitude={location.longitude}
          popup={
            <div>
              <p>{location.address}</p>
              <p>
                {location.latitude}, {location.longitude}
              </p>
            </div>
          }
        />
      </div>
    </Tab>
  );
};

interface DeviceSystemStatusTabProps {
  deviceRef: Device_systemStatus$key;
}

const DeviceSystemStatusTab = ({ deviceRef }: DeviceSystemStatusTabProps) => {
  const intl = useIntl();
  const { systemStatus } = useFragment(
    DEVICE_SYSTEM_STATUS_FRAGMENT,
    deviceRef
  );
  if (!systemStatus) {
    return null;
  }
  return (
    <Tab
      eventKey="device-system-status-tab"
      title={intl.formatMessage({
        id: "pages.Device.systemStatusTab",
        defaultMessage: "System Status",
      })}
    >
      <div className="mt-3">
        <p className="text-muted">
          <FormattedMessage
            id="pages.Device.systemStatus.lastUpdateAt"
            defaultMessage="Last updated at {date}"
            values={{
              date: (
                <FormattedDate
                  value={new Date(systemStatus.timestamp)}
                  year="numeric"
                  month="long"
                  day="numeric"
                  hour="numeric"
                  minute="numeric"
                />
              ),
            }}
          />
        </p>
        <Stack gap={3}>
          {systemStatus.memoryFreeBytes != null && (
            <FormRow
              id="device-system-status-memory-free-bytes"
              label={
                <FormattedMessage
                  id="Device.systemStatus.memoryFreeBytes"
                  defaultMessage="Free Memory"
                />
              }
            >
              <Form.Control
                type="text"
                value={formatBytes(systemStatus.memoryFreeBytes)}
                readOnly
              />
            </FormRow>
          )}
          {systemStatus.taskCount != null && (
            <FormRow
              id="device-system-status-task-count"
              label={
                <FormattedMessage
                  id="Device.systemStatus.taskCount"
                  defaultMessage="Active Tasks"
                />
              }
            >
              <Form.Control
                type="text"
                value={systemStatus.taskCount}
                readOnly
              />
            </FormRow>
          )}
          {systemStatus.uptimeMilliseconds != null && (
            <FormRow
              id="device-system-status-uptime"
              label={
                <FormattedMessage
                  id="Device.systemStatus.uptimeMilliseconds"
                  defaultMessage="Last boot at"
                />
              }
            >
              <FormValue>
                <FormattedDate
                  value={dayjs(systemStatus.timestamp)
                    .subtract(systemStatus.uptimeMilliseconds, "millisecond")
                    .toDate()}
                  year="numeric"
                  month="long"
                  day="numeric"
                  hour="numeric"
                  minute="numeric"
                />
              </FormValue>
            </FormRow>
          )}
        </Stack>
      </div>
    </Tab>
  );
};

interface DeviceWiFiScanResultsTabProps {
  deviceRef: Device_wifiScanResults$key;
}

const DeviceWiFiScanResultsTab = ({
  deviceRef,
}: DeviceWiFiScanResultsTabProps) => {
  const intl = useIntl();
  const { wifiScanResults } = useFragment(
    DEVICE_WIFI_SCAN_RESULTS_FRAGMENT,
    deviceRef
  );
  if (!wifiScanResults) {
    return null;
  }
  // TODO: handle readonly type without mapping to mutable type
  const scanResults = wifiScanResults.map((wifiScanResult) => ({
    ...wifiScanResult,
  }));
  return (
    <Tab
      eventKey="device-wifi-scan-results-tab"
      title={intl.formatMessage({
        id: "pages.Device.wifiScanResultsTab",
        defaultMessage: "WiFi APs",
      })}
    >
      <div className="mt-3">
        {scanResults.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.Device.wifiScanResultsTab.noResults.title"
                defaultMessage="No results"
              />
            }
          >
            <FormattedMessage
              id="pages.Device.wifiScanResultsTab.noResults.message"
              defaultMessage="The device has not detected any WiFi AP yet."
            />
          </Result.EmptyList>
        ) : (
          <WiFiScanResultsTable data={scanResults} />
        )}
      </div>
    </Tab>
  );
};

interface DeviceBatteryTabProps {
  deviceRef: Device_batteryStatus$key;
}

const DeviceBatteryTab = ({ deviceRef }: DeviceBatteryTabProps) => {
  const intl = useIntl();
  const { batteryStatus } = useFragment(
    DEVICE_BATTERY_STATUS_FRAGMENT,
    deviceRef
  );
  if (!batteryStatus) {
    return null;
  }
  // TODO: handle readonly type without mapping to mutable type
  const batterySlots = batteryStatus.map((batterySlot) => ({
    ...batterySlot,
  }));
  return (
    <Tab
      eventKey="device-battery-tab"
      title={intl.formatMessage({
        id: "pages.Device.BatteryStatusTab",
        defaultMessage: "Battery",
      })}
    >
      <div className="mt-3">
        {batterySlots.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.Device.BatteryStatusTab.noBattery.title"
                defaultMessage="No battery"
              />
            }
          >
            <FormattedMessage
              id="pages.Device.BatteryStatusTab.noBattery.message"
              defaultMessage="The device has not detected any battery yet."
            />
          </Result.EmptyList>
        ) : (
          <BatteryTable data={batterySlots} />
        )}
      </div>
    </Tab>
  );
};

type SoftwareUpdateTabProps = {
  deviceRef: Device_otaOperations$key;
};

const SoftwareUpdateTab = ({ deviceRef }: SoftwareUpdateTabProps) => {
  // this assumes all devices can be updated
  // TODO: edgehog should represent the 2 different states:
  //       - device can be updated but never did
  //       - device never updated because it doesn't have this capability
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const intl = useIntl();
  const device = useFragment(DEVICE_OTA_OPERATIONS_FRAGMENT, deviceRef);
  const [createOtaOperation, isCreatingOtaOperation] =
    useMutation<Device_createManualOtaOperation_Mutation>(
      DEVICE_CREATE_MANUAL_OTA_OPERATION_MUTATION
    );

  const currentOperations = device.otaOperations
    .filter(
      (operation) =>
        operation.status === "PENDING" || operation.status === "IN_PROGRESS"
    )
    .map((operation) => ({ ...operation }));

  // For now devices only support 1 update operation at a time
  const currentOperation = currentOperations?.[0] || null;

  const launchManualOTAUpdate = (file: File) => {
    createOtaOperation({
      variables: {
        input: {
          deviceId: device.id,
          baseImageFile: file,
        },
      },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map((error) => error.message)
            .join(". \n");
          return setErrorFeedback(errorFeedback);
        }
      },
      onError(error) {
        setErrorFeedback(
          <FormattedMessage
            id="pages.Device.otaUpdateCreationErrorFeedback"
            defaultMessage="Could not start the OTA update, please try again."
          />
        );
      },
      updater(store, data) {
        const otaOperationId = data.createManualOtaOperation?.otaOperation?.id;
        if (otaOperationId) {
          const otaOperation = store.get(otaOperationId);
          const storedDevice = store.get(device.id);
          const otaOperations = storedDevice?.getLinkedRecords("otaOperations");
          if (storedDevice && otaOperation && otaOperations) {
            storedDevice.setLinkedRecords(
              [otaOperation, ...otaOperations],
              "otaOperations"
            );
          }
        }
      },
    });
  };

  return (
    <Tab
      eventKey="device-software-update-tab"
      title={intl.formatMessage({
        id: "pages.Device.SoftwareUpdateTab",
        defaultMessage: "Software Updates",
      })}
    >
      <div className="mt-3">
        <h5>
          <FormattedMessage
            id="pages.Device.SoftwareUpdateTab.manualOTAUpdate"
            defaultMessage="Manual OTA Update"
          />
        </h5>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        {currentOperation ? (
          <div className="mt-3">
            <FormattedMessage
              id="pages.Device.SoftwareUpdateTab.updatingTo"
              defaultMessage="Updating to image <a>{baseImageName}</a>"
              values={{
                a: (chunks: React.ReactNode) => (
                  <a
                    target="_blank"
                    rel="noreferrer"
                    href={currentOperation.baseImageUrl}
                  >
                    {chunks}
                  </a>
                ),
                baseImageName: currentOperation.baseImageUrl.split("/").pop(),
              }}
            />
          </div>
        ) : (
          <BaseImageForm
            className="mt-3"
            onSubmit={launchManualOTAUpdate}
            isLoading={isCreatingOtaOperation}
          />
        )}
        <h5 className="mt-4">
          <FormattedMessage
            id="pages.Device.SoftwareUpdateTab.updatesHistory"
            defaultMessage="History"
          />
        </h5>
        <OperationTable deviceRef={device} />
      </div>
    </Tab>
  );
};

interface DeviceCellularConnectionTabProps {
  deviceRef: NonNullable<Device_getDevice_QueryResponse["device"]>;
}

const DeviceCellularConnectionTab = ({
  deviceRef,
}: DeviceCellularConnectionTabProps) => {
  const intl = useIntl();

  const { cellularConnection } = deviceRef;
  if (!cellularConnection) {
    return null;
  }

  return (
    <Tab
      eventKey="device-cellular-connection-tab"
      title={intl.formatMessage({
        id: "pages.Device.CellularConnectionTab",
        defaultMessage: "Cellular Connection",
      })}
    >
      <div className="mt-3">
        {cellularConnection.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.Device.DeviceCellularConnectionTab.noModems.title"
                defaultMessage="No modem"
              />
            }
          >
            <FormattedMessage
              id="pages.Device.DeviceCellularConnectionTab.noModems.message"
              defaultMessage="The device has not detected any modems yet."
            />
          </Result.EmptyList>
        ) : (
          <CellularConnectionTabs deviceRef={deviceRef} />
        )}
      </div>
    </Tab>
  );
};

interface DeviceContentProps {
  getDeviceQuery: PreloadedQuery<Device_getDevice_Query>;
}

const DeviceContent = ({ getDeviceQuery }: DeviceContentProps) => {
  const deviceData = usePreloadedQuery(GET_DEVICE_QUERY, getDeviceQuery);

  // TODO: handle readonly type without mapping to mutable type
  const device = useMemo(
    () => deviceData.device && { ...deviceData.device },
    [deviceData.device]
  );

  if (!device) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Device.deviceNotFound.title"
            defaultMessage="Device not found."
          />
        }
      >
        <Link route={Route.devices}>
          <FormattedMessage
            id="pages.Device.deviceNotFound.message"
            defaultMessage="Return to the device list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={device.name} />
      <Page.Main>
        <Stack gap={3}>
          <Row>
            <Col md="5" lg="4" xl="3">
              <div>
                <Figure
                  alt={device.name}
                  src={device.systemModel?.pictureUrl || undefined}
                />
              </div>
            </Col>
            <Col md="7" lg="8" xl="9">
              <Form className="ms-3">
                <Stack gap={3}>
                  <FormRow
                    id="form-device-name"
                    label={
                      <FormattedMessage
                        id="Device.name"
                        defaultMessage="Name"
                      />
                    }
                  >
                    <Form.Control type="text" value={device.name} readOnly />
                  </FormRow>
                  <FormRow
                    id="form-device-deviceId"
                    label={
                      <FormattedMessage
                        id="Device.deviceId"
                        defaultMessage="Device ID"
                      />
                    }
                  >
                    <Form.Control
                      type="text"
                      value={device.deviceId}
                      readOnly
                    />
                  </FormRow>
                  {device.systemModel && (
                    <>
                      <FormRow
                        id="form-device-system-model"
                        label={
                          <FormattedMessage
                            id="Device.systemModel"
                            defaultMessage="System Model"
                          />
                        }
                      >
                        <Form.Control
                          type="text"
                          value={device.systemModel.name}
                          readOnly
                        />
                      </FormRow>
                      <FormRow
                        id="form-device-hardware-type"
                        label={
                          <FormattedMessage
                            id="Device.hardwareType"
                            defaultMessage="Hardware Type"
                          />
                        }
                      >
                        <Form.Control
                          type="text"
                          value={device.systemModel.hardwareType.name}
                          readOnly
                        />
                      </FormRow>
                    </>
                  )}
                  <FormRow
                    id="form-device-connection-status"
                    label={
                      <FormattedMessage
                        id="Device.connectionStatus"
                        defaultMessage="Connection"
                      />
                    }
                  >
                    <FormValue>
                      <ConnectionStatus connected={device.online} />
                    </FormValue>
                  </FormRow>
                  <FormRow
                    id="form-device-last-seen"
                    label={
                      <FormattedMessage
                        id="Device.lastSeen"
                        defaultMessage="Last seen"
                      />
                    }
                  >
                    <FormValue>
                      <LastSeen
                        lastConnection={device.lastConnection}
                        lastDisconnection={device.lastDisconnection}
                        online={device.online}
                      />
                    </FormValue>
                  </FormRow>
                </Stack>
              </Form>
            </Col>
          </Row>
          <Tabs
            tabsOrder={[
              "device-hardware-info-tab",
              "device-os-info-tab",
              "device-runtime-info-tab",
              "device-base-image-tab",
              "device-system-status-tab",
              "device-storage-usage-tab",
              "device-battery-tab",
              "device-location-tab",
              "device-cellular-connection-tab",
              "device-wifi-scan-results-tab",
              "device-software-update-tab",
            ]}
          >
            <DeviceHardwareInfoTab deviceRef={device} />
            <DeviceOSInfoTab deviceRef={device} />
            <DeviceRuntimeInfoTab deviceRef={device} />
            <DeviceBaseImageTab deviceRef={device} />
            <DeviceSystemStatusTab deviceRef={device} />
            <DeviceStorageUsageTab deviceRef={device} />
            <DeviceBatteryTab deviceRef={device} />
            <DeviceCellularConnectionTab deviceRef={device} />
            <DeviceLocationTab deviceRef={device} />
            <DeviceWiFiScanResultsTab deviceRef={device} />
            <SoftwareUpdateTab deviceRef={device} />
          </Tabs>
        </Stack>
      </Page.Main>
    </Page>
  );
};

const DevicePage = () => {
  const { deviceId = "" } = useParams();

  const [getDeviceQuery, getDevice] =
    useQueryLoader<Device_getDevice_Query>(GET_DEVICE_QUERY);

  useEffect(() => {
    getDevice({ id: deviceId });
  }, [getDevice, deviceId]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={() => {
          getDevice({ id: deviceId });
        }}
      >
        {getDeviceQuery && <DeviceContent getDeviceQuery={getDeviceQuery} />}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DevicePage;
