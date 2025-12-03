/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { Col, Container, Row } from "react-bootstrap";
import {
  FieldErrors,
  UseFieldArrayReturn,
  UseFormRegister,
} from "react-hook-form";
import { FormattedMessage } from "react-intl";

import { ContainersTable_ContainerFragment$data } from "@/api/__generated__/ContainersTable_ContainerFragment.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Icon from "@/components/Icon";
import { ReleaseInputData } from "@/forms/CreateRelease";

type DeviceMappingsData = NonNullable<
  ContainersTable_ContainerFragment$data["containers"]["edges"]
>[number]["node"]["deviceMappings"];

type ReadOnlyFormInputProps = {
  deviceMappings: DeviceMappingsData;
};

type EditableFormInputProps = {
  containerIndex: number;
  deviceMappingsForm: UseFieldArrayReturn<
    ReleaseInputData,
    `containers.${number}.deviceMappings`,
    "id"
  >;
  canAddDeviceMapping: boolean;
  errorFeedback: FieldErrors<ReleaseInputData>;
  register: UseFormRegister<ReleaseInputData>;
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
  const otherFormControlFields = (
    dmProp: "pathInContainer" | "pathOnHost" | "cgroupPermissions",
    dmIndex: number,
    value?: string,
  ) => {
    return readOnly
      ? {
          value: value ?? "",
        }
      : {
          ...editableProps?.register(
            `containers.${editableProps.containerIndex}.deviceMappings.${dmIndex}.${dmProp}` as const,
          ),
        };
  };

  const data = readOnly
    ? readOnlyProps?.deviceMappings.edges?.map((edge) => edge.node)
    : editableProps?.deviceMappingsForm?.fields;

  return (
    <>
      <Container fluid>
        {(editableProps?.deviceMappingsForm?.fields?.length ||
          readOnlyProps?.deviceMappings?.edges?.length) && (
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
            {!readOnly && <Col></Col>}
          </Row>
        )}

        {data?.map((deviceMapping, dmIndex) => {
          const fieldErrors = readOnly
            ? null
            : editableProps?.errorFeedback?.containers?.[
                editableProps?.containerIndex
              ]?.deviceMappings?.[dmIndex];

          return (
            <Row className="mb-3" key={`deviceMapping-${dmIndex}`}>
              <Col>
                <Form.Control
                  {...otherFormControlFields(
                    "pathInContainer",
                    dmIndex,
                    deviceMapping?.pathInContainer,
                  )}
                  placeholder="e.g., /dev/net/1"
                  isInvalid={!!fieldErrors?.pathInContainer}
                  readOnly={readOnly}
                />
                <Form.Control.Feedback type="invalid">
                  {fieldErrors?.pathInContainer?.message && (
                    <FormattedMessage
                      id={fieldErrors.pathInContainer.message}
                    />
                  )}
                </Form.Control.Feedback>
              </Col>
              <Col>
                <Form.Control
                  {...otherFormControlFields(
                    "pathOnHost",
                    dmIndex,
                    deviceMapping?.pathOnHost,
                  )}
                  placeholder="e.g., /dev/net/1"
                  isInvalid={!!fieldErrors?.pathOnHost}
                  readOnly={readOnly}
                />
                <Form.Control.Feedback type="invalid">
                  {fieldErrors?.pathOnHost?.message && (
                    <FormattedMessage id={fieldErrors.pathOnHost.message} />
                  )}
                </Form.Control.Feedback>
              </Col>
              <Col>
                <Form.Control
                  {...otherFormControlFields(
                    "cgroupPermissions",
                    dmIndex,
                    deviceMapping?.cgroupPermissions,
                  )}
                  placeholder="e.g., mrw"
                  isInvalid={!!fieldErrors?.cgroupPermissions}
                  readOnly={readOnly}
                />
                <Form.Control.Feedback type="invalid">
                  {fieldErrors?.cgroupPermissions?.message && (
                    <FormattedMessage
                      id={fieldErrors.cgroupPermissions.message}
                    />
                  )}
                </Form.Control.Feedback>
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
