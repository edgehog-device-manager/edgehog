// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
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

import { Col, Container, Row } from "react-bootstrap";
import {
  FieldErrors,
  UseFieldArrayReturn,
  UseFormRegister,
  Path,
} from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Icon from "@/components/Icon";
import FormFeedback from "@/forms/FormFeedback";
import { ContainerInputData } from "@/forms/validation";

type DeviceMapping = {
  pathInContainer: string;
  pathOnHost: string;
  cgroupPermissions: string;
};

type ReadOnlyFormInputProps = {
  deviceMappings: DeviceMapping[];
};

export type EditableFormInputProps = {
  deviceMappingsForm: UseFieldArrayReturn<
    ContainerInputData,
    "deviceMappings",
    "id"
  >;
  canAddDeviceMapping: boolean;
  errorFeedback: FieldErrors<ContainerInputData>;
  register: UseFormRegister<ContainerInputData>;
  removeDeviceMapping: (dmIndex: number) => void;
};

type DeviceMappingsFormInputProps = {
  readOnly?: boolean;
  editableProps: EditableFormInputProps | null;
  readOnlyProps: ReadOnlyFormInputProps | null;
};

const DeviceMappingsFormInput = ({
  readOnly = false,
  editableProps,
  readOnlyProps,
}: DeviceMappingsFormInputProps) => {
  const fields = editableProps?.deviceMappingsForm?.fields ?? [];

  const data: DeviceMapping[] = readOnly
    ? (readOnlyProps?.deviceMappings ?? [])
    : fields.map((f) => ({
        pathInContainer: f.pathInContainer ?? "",
        pathOnHost: f.pathOnHost ?? "",
        cgroupPermissions: f.cgroupPermissions ?? "",
      }));

  const registerField = (
    index: number,
    field: keyof DeviceMapping,
    value?: string,
  ) => {
    if (readOnly) {
      return { value: value ?? "" };
    }

    return editableProps?.register(
      `deviceMappings.${index}.${field}` as Path<ContainerInputData>,
    );
  };

  return (
    <>
      <Container fluid>
        {data.length > 0 && (
          <Row className="mb-3">
            <Col>
              <FormattedMessage
                id="components.DeviceMappingsFormInput.pathInContainerLabel"
                defaultMessage="Path In Container"
              />
            </Col>
            <Col>
              <FormattedMessage
                id="components.DeviceMappingsFormInput.pathOnHostLabel"
                defaultMessage="Path On Host"
              />
            </Col>
            <Col>
              <FormattedMessage
                id="components.DeviceMappingsFormInput.cgroupPermissionsLabel"
                defaultMessage="Container Group Permissions"
              />
            </Col>
            {!readOnly && <Col />}
          </Row>
        )}

        {data.map((deviceMapping, dmIndex) => {
          const errors =
            editableProps?.errorFeedback?.deviceMappings?.[dmIndex];

          return (
            <Row className="mb-3" key={`deviceMapping-${dmIndex}`}>
              <Col>
                <Form.Control
                  {...registerField(
                    dmIndex,
                    "pathInContainer",
                    deviceMapping.pathInContainer,
                  )}
                  placeholder="e.g., /dev/net/1"
                  isInvalid={!!errors?.pathInContainer}
                  readOnly={readOnly}
                />
                <FormFeedback feedback={errors?.pathInContainer?.message} />
              </Col>

              <Col>
                <Form.Control
                  {...registerField(
                    dmIndex,
                    "pathOnHost",
                    deviceMapping.pathOnHost,
                  )}
                  placeholder="e.g., /dev/net/1"
                  isInvalid={!!errors?.pathOnHost}
                  readOnly={readOnly}
                />
                <FormFeedback feedback={errors?.pathOnHost?.message} />
              </Col>

              <Col>
                <Form.Control
                  {...registerField(
                    dmIndex,
                    "cgroupPermissions",
                    deviceMapping.cgroupPermissions,
                  )}
                  placeholder="e.g., mrw"
                  isInvalid={!!errors?.cgroupPermissions}
                  readOnly={readOnly}
                />
                <FormFeedback feedback={errors?.cgroupPermissions?.message} />
              </Col>

              {!readOnly && (
                <Col>
                  <Button
                    variant="shadow-danger"
                    type="button"
                    onClick={() => editableProps?.removeDeviceMapping(dmIndex)}
                  >
                    <Icon className="text-danger" icon={"delete"} />
                  </Button>
                </Col>
              )}
            </Row>
          );
        })}
      </Container>

      {!readOnly && (
        <Button
          variant="outline-primary"
          onClick={() =>
            editableProps?.deviceMappingsForm?.append({
              pathOnHost: "",
              pathInContainer: "",
              cgroupPermissions: "",
            })
          }
          disabled={!editableProps?.canAddDeviceMapping}
        >
          <FormattedMessage
            id="components.DeviceMappingsFormInput.addDeviceMappingButton"
            defaultMessage="Add Device Mapping"
          />
        </Button>
      )}
    </>
  );
};

export default DeviceMappingsFormInput;
