/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2026 SECO Mind Srl
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

import React, {
  Suspense,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import type { Device_getDevice_Query } from "@/api/__generated__/Device_getDevice_Query.graphql";
import type { Device_getExistingDeviceTags_Query } from "@/api/__generated__/Device_getExistingDeviceTags_Query.graphql";
import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/ui/alert/Alert";
import Center from "@/components/ui/center/Center";
import Page from "@/components/ui/page/Page";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import Tabs from "@/components/ui/tabs/Tabs";
import DeviceInfoCard from "@/components/fleet/devices/device-info-card/DeviceInfoCard";
import DeviceHardwareInfoTab from "@/components/fleet/devices/tabs/hardware-info-tab/HardwareInfoTab";
import DeviceOSInfoTab from "@/components/fleet/devices/tabs/os-info-tab/OSInfoTab";
import DeviceRuntimeInfoTab from "@/components/fleet/devices/tabs/runtime-info-tab/RuntimeInfoTab";
import DeviceBaseImageTab from "@/components/fleet/devices/tabs/base-image-tab/BaseImageTab";
import DeviceSystemStatusTab from "@/components/fleet/devices/tabs/system-status-tab/SystemStatusTab";
import DeviceStorageUsageTab from "@/components/fleet/devices/tabs/storage-usage-tab/StorageUsageTab";
import DeviceBatteryTab from "@/components/fleet/devices/tabs/battery-tab/BatteryTab";
import DeviceCellularConnectionTab from "@/components/fleet/devices/tabs/cellular-connection-tab/CellularConnectionTab";
import DeviceNetworkInterfacesTab from "@/components/fleet/devices/tabs/network-interfaces-tab/NetworkInterfacesTab";
import DeviceLocationTab from "@/components/fleet/devices/tabs/location-tab/LocationTab";
import DeviceWiFiScanResultsTab from "@/components/fleet/devices/tabs/wifi-scan-results-tab/WiFiScanResultsTab";
import DeviceSoftwareUpdateTab from "@/components/fleet/devices/tabs/software-update-tab/SoftwareUpdateTab";
import DeviceFileManagementTab from "@/components/fleet/devices/tabs/file-management-tab/FileManagementTab";
import DeviceApplicationsTab from "@/components/fleet/devices/tabs/applications-tab/ApplicationsTab";

const GET_DEVICE_QUERY = graphql`
  query Device_getDevice_Query($id: ID!, $first: Int, $after: String) {
    forwarderConfig {
      __typename
    }
    device(id: $id) {
      name
      ...DeviceInfoCard_device
      ...HardwareInfoTab_hardwareInfo
      ...BaseImageTab_baseImage
      ...OSInfoTab_osInfo
      ...RuntimeInfoTab_runtimeInfo
      ...LocationTab_location
      ...StorageUsageTab_storageUsage
      ...SystemStatusTab_systemStatus
      ...WiFiScanResultsTab_wifiScanResults
      ...BatteryTab_batteryStatus
      ...SoftwareUpdateTab_otaOperations
      ...CellularConnectionTab_cellularConnection
      ...NetworkInterfacesTab_networkInterfaces
      ...FileManagementTab_fileManagement
        @arguments(storageFirst: $first, storageAfter: $after)
    }
    ...ApplicationsTab_deployedApplications
  }
`;

const GET_TAGS_QUERY = graphql`
  query Device_getExistingDeviceTags_Query {
    existingDeviceTags {
      edges {
        node {
          name
        }
      }
    }
  }
`;

const TAB_KEYS = [
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
  "device-file-management-tab",
  "device-applications-tab",
];

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
  const { deviceId = "", activeTab } = useParams();
  const navigate = useNavigate();

  const deviceData = usePreloadedQuery<Device_getDevice_Query>(
    GET_DEVICE_QUERY,
    getDeviceQuery,
  );

  const tagsData = usePreloadedQuery<Device_getExistingDeviceTags_Query>(
    GET_TAGS_QUERY,
    getTagsQuery,
  );

  const isForwarderEnabled = useMemo(
    () => deviceData.forwarderConfig != null,
    [deviceData.forwarderConfig],
  );

  const device = deviceData.device;

  const tags = useMemo(
    () =>
      tagsData.existingDeviceTags?.edges?.map(({ node: { name: tag } }) => ({
        label: tag,
        value: tag,
      })),
    [tagsData.existingDeviceTags],
  );

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const currentTabKey = activeTab || TAB_KEYS[0];

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
          <Alert
            show={!!errorFeedback}
            variant="danger"
            onClose={() => setErrorFeedback(null)}
            dismissible
          >
            {errorFeedback}
          </Alert>
          <DeviceInfoCard
            deviceRef={device}
            tags={tags}
            refreshTags={refreshTags}
            isForwarderSupported={isForwarderEnabled}
            onError={setErrorFeedback}
          />
          <Tabs
            className="pt-1 d-flex flex-column flex-grow-1"
            activeKey={currentTabKey}
            tabsOrder={TAB_KEYS}
            onChange={(tabKey) =>
              navigate(
                {
                  route: Route.devicesEdit,
                  params: { deviceId, activeTab: tabKey },
                },
                { replace: true },
              )
            }
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
            <DeviceSoftwareUpdateTab deviceRef={device} />
            <DeviceFileManagementTab deviceRef={device} />
            <DeviceApplicationsTab deviceRef={deviceData} />
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
    getDevice({ id: deviceId, first: 10_000 });
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
          getDevice({ id: deviceId, first: 10_000 });
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
