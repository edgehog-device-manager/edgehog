/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind

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

import { Suspense, useEffect, useMemo } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useFragment,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import type { Device_hardwareInfo$key } from "api/__generated__/Device_hardwareInfo.graphql";
import type { Device_getDevice_Query } from "api/__generated__/Device_getDevice_Query.graphql";
import { Link, Route } from "Navigation";
import Center from "components/Center";
import ConnectionStatus from "components/ConnectionStatus";
import Col from "components/Col";
import Figure from "components/Figure";
import Form from "components/Form";
import Page from "components/Page";
import Result from "components/Result";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";

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

const GET_DEVICE_QUERY = graphql`
  query Device_getDevice_Query($id: ID!) {
    device(id: $id) {
      id
      deviceId
      name
      ...Device_hardwareInfo
    }
  }
`;

const FormRow: (params: {
  id: string;
  label: JSX.Element;
  children: JSX.Element;
}) => JSX.Element = ({ id, label, children }) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

const FormValue = (params: { children: React.ReactNode }) => {
  return <div className="h-100 py-2">{params.children}</div>;
};

const formatBytes = (bytes: number, decimals = 2) => {
  if (bytes === 0) return "0 Bytes";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
};

interface DeviceHardwareInfoProps {
  deviceRef: Device_hardwareInfo$key;
}

const DeviceHardwareInfo = ({ deviceRef }: DeviceHardwareInfoProps) => {
  const { hardwareInfo } = useFragment(
    DEVICE_HARDWARE_INFO_FRAGMENT,
    deviceRef
  );
  if (!hardwareInfo) {
    return null;
  }
  return (
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
          <Form.Control type="text" value={hardwareInfo.cpuModel} readOnly />
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
          <Form.Control type="text" value={hardwareInfo.cpuVendor} readOnly />
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
  );
};

interface DeviceContentProps {
  getDeviceQuery: PreloadedQuery<Device_getDevice_Query>;
}

const DeviceContent = ({ getDeviceQuery }: DeviceContentProps) => {
  const deviceData = usePreloadedQuery(GET_DEVICE_QUERY, getDeviceQuery);

  // TODO: handle readonly type without mapping to mutable type
  const device = useMemo(
    () =>
      deviceData.device && {
        ...deviceData.device,
        online: true,
      },
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
        <Row>
          <Col sm="4" lg="3">
            <div>
              <Figure alt={device.name} />
            </div>
          </Col>
          <Col sm="8" lg="9">
            <Form className="ms-3">
              <Stack gap={3}>
                <FormRow
                  id="form-device-name"
                  label={
                    <FormattedMessage id="Device.name" defaultMessage="Name" />
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
                  <Form.Control type="text" value={device.deviceId} readOnly />
                </FormRow>
                <DeviceHardwareInfo deviceRef={device} />
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
              </Stack>
            </Form>
          </Col>
        </Row>
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
