/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2025 SECO Mind Srl
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
  useState,
  useMemo,
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
import type { PayloadError } from "relay-runtime";
import { FormattedMessage } from "react-intl";
import _ from "lodash";

import type { Device_connectionStatus$key } from "@/api/__generated__/Device_connectionStatus.graphql";
import type { Device_getDevice_Query } from "@/api/__generated__/Device_getDevice_Query.graphql";
import type { Device_updateDevice_Mutation } from "@/api/__generated__/Device_updateDevice_Mutation.graphql";
import type { Device_addDeviceTags_Mutation } from "@/api/__generated__/Device_addDeviceTags_Mutation.graphql";
import type { Device_removeDeviceTags_Mutation } from "@/api/__generated__/Device_removeDeviceTags_Mutation.graphql";
import type { Device_requestForwarderSession_Mutation } from "@/api/__generated__/Device_requestForwarderSession_Mutation.graphql";
import type { Device_getForwarderSession_Query } from "@/api/__generated__/Device_getForwarderSession_Query.graphql";
import type { Device_getExistingDeviceTags_Query } from "@/api/__generated__/Device_getExistingDeviceTags_Query.graphql";
import { Link, Route } from "@/Navigation";
import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import ConnectionStatus from "@/components/ConnectionStatus";
import Col from "@/components/Col";
import Figure from "@/components/Figure";
import Form from "@/components/Form";
import LastSeen from "@/components/LastSeen";
import LedBehaviorDropdown from "@/components/LedBehaviorDropdown";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import Tabs from "@/components/Tabs";
import MultiSelect from "@/components/MultiSelect";
import { FormRow as BaseFormRow, FormRowProps } from "@/components/FormRow";
import assets from "@/assets";
import DeviceHardwareInfoTab from "@/components/DeviceTabs/HardwareInfoTab";
import DeviceOSInfoTab from "@/components/DeviceTabs/OSInfoTab";
import DeviceRuntimeInfoTab from "@/components/DeviceTabs/RuntimeInfoTab";
import DeviceBaseImageTab from "@/components/DeviceTabs/BaseImageTab";
import DeviceSystemStatusTab from "@/components/DeviceTabs/SystemStatusTab";
import DeviceStorageUsageTab from "@/components/DeviceTabs/StorageUsageTab";
import DeviceBatteryTab from "@/components/DeviceTabs/BatteryTab";
import DeviceCellularConnectionTab from "@/components/DeviceTabs/CellularConnectionTab";
import DeviceNetworkInterfacesTab from "@/components/DeviceTabs/NetworkInterfacesTab";
import DeviceLocationTab from "@/components/DeviceTabs/LocationTab";
import DeviceWiFiScanResultsTab from "@/components/DeviceTabs/WiFiScanResultsTab";
import DeviceSoftwareUpdateTab from "@/components/DeviceTabs/SoftwareUpdateTab";
import DeviceApplicationsTab from "@/components/DeviceTabs/ApplicationsTab";

const DEVICE_CONNECTION_STATUS_FRAGMENT = graphql`
  fragment Device_connectionStatus on Device {
    online
    lastConnection
    lastDisconnection
  }
`;

const GET_DEVICE_QUERY = graphql`
  query Device_getDevice_Query($id: ID!, $first: Int, $after: String) {
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
        edges {
          node {
            id
            name
          }
        }
      }
      deviceGroups {
        id
        name
      }
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
      ...Device_connectionStatus
    }
    ...ApplicationsTab_deployedApplications
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
      }
    }
  }
`;

const ADD_DEVICE_TAGS_MUTATION = graphql`
  mutation Device_addDeviceTags_Mutation(
    $deviceId: ID!
    $input: AddDeviceTagsInput!
  ) {
    addDeviceTags(id: $deviceId, input: $input) {
      result {
        id
        tags {
          edges {
            node {
              id
              name
            }
          }
        }
        deviceGroups {
          id
          name
        }
      }
    }
  }
`;

const REMOVE_DEVICE_TAGS_MUTATION = graphql`
  mutation Device_removeDeviceTags_Mutation(
    $deviceId: ID!
    $input: RemoveDeviceTagsInput!
  ) {
    removeDeviceTags(id: $deviceId, input: $input) {
      result {
        id
        tags {
          edges {
            node {
              id
              name
            }
          }
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
      edges {
        node {
          name
        }
      }
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

const FormRow = (props: FormRowProps) => (
  <BaseFormRow {...props} labelCol={4} valueCol={8} />
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

  const isForwarderEnabled = useMemo(
    () => deviceData.forwarderConfig != null,
    [deviceData.forwarderConfig],
  );

  const device = deviceData.device;
  const [deviceDraftName, setDeviceDraftName] = useState(device?.name || "");

  const deviceTags = useMemo(
    () =>
      device?.tags?.edges?.map(({ node: { name: tag } }) => ({
        label: tag,
        value: tag,
      })) || [],
    [device?.tags],
  );

  const tags = useMemo(
    () =>
      tagsData.existingDeviceTags?.edges?.map(({ node: { name: tag } }) => ({
        label: tag,
        value: tag,
      })),
    [tagsData.existingDeviceTags],
  );

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const handleAPIErrors = useCallback((errors: PayloadError[]) => {
    const errorFeedback = errors
      .map(({ fields, message }) =>
        fields.length ? `${fields.join(" ")} ${message}` : message,
      )
      .join(". \n");
    setErrorFeedback(errorFeedback);
  }, []);

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
          handleAPIErrors(errors);
          return;
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
  const [addDeviceTags] = useMutation<Device_addDeviceTags_Mutation>(
    ADD_DEVICE_TAGS_MUTATION,
  );
  const [removeDeviceTags] = useMutation<Device_removeDeviceTags_Mutation>(
    REMOVE_DEVICE_TAGS_MUTATION,
  );

  const handleUpdateDeviceName = useMemo(
    () =>
      _.debounce(
        (newDeviceName: string) => {
          updateDevice({
            variables: { deviceId, input: { name: newDeviceName } },
            onCompleted(data, errors) {
              if (errors) {
                handleAPIErrors(errors);
                return;
              }
            },
            onError() {
              setErrorFeedback(
                <FormattedMessage
                  id="pages.Device.updateDeviceErrorFeedback"
                  defaultMessage="Could not update the device, please try again."
                  description="Feedback for unknown error while updating a device"
                />,
              );
            },
          });
        },
        500,
        { leading: true },
      ),
    [updateDevice, deviceId],
  );

  const handleDeviceNameChange = useCallback(
    (newDeviceName: string) => {
      setDeviceDraftName(newDeviceName);
      handleUpdateDeviceName(newDeviceName);
    },
    [handleUpdateDeviceName],
  );

  const isValidNewTag = useCallback(
    (inputValue: string) => {
      const newTag = inputValue.trim().toLowerCase();
      return newTag !== "" && !deviceTags.some((tag) => tag.value === newTag);
    },
    [deviceTags],
  );

  const handleAddDeviceTags = useCallback((tags: string[]) => {
    addDeviceTags({
      variables: {
        deviceId,
        input: { tags },
      },
      onCompleted(data, errors) {
        if (errors) {
          handleAPIErrors(errors);
          return;
        }
        // TODO refresh tags only when adding unexisting tags
        refreshTags();
      },
      updater(store, data) {
        if (!data?.addDeviceTags?.result) {
          return;
        }

        const root = store.getRoot();
        const deviceGroups = root.getLinkedRecords("deviceGroups");
        if (!deviceGroups) {
          return;
        }

        const device = store
          .getRootField("addDeviceTags")
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
          if (!devices.some((device) => device.getDataID() === deviceId)) {
            deviceGroup.setLinkedRecords([...devices, device], "devices");
          }
        });
      },
    });
  }, []);

  const handleRemoveDeviceTags = useCallback((tags: string[]) => {
    removeDeviceTags({
      variables: {
        deviceId,
        input: { tags },
      },
      onCompleted(data, errors) {
        if (errors) {
          handleAPIErrors(errors);
          return;
        }
      },
      updater(store, data) {
        if (!data?.removeDeviceTags?.result) {
          return;
        }

        const root = store.getRoot();
        const deviceGroups = root.getLinkedRecords("deviceGroups");
        if (!deviceGroups) {
          return;
        }

        const device = store
          .getRootField("removeDeviceTags")
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
          if (!devices.some((device) => device.getDataID() === deviceId)) {
            deviceGroup.setLinkedRecords([...devices, device], "devices");
          }
        });
      },
    });
  }, []);

  const handleTagsChange = useCallback(
    (updatedTags: string[]) => {
      const previousTags = deviceTags.map((tag) => tag.value);
      const tagsToBeAdded = updatedTags.filter(
        (t) => !previousTags.includes(t),
      );
      const tagsToBeRemoved = previousTags.filter(
        (t) => !updatedTags.includes(t),
      );

      if (tagsToBeAdded.length > 0) {
        handleAddDeviceTags(tagsToBeAdded);
      }
      if (tagsToBeRemoved.length > 0) {
        handleRemoveDeviceTags(tagsToBeRemoved);
      }
    },
    [deviceTags],
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
                  src={device.systemModel?.pictureUrl || assets.images.devices}
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
                      value={deviceDraftName}
                      onChange={(e) => handleDeviceNameChange(e.target.value)}
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
                      onChange={(newTags) =>
                        handleTagsChange(newTags.map(({ value }) => value))
                      }
                      isValidNewOption={isValidNewTag}
                      onCreateOption={(inputValue) => {
                        const newTag = inputValue.trim().toLowerCase();
                        handleAddDeviceTags([newTag]);
                      }}
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
              "applications-tab",
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
            <DeviceSoftwareUpdateTab deviceRef={device} />
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

export { FormRow, FormValue, formatBytes };

export default DevicePage;
