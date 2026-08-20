// This file is part of Edgehog.
//
// Copyright 2021-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import debounce from "lodash/debounce";
import { ReactNode, useCallback, useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import {
  graphql,
  useFragment,
  useMutation,
  fetchQuery,
  useRelayEnvironment,
} from "react-relay/hooks";
import type { PayloadError } from "relay-runtime";
import { Card } from "react-bootstrap";
import { FormattedMessage } from "react-intl";

import type { DeviceInfoCard_device$key } from "@/api/__generated__/DeviceInfoCard_device.graphql";
import type { DeviceInfoCard_connectionStatus$key } from "@/api/__generated__/DeviceInfoCard_connectionStatus.graphql";
import type { DeviceInfoCard_getForwarderSession_Query } from "@/api/__generated__/DeviceInfoCard_getForwarderSession_Query.graphql";
import type { DeviceInfoCard_updateDevice_Mutation } from "@/api/__generated__/DeviceInfoCard_updateDevice_Mutation.graphql";
import type { DeviceInfoCard_addDeviceTags_Mutation } from "@/api/__generated__/DeviceInfoCard_addDeviceTags_Mutation.graphql";
import type { DeviceInfoCard_removeDeviceTags_Mutation } from "@/api/__generated__/DeviceInfoCard_removeDeviceTags_Mutation.graphql";
import type { DeviceInfoCard_requestForwarderSession_Mutation } from "@/api/__generated__/DeviceInfoCard_requestForwarderSession_Mutation.graphql";

import { Link, Route } from "@/Navigation";
import Alert from "@/components/ui/alert/Alert";
import Button from "@/components/ui/button/Button";
import ConnectionStatus from "@/components/fleet/devices/connection-status/ConnectionStatus";
import Col from "@/components/ui/col/Col";
import Figure from "@/components/ui/figure/Figure";
import Form from "@/components/ui/form/Form";
import FormValue from "@/components/ui/form-value/FormValue";
import { FormRow } from "@/components/ui/form-row/FormRow";
import LastSeen from "@/components/fleet/devices/last-seen/LastSeen";
import LedBehaviorDropdown from "@/components/fleet/devices/led-behavior-dropdown/LedBehaviorDropdown";
import MultiSelect from "@/components/ui/multi-select/MultiSelect";
import Row from "@/components/ui/row/Row";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import assets from "@/assets";

const DEVICE_INFO_CARD_FRAGMENT = graphql`
  fragment DeviceInfoCard_device on Device {
    id
    name
    deviceId
    serialNumber
    partNumber
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
    ...DeviceInfoCard_connectionStatus
  }
`;

const CONNECTION_STATUS_FRAGMENT = graphql`
  fragment DeviceInfoCard_connectionStatus on Device {
    online
    lastConnection
    lastDisconnection
  }
`;

const UPDATE_DEVICE_MUTATION = graphql`
  mutation DeviceInfoCard_updateDevice_Mutation(
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
  mutation DeviceInfoCard_addDeviceTags_Mutation(
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
  mutation DeviceInfoCard_removeDeviceTags_Mutation(
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

const REQUEST_FORWARDER_SESSION_MUTATION = graphql`
  mutation DeviceInfoCard_requestForwarderSession_Mutation(
    $input: RequestForwarderSessionInput!
  ) {
    requestForwarderSession(input: $input)
  }
`;

const GET_FORWARDER_SESSION_QUERY = graphql`
  query DeviceInfoCard_getForwarderSession_Query(
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

const FORM_ROW = { labelCol: 3, valueCol: 9 };

interface DeviceInfoCardProps {
  deviceRef: DeviceInfoCard_device$key;
  tags?: { label: string; value: string }[];
  refreshTags: () => void;
  isForwarderSupported: boolean;
  onError: (feedback: ReactNode) => void;
}

interface DeviceConnectionFormRowsProps {
  deviceRef: DeviceInfoCard_connectionStatus$key;
}

const DeviceConnectionFormRows = ({
  deviceRef,
}: DeviceConnectionFormRowsProps) => {
  const { online, lastConnection, lastDisconnection } = useFragment(
    CONNECTION_STATUS_FRAGMENT,
    deviceRef,
  );

  return (
    <>
      <FormRow
        id="form-device-connection-status"
        label={
          <FormattedMessage
            id="components.fleet.devices.device-info-card.DeviceInfoCard.connectionStatus"
            defaultMessage="Connection"
          />
        }
        {...FORM_ROW}
      >
        <FormValue>
          <ConnectionStatus connected={online} />
        </FormValue>
      </FormRow>
      <FormRow
        id="form-device-last-seen"
        label={
          <FormattedMessage
            id="components.fleet.devices.device-info-card.DeviceInfoCard.lastSeen"
            defaultMessage="Last seen"
          />
        }
        {...FORM_ROW}
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
    new Promise((_resolve, reject) => setTimeout(() => reject(), millis)),
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

const DeviceInfoCard = ({
  deviceRef,
  tags,
  refreshTags,
  isForwarderSupported,
  onError,
}: DeviceInfoCardProps) => {
  const { deviceId = "" } = useParams();
  const relayEnvironment = useRelayEnvironment();
  const [isOpeningRemoteTerminal, setIsOpeningRemoteTerminal] = useState(false);
  const [remoteTerminalErrorFeedback, setRemoteTerminalErrorFeedback] =
    useState<ReactNode>(null);

  const device = useFragment(DEVICE_INFO_CARD_FRAGMENT, deviceRef);

  const [deviceDraftName, setDeviceDraftName] = useState(device.name || "");

  const deviceTags = useMemo(
    () =>
      device.tags?.edges?.map(({ node: { name: tag } }) => ({
        label: tag,
        value: tag,
      })) || [],
    [device.tags],
  );

  const handleAPIErrors = useCallback(
    (errors: PayloadError[]) => {
      const errorFeedback = errors
        .map(({ fields, message }) =>
          fields.length ? `${fields.join(" ")} ${message}` : message,
        )
        .join(". \n");
      onError(errorFeedback);
    },
    [onError],
  );

  const [requestForwarderSession, isRequestingForwarderSession] =
    useMutation<DeviceInfoCard_requestForwarderSession_Mutation>(
      REQUEST_FORWARDER_SESSION_MUTATION,
    );

  const handleOpenRemoteTerminal = useCallback(
    async (sessionToken: string) => {
      const data = await fetchQuery<DeviceInfoCard_getForwarderSession_Query>(
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
                id="components.fleet.devices.device-info-card.DeviceInfoCard.openRemoteTerminalErrorFeedback"
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
        onError(
          <FormattedMessage
            id="components.fleet.devices.device-info-card.DeviceInfoCard.openRemoteTerminalErrorFeedback"
            defaultMessage="Could not access the remote terminal, please try again."
            description="Feedback for unknown error while opening a remote terminal session"
          />,
        );
      },
    });
  }, [
    requestForwarderSession,
    handleOpenRemoteTerminal,
    deviceId,
    handleAPIErrors,
    onError,
  ]);

  const [updateDevice] = useMutation<DeviceInfoCard_updateDevice_Mutation>(
    UPDATE_DEVICE_MUTATION,
  );
  const [addDeviceTags] = useMutation<DeviceInfoCard_addDeviceTags_Mutation>(
    ADD_DEVICE_TAGS_MUTATION,
  );
  const [removeDeviceTags] =
    useMutation<DeviceInfoCard_removeDeviceTags_Mutation>(
      REMOVE_DEVICE_TAGS_MUTATION,
    );

  const handleUpdateDeviceName = useMemo(
    () =>
      debounce(
        (newDeviceName: string) => {
          updateDevice({
            variables: { deviceId, input: { name: newDeviceName } },
            onCompleted(_data, errors) {
              if (errors) {
                handleAPIErrors(errors);
                return;
              }
            },
            onError() {
              onError(
                <FormattedMessage
                  id="components.fleet.devices.device-info-card.DeviceInfoCard.updateDeviceErrorFeedback"
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
    [updateDevice, deviceId, handleAPIErrors, onError],
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

  const handleAddDeviceTags = useCallback(
    (tagsToAdd: string[]) => {
      addDeviceTags({
        variables: {
          deviceId,
          input: { tags: tagsToAdd },
        },
        onCompleted(_data, errors) {
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
    },
    [addDeviceTags, deviceId, handleAPIErrors, refreshTags],
  );

  const handleRemoveDeviceTags = useCallback(
    (tagsToRemove: string[]) => {
      removeDeviceTags({
        variables: {
          deviceId,
          input: { tags: tagsToRemove },
        },
        onCompleted(_data, errors) {
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
    },
    [deviceId, removeDeviceTags, handleAPIErrors],
  );

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
    [deviceTags, handleAddDeviceTags, handleRemoveDeviceTags],
  );

  const isRemoteTerminalSupported =
    isForwarderSupported && device.capabilities.includes("REMOTE_TERMINAL");

  return (
    <Card className="h-100 border-0 p-3 shadow-sm mb-2">
      <Row>
        <Col md="7" lg="8" xl="9">
          <Form className="ms-3">
            <Stack gap={3}>
              <FormRow
                id="form-device-name"
                label={
                  <FormattedMessage
                    id="components.fleet.devices.device-info-card.DeviceInfoCard.name"
                    defaultMessage="Name"
                  />
                }
                {...FORM_ROW}
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
                    id="components.fleet.devices.device-info-card.DeviceInfoCard.tags"
                    defaultMessage="Tags"
                  />
                }
                {...FORM_ROW}
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
                    id="components.fleet.devices.device-info-card.DeviceInfoCard.deviceId"
                    defaultMessage="Device ID"
                  />
                }
                {...FORM_ROW}
              >
                {device.deviceId}
              </FormRow>
              {device.serialNumber && (
                <FormRow
                  id="form-device-serialNumber"
                  label={
                    <FormattedMessage
                      id="components.fleet.devices.device-info-card.DeviceInfoCard.serialNumber"
                      defaultMessage="Serial Number"
                    />
                  }
                  {...FORM_ROW}
                >
                  {device.serialNumber}
                </FormRow>
              )}
              {device.partNumber && (
                <FormRow
                  id="device-hardware-info-part-number"
                  label={
                    <FormattedMessage
                      id="components.fleet.devices.device-info-card.DeviceInfoCard.partNumber"
                      defaultMessage="Part Number"
                    />
                  }
                  {...FORM_ROW}
                >
                  {device.partNumber}
                </FormRow>
              )}
              {device.systemModel && (
                <>
                  <FormRow
                    id="form-device-system-model"
                    label={
                      <FormattedMessage
                        id="components.fleet.devices.device-info-card.DeviceInfoCard.systemModel"
                        defaultMessage="System Model"
                      />
                    }
                    {...FORM_ROW}
                  >
                    {device.systemModel.name}
                  </FormRow>
                  <FormRow
                    id="form-device-hardware-type"
                    label={
                      <FormattedMessage
                        id="components.fleet.devices.device-info-card.DeviceInfoCard.hardwareType"
                        defaultMessage="Hardware Type"
                      />
                    }
                    {...FORM_ROW}
                  >
                    {device.systemModel.hardwareType?.name}
                  </FormRow>
                </>
              )}
              <FormRow
                id="form-device-deviceGroups"
                label={
                  <FormattedMessage
                    id="components.fleet.devices.device-info-card.DeviceInfoCard.groups"
                    defaultMessage="Groups"
                  />
                }
                {...FORM_ROW}
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
                      id="components.fleet.devices.device-info-card.DeviceInfoCard.checkMyDevice"
                      defaultMessage="Check my Device"
                    />
                  }
                  {...FORM_ROW}
                >
                  <LedBehaviorDropdown
                    deviceId={device.id}
                    disabled={!device.online}
                    onError={onError}
                  />
                </FormRow>
              )}
              {isRemoteTerminalSupported && (
                <FormRow
                  id="form-device-open-remote-terminal"
                  label={
                    <FormattedMessage
                      id="components.fleet.devices.device-info-card.DeviceInfoCard.remoteTerminal.label"
                      defaultMessage="Remote Terminal"
                    />
                  }
                  {...FORM_ROW}
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
                        id="components.fleet.devices.device-info-card.DeviceInfoCard.remoteTerminal.openTerminalButton"
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
        <Col md="5" lg="4" xl="3">
          <Figure
            alt={device.name}
            src={device.systemModel?.pictureUrl || assets.images.devices}
          />
        </Col>
      </Row>
    </Card>
  );
};

export default DeviceInfoCard;
