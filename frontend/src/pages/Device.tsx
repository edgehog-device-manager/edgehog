/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import React, {
  Suspense,
  useCallback,
  useEffect,
  useState,
  useMemo,
  useRef,
} from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useFragment,
  usePreloadedQuery,
  useQueryLoader,
  useMutation,
  fetchQuery,
  useRelayEnvironment,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import type { Subscription } from "relay-runtime";
import { FormattedDate, FormattedMessage, useIntl } from "react-intl";
import dayjs from "dayjs";
import _ from "lodash";

import type { Device_batteryStatus$key } from "api/__generated__/Device_batteryStatus.graphql";
import type { Device_hardwareInfo$key } from "api/__generated__/Device_hardwareInfo.graphql";
import type { Device_location$key } from "api/__generated__/Device_location.graphql";
import type { Device_baseImage$key } from "api/__generated__/Device_baseImage.graphql";
import type { Device_osInfo$key } from "api/__generated__/Device_osInfo.graphql";
import type { Device_runtimeInfo$key } from "api/__generated__/Device_runtimeInfo.graphql";
import type { Device_storageUsage$key } from "api/__generated__/Device_storageUsage.graphql";
import type { Device_systemStatus$key } from "api/__generated__/Device_systemStatus.graphql";
import type { Device_wifiScanResults$key } from "api/__generated__/Device_wifiScanResults.graphql";
import type { Device_networkInterfaces$key } from "api/__generated__/Device_networkInterfaces.graphql";
import type { Device_otaOperations$key } from "api/__generated__/Device_otaOperations.graphql";
import type { Device_cellularConnection$key } from "api/__generated__/Device_cellularConnection.graphql";
import type { Device_connectionStatus$key } from "api/__generated__/Device_connectionStatus.graphql";
import type { Device_getDevice_Query } from "api/__generated__/Device_getDevice_Query.graphql";
import type { Device_createManualOtaOperation_Mutation } from "api/__generated__/Device_createManualOtaOperation_Mutation.graphql";
import type { Device_updateDevice_Mutation } from "api/__generated__/Device_updateDevice_Mutation.graphql";
import type { Device_requestForwarderSession_Mutation } from "api/__generated__/Device_requestForwarderSession_Mutation.graphql";
import type { Device_getForwarderSession_Query } from "api/__generated__/Device_getForwarderSession_Query.graphql";
import type { Device_getExistingDeviceTags_Query } from "api/__generated__/Device_getExistingDeviceTags_Query.graphql";
import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Button from "components/Button";
import CellularConnectionTabs from "components/CellularConnectionTabs";
import Center from "components/Center";
import ConnectionStatus from "components/ConnectionStatus";
import Col from "components/Col";
import Figure from "components/Figure";
import Form from "components/Form";
import LastSeen from "components/LastSeen";
import LedBehaviorDropdown from "components/LedBehaviorDropdown";
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
import NetworkInterfacesTable from "components/NetworkInterfacesTable";
import BaseImageForm from "forms/BaseImageForm";
import MultiSelect from "components/MultiSelect";

const DEVICE_HARDWARE_INFO_FRAGMENT = graphql`
  fragment Device_hardwareInfo on Device {
    capabilities
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
    capabilities
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
    capabilities
    osInfo {
      name
      version
    }
  }
`;

const DEVICE_LOCATION_FRAGMENT = graphql`
  fragment Device_location on Device {
    capabilities
    position {
      latitude
      longitude
      timestamp
    }
    location {
      formattedAddress
    }
  }
`;

const DEVICE_STORAGE_USAGE_FRAGMENT = graphql`
  fragment Device_storageUsage on Device {
    capabilities
    ...StorageTable_storageUsage
  }
`;

const DEVICE_SYSTEM_STATUS_FRAGMENT = graphql`
  fragment Device_systemStatus on Device {
    capabilities
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
    capabilities
    ...WiFiScanResultsTable_wifiScanResults
  }
`;

const DEVICE_BATTERY_STATUS_FRAGMENT = graphql`
  fragment Device_batteryStatus on Device {
    capabilities
    ...BatteryTable_batteryStatus
  }
`;

const DEVICE_OTA_OPERATIONS_FRAGMENT = graphql`
  fragment Device_otaOperations on Device {
    id
    capabilities
    otaOperations {
      id
      baseImageUrl
      status
      createdAt
    }
    ...OperationTable_otaOperations
  }
`;

const DEVICE_RUNTIME_INFO_FRAGMENT = graphql`
  fragment Device_runtimeInfo on Device {
    capabilities
    runtimeInfo {
      name
      version
      environment
      url
    }
  }
`;

const DEVICE_CELLULAR_CONNECTION_FRAGMENT = graphql`
  fragment Device_cellularConnection on Device {
    capabilities
    ...CellularConnectionTabs_cellularConnection
  }
`;

const DEVICE_NETWORK_INTERFACES__FRAGMENT = graphql`
  fragment Device_networkInterfaces on Device {
    capabilities
    ...NetworkInterfacesTable_networkInterfaces
  }
`;

const DEVICE_CONNECTION_STATUS_FRAGMENT = graphql`
  fragment Device_connectionStatus on Device {
    online
    lastConnection
    lastDisconnection
  }
`;

const GET_DEVICE_QUERY = graphql`
  query Device_getDevice_Query($id: ID!) {
    forwarderConfig {
      __typename
    }
    device(id: $id) {
      id
      deviceId
      name
      online
      capabilities
      systemModel {
        name
        pictureUrl
        hardwareType {
          name
        }
      }
      tags {
        name
      }
      deviceGroups {
        id
        name
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
      ...Device_cellularConnection
      ...Device_networkInterfaces
      ...Device_connectionStatus
    }
  }
`;

const GET_DEVICE_OTA_OPERATIONS_QUERY = graphql`
  query Device_getDeviceOtaOperations_Query($id: ID!) {
    device(id: $id) {
      id
      online
      lastConnection
      lastDisconnection
      ...Device_otaOperations
    }
  }
`;

const DEVICE_CREATE_MANUAL_OTA_OPERATION_MUTATION = graphql`
  mutation Device_createManualOtaOperation_Mutation(
    $input: CreateManualOtaOperationInput!
  ) {
    createManualOtaOperation(input: $input) {
      result {
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

const UPDATE_DEVICE_MUTATION = graphql`
  mutation Device_updateDevice_Mutation(
    $deviceId: ID!
    $input: UpdateDeviceInput!
  ) {
    updateDevice(id: $deviceId, input: $input) {
      result {
        id
        name
        tags {
          name
        }
        deviceGroups {
          id
          name
        }
      }
    }
  }
`;

const GET_TAGS_QUERY = graphql`
  query Device_getExistingDeviceTags_Query {
    existingDeviceTags {
      name
    }
  }
`;

const REQUEST_FORWARDER_SESSION_MUTATION = graphql`
  mutation Device_requestForwarderSession_Mutation(
    $input: RequestForwarderSessionInput!
  ) {
    requestForwarderSession(input: $input)
  }
`;

const GET_FORWARDER_SESSION_QUERY = graphql`
  query Device_getForwarderSession_Query(
    $deviceId: ID!
    $sessionToken: String!
  ) {
    forwarderSession(deviceId: $deviceId, token: $sessionToken) {
      status
      secure
      forwarderHostname
      forwarderPort
    }
  }
`;

const TTYD_PORT = 7681;

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
  const { hardwareInfo, capabilities } = useFragment(
    DEVICE_HARDWARE_INFO_FRAGMENT,
    deviceRef,
  );
  if (!hardwareInfo || !capabilities.includes("HARDWARE_INFO")) {
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
  const { baseImage, capabilities } = useFragment(
    DEVICE_BASE_IMAGE_FRAGMENT,
    deviceRef,
  );
  if (
    !baseImage ||
    Object.values(baseImage).every((value) => value === null) ||
    !capabilities.includes("BASE_IMAGE")
  ) {
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
  const { osInfo, capabilities } = useFragment(
    DEVICE_OS_INFO_FRAGMENT,
    deviceRef,
  );
  if (
    !osInfo ||
    Object.values(osInfo).every((value) => value === null) ||
    !capabilities.includes("OPERATING_SYSTEM")
  ) {
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
  const { runtimeInfo, capabilities } = useFragment(
    DEVICE_RUNTIME_INFO_FRAGMENT,
    deviceRef,
  );
  if (
    !runtimeInfo ||
    Object.values(runtimeInfo).every((value) => value === null) ||
    !capabilities.includes("RUNTIME_INFO")
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
  const device = useFragment(DEVICE_STORAGE_USAGE_FRAGMENT, deviceRef);
  if (!device.capabilities.includes("STORAGE")) {
    return null;
  }
  return (
    <Tab
      eventKey="device-storage-usage-tab"
      title={intl.formatMessage({
        id: "pages.Device.storageTab",
        defaultMessage: "Storage",
      })}
    >
      <div className="mt-3">
        <StorageTable deviceRef={device} />
      </div>
    </Tab>
  );
};

interface DeviceLocationTabProps {
  deviceRef: Device_location$key;
}

const DeviceLocationTab = ({ deviceRef }: DeviceLocationTabProps) => {
  const intl = useIntl();
  const { capabilities, position, location } = useFragment(
    DEVICE_LOCATION_FRAGMENT,
    deviceRef,
  );
  if (!position || !capabilities.includes("GEOLOCATION")) {
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
                  value={new Date(position.timestamp)}
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
          latitude={position.latitude}
          longitude={position.longitude}
          popup={
            <div>
              {location && <p>{location.formattedAddress}</p>}
              <p>
                {position.latitude}, {position.longitude}
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
  const { systemStatus, capabilities } = useFragment(
    DEVICE_SYSTEM_STATUS_FRAGMENT,
    deviceRef,
  );
  if (!systemStatus || !capabilities.includes("SYSTEM_STATUS")) {
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
  const device = useFragment(DEVICE_WIFI_SCAN_RESULTS_FRAGMENT, deviceRef);
  if (!device.capabilities.includes("WIFI")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-wifi-scan-results-tab"
      title={intl.formatMessage({
        id: "pages.Device.wifiScanResultsTab",
        defaultMessage: "WiFi APs",
      })}
    >
      <div className="mt-3">
        <WiFiScanResultsTable deviceRef={device} />
      </div>
    </Tab>
  );
};

interface DeviceBatteryTabProps {
  deviceRef: Device_batteryStatus$key;
}

const DeviceBatteryTab = ({ deviceRef }: DeviceBatteryTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_BATTERY_STATUS_FRAGMENT, deviceRef);
  if (!device.capabilities.includes("BATTERY_STATUS")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-battery-tab"
      title={intl.formatMessage({
        id: "pages.Device.BatteryStatusTab",
        defaultMessage: "Battery",
      })}
    >
      <div className="mt-3">
        <BatteryTable deviceRef={device} />
      </div>
    </Tab>
  );
};

type SoftwareUpdateTabProps = {
  deviceRef: Device_otaOperations$key;
};

const SoftwareUpdateTab = ({ deviceRef }: SoftwareUpdateTabProps) => {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const intl = useIntl();
  const relayEnvironment = useRelayEnvironment();

  const device = useFragment(DEVICE_OTA_OPERATIONS_FRAGMENT, deviceRef);
  const deviceId = device.id;

  const [createOtaOperation, isCreatingOtaOperation] =
    useMutation<Device_createManualOtaOperation_Mutation>(
      DEVICE_CREATE_MANUAL_OTA_OPERATION_MUTATION,
    );

  const otaOperations = device.otaOperations
    .map((operation) => ({ ...operation }))
    .sort((a, b) => {
      if (a.createdAt > b.createdAt) {
        return -1;
      }
      if (a.createdAt < b.createdAt) {
        return 1;
      }
      return 0;
    });

  const lastFinishedOperationIndex = otaOperations.findIndex(
    ({ status }) => status === "SUCCESS" || status === "FAILURE",
  );
  const currentOperations =
    lastFinishedOperationIndex === -1
      ? otaOperations
      : otaOperations.slice(0, lastFinishedOperationIndex);

  // For now devices only support 1 update operation at a time
  const currentOperation = currentOperations[0] || null;

  // TODO: use GraphQL subscription (when available) to get updates about OTA operation
  const subscriptionRef = useRef<Subscription | null>(null);
  useEffect(() => {
    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
      }
    };
  }, []);

  useEffect(() => {
    if (!currentOperation || isRefreshing) {
      return;
    }
    const refreshTimerId = setTimeout(() => {
      setIsRefreshing(true);
      subscriptionRef.current = fetchQuery(
        relayEnvironment,
        GET_DEVICE_OTA_OPERATIONS_QUERY,
        {
          id: deviceId,
        },
      ).subscribe({
        complete: () => {
          setIsRefreshing(false);
        },
        error: () => {
          setIsRefreshing(false);
        },
      });
    }, 10000);

    return () => {
      clearTimeout(refreshTimerId);
    };
  }, [
    currentOperation,
    isRefreshing,
    setIsRefreshing,
    relayEnvironment,
    deviceId,
  ]);

  if (!device.capabilities.includes("SOFTWARE_UPDATES")) {
    return null;
  }

  const launchManualOTAUpdate = (file: File) => {
    createOtaOperation({
      variables: {
        input: {
          deviceId,
          baseImageFile: file,
        },
      },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          return setErrorFeedback(errorFeedback);
        }
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.Device.otaUpdateCreationErrorFeedback"
            defaultMessage="Could not start the OTA update, please try again."
          />,
        );
      },
      updater(store, data) {
        const otaOperationId = data?.createManualOtaOperation?.result?.id;
        if (otaOperationId) {
          const otaOperation = store.get(otaOperationId);
          const storedDevice = store.get(deviceId);
          const otaOperations = storedDevice?.getLinkedRecords("otaOperations");
          if (storedDevice && otaOperation && otaOperations) {
            storedDevice.setLinkedRecords(
              [otaOperation, ...otaOperations],
              "otaOperations",
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
        <BaseImageForm
          className="mt-3"
          onSubmit={launchManualOTAUpdate}
          isLoading={isCreatingOtaOperation}
        />
        {currentOperation && (
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
            {isRefreshing && <Spinner size="sm" className="ms-2" />}
          </div>
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
  deviceRef: Device_cellularConnection$key;
}

const DeviceCellularConnectionTab = ({
  deviceRef,
}: DeviceCellularConnectionTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_CELLULAR_CONNECTION_FRAGMENT, deviceRef);

  if (!device.capabilities.includes("CELLULAR_CONNECTION")) {
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
        <CellularConnectionTabs deviceRef={device} />
      </div>
    </Tab>
  );
};

interface DeviceNetworkInterfacesTabProps {
  deviceRef: Device_networkInterfaces$key;
}

const DeviceNetworkInterfacesTab = ({
  deviceRef,
}: DeviceNetworkInterfacesTabProps) => {
  const intl = useIntl();
  const device = useFragment(DEVICE_NETWORK_INTERFACES__FRAGMENT, deviceRef);

  if (!device.capabilities.includes("NETWORK_INTERFACE_INFO")) {
    return null;
  }

  return (
    <Tab
      eventKey="device-network-interfaces-tab"
      title={intl.formatMessage({
        id: "pages.Device.NetworkInterfacesTab",
        defaultMessage: "Network Interfaces",
      })}
    >
      <div className="mt-3">
        <NetworkInterfacesTable deviceRef={device} />
      </div>
    </Tab>
  );
};

interface DeviceConnectionFormRowsProps {
  deviceRef: Device_connectionStatus$key;
}
const DeviceConnectionFormRows = ({
  deviceRef,
}: DeviceConnectionFormRowsProps) => {
  const { online, lastConnection, lastDisconnection } = useFragment(
    DEVICE_CONNECTION_STATUS_FRAGMENT,
    deviceRef,
  );

  return (
    <>
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
          <ConnectionStatus connected={online} />
        </FormValue>
      </FormRow>
      <FormRow
        id="form-device-last-seen"
        label={
          <FormattedMessage id="Device.lastSeen" defaultMessage="Last seen" />
        }
      >
        <FormValue>
          <LastSeen
            lastConnection={lastConnection}
            lastDisconnection={lastDisconnection}
            online={online}
          />
        </FormValue>
      </FormRow>
    </>
  );
};

function timeoutPromise<T>(promise: Promise<T>, millis: number) {
  return Promise.race([
    promise,
    new Promise((resolve, reject) => setTimeout(() => reject(), millis)),
  ]);
}

async function retryWithExponentialBackoff<T>(
  fn: () => Promise<T>,
  attempt = 1,
  maxAttempts = 4,
  baseDelayMs = 1000,
): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    if (attempt >= maxAttempts) {
      throw error;
    }
    const delayMs = baseDelayMs * (2 ** attempt - 1);
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    return await retryWithExponentialBackoff(
      fn,
      attempt + 1,
      maxAttempts,
      baseDelayMs,
    );
  }
}

interface DeviceContentProps {
  getDeviceQuery: PreloadedQuery<Device_getDevice_Query>;
  getTagsQuery: PreloadedQuery<Device_getExistingDeviceTags_Query>;
  refreshTags: () => void;
}

const DeviceContent = ({
  getDeviceQuery,
  getTagsQuery,
  refreshTags,
}: DeviceContentProps) => {
  const { deviceId = "" } = useParams();
  const relayEnvironment = useRelayEnvironment();
  const deviceData = usePreloadedQuery(GET_DEVICE_QUERY, getDeviceQuery);
  const tagsData = usePreloadedQuery(GET_TAGS_QUERY, getTagsQuery);
  const [isOpeningRemoteTerminal, setIsOpeningRemoteTerminal] = useState(false);
  const [remoteTerminalErrorFeedback, setRemoteTerminalErrorFeedback] =
    useState<React.ReactNode>(null);

  // TODO: handle readonly type without mapping to mutable type
  const device = useMemo(
    () =>
      deviceData.device && {
        ...deviceData.device,
        tags: deviceData.device.tags.slice(),
      },
    [deviceData.device],
  );

  const isForwarderEnabled = useMemo(
    () => deviceData.forwarderConfig != null,
    [deviceData.forwarderConfig],
  );

  const [deviceDraft, setDeviceDraft] = useState(
    _.pick(device, ["name", "tags"]),
  );

  const deviceTags = useMemo(
    () =>
      deviceDraft.tags?.map(({ name: tag }) => ({
        label: tag,
        value: tag,
      })) || [],
    [deviceDraft.tags],
  );

  const tags = useMemo(
    () =>
      tagsData.existingDeviceTags.map(({ name: tag }) => ({
        label: tag,
        value: tag,
      })),
    [tagsData.existingDeviceTags],
  );

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [requestForwarderSession, isRequestingForwarderSession] =
    useMutation<Device_requestForwarderSession_Mutation>(
      REQUEST_FORWARDER_SESSION_MUTATION,
    );

  const handleOpenRemoteTerminal = useCallback(
    async (sessionToken: string) => {
      const data = await fetchQuery<Device_getForwarderSession_Query>(
        relayEnvironment,
        GET_FORWARDER_SESSION_QUERY,
        { deviceId, sessionToken },
      ).toPromise();

      if (!data?.forwarderSession) {
        throw new Error("The forwarder session does not exist.");
      }

      const { forwarderHostname, forwarderPort, secure, status } =
        data.forwarderSession;

      if (status !== "CONNECTED") {
        throw new Error("The forwarder session is not connected.");
      }

      const forwarderProtocol = secure ? "https" : "http";

      window.open(
        `${forwarderProtocol}://${forwarderHostname}:${forwarderPort}/v1/${sessionToken}/http/${TTYD_PORT}`,
        "_blank",
      );
    },
    [relayEnvironment, deviceId],
  );

  const handleRequestForwarderSession = useCallback(() => {
    requestForwarderSession({
      variables: { input: { deviceId } },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          return setErrorFeedback(errorFeedback);
        }
        const sessionToken = data.requestForwarderSession;

        setIsOpeningRemoteTerminal(true);
        timeoutPromise(
          retryWithExponentialBackoff(() =>
            handleOpenRemoteTerminal(sessionToken),
          ),
          10_000,
        )
          .catch(() => {
            setRemoteTerminalErrorFeedback(
              <FormattedMessage
                id="pages.Device.openRemoteTerminalErrorFeedback"
                defaultMessage="Could not access the remote terminal, please try again."
                description="Feedback for unknown error while opening a remote terminal session"
              />,
            );
          })
          .finally(() => {
            setIsOpeningRemoteTerminal(false);
          });
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.Device.openRemoteTerminalErrorFeedback"
            defaultMessage="Could not access the remote terminal, please try again."
            description="Feedback for unknown error while opening a remote terminal session"
          />,
        );
      },
    });
  }, [requestForwarderSession, handleOpenRemoteTerminal, deviceId]);

  const [updateDevice] = useMutation<Device_updateDevice_Mutation>(
    UPDATE_DEVICE_MUTATION,
  );

  const handleUpdateDevice = useMemo(
    () =>
      _.debounce(
        (
          draft: typeof deviceDraft,
          deviceChanges: Partial<typeof deviceDraft>,
        ) => {
          updateDevice({
            variables: { deviceId, input: deviceChanges },
            onCompleted(data, errors) {
              if (errors) {
                setDeviceDraft(draft);
                const errorFeedback = errors
                  .map(({ fields, message }) =>
                    fields.length ? `${fields.join(" ")} ${message}` : message,
                  )
                  .join(". \n");
                return setErrorFeedback(errorFeedback);
              }
              if (deviceChanges.tags != null) {
                refreshTags();
              }
            },
            onError() {
              setDeviceDraft(draft);
              setErrorFeedback(
                <FormattedMessage
                  id="pages.Device.updateDeviceErrorFeedback"
                  defaultMessage="Could not update the device, please try again."
                  description="Feedback for unknown error while updating a device"
                />,
              );
            },
            updater(store, data) {
              if (!data?.updateDevice?.result) {
                return;
              }

              const root = store.getRoot();
              const deviceGroups = root.getLinkedRecords("deviceGroups");
              if (!deviceGroups) {
                return;
              }

              const device = store
                .getRootField("updateDevice")
                .getLinkedRecord("result");
              const deviceId = device.getDataID();

              const linkedGroups = new Set(
                device
                  .getLinkedRecords("deviceGroups")
                  ?.map((deviceGroup) => deviceGroup.getDataID()),
              );

              deviceGroups.forEach((deviceGroup) => {
                const devices = deviceGroup.getLinkedRecords("devices");
                if (!devices) {
                  return;
                }

                if (!linkedGroups.has(deviceGroup.getDataID())) {
                  return deviceGroup.setLinkedRecords(
                    devices.filter((device) => device.getDataID() !== deviceId),
                    "devices",
                  );
                }

                if (
                  !devices.some((device) => device.getDataID() === deviceId)
                ) {
                  deviceGroup.setLinkedRecords([...devices, device], "devices");
                }
              });
            },
          });
        },
        500,
        { leading: true },
      ),
    [updateDevice, deviceId, refreshTags],
  );

  const handleDeviceChange = useCallback(
    (deviceChanges: Partial<typeof deviceDraft>) => {
      setDeviceDraft((draft) => ({ ...draft, ...deviceChanges }));
      handleUpdateDevice(deviceDraft, deviceChanges);
    },
    [handleUpdateDevice, deviceDraft],
  );
  const isValidNewTag = useCallback(
    (inputValue: string) => {
      const newTag = inputValue.trim().toLowerCase();
      return newTag !== "" && !deviceTags.some((tag) => tag.value === newTag);
    },
    [deviceTags],
  );
  const handleTagCreate = useCallback(
    (inputValue: string) => {
      const newTag = inputValue.trim().toLowerCase();
      handleDeviceChange({
        tags: deviceTags
          .map(({ value }) => ({ name: value }))
          .concat([{ name: newTag }]),
      });
    },
    [handleDeviceChange, deviceTags],
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

  const isRemoteTerminalSupported =
    isForwarderEnabled && device.capabilities.includes("REMOTE_TERMINAL");

  return (
    <Page>
      <Page.Header title={device.name} />
      <Page.Main>
        <Stack gap={3}>
          <Alert
            show={!!errorFeedback}
            variant="danger"
            onClose={() => setErrorFeedback(null)}
            dismissible
          >
            {errorFeedback}
          </Alert>
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
                    <Form.Control
                      type="text"
                      value={deviceDraft.name}
                      onChange={(e) =>
                        handleDeviceChange({ name: e.target.value })
                      }
                    />
                  </FormRow>
                  <FormRow
                    id="form-device-tags"
                    label={
                      <FormattedMessage
                        id="Device.tags"
                        defaultMessage="Tags"
                      />
                    }
                  >
                    <MultiSelect
                      creatable
                      value={deviceTags}
                      options={tags}
                      onChange={(value) =>
                        handleDeviceChange({
                          tags: value.map(({ value }) => ({ name: value })),
                        })
                      }
                      isValidNewOption={isValidNewTag}
                      onCreateOption={handleTagCreate}
                    />
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
                          value={device.systemModel.hardwareType?.name}
                          readOnly
                        />
                      </FormRow>
                    </>
                  )}
                  <FormRow
                    id="form-device-deviceGroups"
                    label={
                      <FormattedMessage
                        id="Device.groups"
                        defaultMessage="Groups"
                      />
                    }
                  >
                    <Stack direction="horizontal" gap={3}>
                      {device.deviceGroups.map((deviceGroup) => (
                        <Link
                          key={`device-group-link-${deviceGroup.id}`}
                          route={Route.deviceGroupsEdit}
                          params={{ deviceGroupId: deviceGroup.id }}
                        >
                          {deviceGroup.name}
                        </Link>
                      ))}
                    </Stack>
                  </FormRow>
                  <DeviceConnectionFormRows deviceRef={device} />
                  {device.capabilities.includes("LED_BEHAVIORS") && (
                    <FormRow
                      id="form-device-check-my-device"
                      label={
                        <FormattedMessage
                          id="Device.checkMyDevice"
                          defaultMessage="Check my Device"
                        />
                      }
                    >
                      <LedBehaviorDropdown
                        deviceId={device.id}
                        disabled={!device.online}
                        onError={setErrorFeedback}
                      />
                    </FormRow>
                  )}
                  {isRemoteTerminalSupported && (
                    <FormRow
                      id="form-device-open-remote-terminal"
                      label={
                        <FormattedMessage
                          id="Device.remoteTerminal.label"
                          defaultMessage="Remote Terminal"
                        />
                      }
                    >
                      <>
                        <Button
                          variant="secondary"
                          onClick={handleRequestForwarderSession}
                          disabled={
                            !device.online ||
                            isRequestingForwarderSession ||
                            isOpeningRemoteTerminal
                          }
                        >
                          {(isRequestingForwarderSession ||
                            isOpeningRemoteTerminal) && (
                            <Spinner size="sm" className="me-2" />
                          )}
                          <FormattedMessage
                            id="Device.remoteTerminal.openTerminalButton"
                            defaultMessage="Open"
                          />
                        </Button>
                        <Alert
                          show={!!remoteTerminalErrorFeedback}
                          variant="danger"
                          onClose={() => setRemoteTerminalErrorFeedback(null)}
                          dismissible
                          className="mt-3"
                        >
                          {remoteTerminalErrorFeedback}
                        </Alert>
                      </>
                    </FormRow>
                  )}
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
              "device-network-interfaces-tab",
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
            <DeviceNetworkInterfacesTab deviceRef={device} />
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

  const [getTagsQuery, getTags] =
    useQueryLoader<Device_getExistingDeviceTags_Query>(GET_TAGS_QUERY);

  const refreshTags = useCallback(
    () => getTags({}, { fetchPolicy: "store-and-network" }),
    [getTags],
  );

  useEffect(() => {
    getDevice({ id: deviceId });
    refreshTags();
  }, [getDevice, deviceId, refreshTags]);

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
          refreshTags();
        }}
      >
        {getDeviceQuery && getTagsQuery && (
          <DeviceContent
            getDeviceQuery={getDeviceQuery}
            getTagsQuery={getTagsQuery}
            refreshTags={refreshTags}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DevicePage;
