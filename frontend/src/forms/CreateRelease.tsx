/*
  This file is part of Edgehog.

  Copyright 2024 - 2025 SECO Mind Srl

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

import React, { useState, useRef } from "react";
import { useForm, useFieldArray, Controller, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment, useLazyLoadQuery } from "react-relay/hooks";
import type { Control, FieldErrors, UseFormRegister } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";

import type { CreateRelease_ImageCredentialsOptionsFragment$key } from "api/__generated__/CreateRelease_ImageCredentialsOptionsFragment.graphql";
import type { CreateRelease_NetworksOptionsFragment$key } from "api/__generated__/CreateRelease_NetworksOptionsFragment.graphql";
import type { CreateRelease_VolumesOptionsFragment$key } from "api/__generated__/CreateRelease_VolumesOptionsFragment.graphql";
import type { CreateRelease_SystemModelsOptionsFragment$key } from "api/__generated__/CreateRelease_SystemModelsOptionsFragment.graphql";
import {
  ContainerCreateWithNestedDeviceMappingsInput,
  ContainerCreateWithNestedNetworksInput,
  ContainerCreateWithNestedVolumesInput,
  ReleaseCreateRequiredSystemModelsInput,
} from "api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import type {
  CreateRelease_getApplicationsWithReleases_Query,
  CreateRelease_getApplicationsWithReleases_Query$data,
} from "api/__generated__/CreateRelease_getApplicationsWithReleases_Query.graphql";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import Alert from "components/Alert";
import Tag from "components/Tag";
import {
  yup,
  envSchema,
  portBindingsSchema,
  tmpfsOptSchema,
  storageOptSchema,
  extraHostsSchema,
  optionalNumberSchema,
  messages,
} from "forms/index";
import MultiSelect from "components/MultiSelect";
import Select, { SingleValue } from "react-select";
import Icon from "components/Icon";
import MonacoJsonEditor from "components/MonacoJsonEditor";
import ConfirmModal from "components/ConfirmModal";
import FormFeedback from "forms/FormFeedback";
import DeviceMappingsFormInput from "components/DeviceMappingsFormInput";

import type { KeyValue } from "forms/index";

const IMAGE_CREDENTIALS_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_ImageCredentialsOptionsFragment on RootQueryType {
    listImageCredentials {
      edges {
        node {
          id
          label
          username
        }
      }
    }
  }
`;

const NETWORKS_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_NetworksOptionsFragment on RootQueryType {
    networks {
      edges {
        node {
          id
          label
        }
      }
    }
  }
`;

const VOLUMES_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_VolumesOptionsFragment on RootQueryType {
    volumes {
      edges {
        node {
          id
          label
        }
      }
    }
  }
`;

const SYSTEM_MODELS_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_SystemModelsOptionsFragment on RootQueryType {
    systemModels {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

const GET_APPLICATIONS_WITH_RELEASES_QUERY = graphql`
  query CreateRelease_getApplicationsWithReleases_Query {
    applications {
      edges {
        node {
          id
          name
          releases {
            edges {
              node {
                id
                version
                systemModels {
                  id
                  name
                }
                containers {
                  edges {
                    node {
                      id
                      env {
                        key
                        value
                      }
                      extraHosts
                      hostname
                      networkMode
                      restartPolicy
                      privileged
                      portBindings
                      cpuPeriod
                      cpuQuota
                      cpuRealtimePeriod
                      cpuRealtimeRuntime
                      memory
                      memorySwap
                      memorySwappiness
                      capAdd
                      capDrop
                      storageOpt
                      tmpfs
                      memoryReservation
                      readOnlyRootfs
                      volumeDriver
                      image {
                        reference
                        credentials {
                          id
                        }
                      }
                      networks {
                        edges {
                          node {
                            id
                            label
                          }
                        }
                      }
                      containerVolumes {
                        edges {
                          node {
                            target
                            volume {
                              id
                              label
                            }
                          }
                        }
                      }
                      deviceMappings {
                        edges {
                          node {
                            id
                            pathInContainer
                            pathOnHost
                            cgroupPermissions
                          }
                        }
                      }
                    }
                  }
                }
                systemModels {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }
  }
`;

type ApplicationsData = NonNullable<
  CreateRelease_getApplicationsWithReleases_Query$data["applications"]
>;

type ApplicationResult = NonNullable<ApplicationsData["edges"]>[number];

type ReleasesData = NonNullable<ApplicationResult["node"]["releases"]>;
type ReleaseEdge = NonNullable<NonNullable<ReleasesData["edges"]>[number]>;

type ReleaseNode = NonNullable<ReleaseEdge["node"]>;

const NetworksErrors = ({ errors }: { errors: unknown }) => {
  if (errors == null) {
    return null;
  }
  if (typeof errors === "object" && !Array.isArray(errors)) {
    if (
      "message" in errors &&
      typeof (errors as Record<"message", unknown>).message === "string"
    ) {
      const message = (errors as Record<"message", string>).message;
      return <FormattedMessage id={message} />;
    }
  }
  return null;
};

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

type ReleaseContainerNode = NonNullable<
  ReleaseNode["containers"]["edges"]
>[number]["node"];
type EnvironmentVariable = NonNullable<ReleaseContainerNode["env"]>[number] &
  KeyValue<string>;

type ContainerInput = {
  cpuPeriod?: number;
  cpuQuota?: number;
  cpuRealtimePeriod?: number;
  cpuRealtimeRuntime?: number;
  extraHosts?: string[];
  env?: EnvironmentVariable[];
  hostname?: string;
  image: {
    reference: string;
    imageCredentialsId?: string;
  }; // ContainerCreateWithNestedImageInput
  memory?: number;
  memoryReservation?: number;
  memorySwap?: number;
  memorySwappiness?: number;
  networkMode?: string;
  networks?: ContainerCreateWithNestedNetworksInput[];
  portBindings?: string;
  privileged?: boolean;
  readOnlyRootfs?: boolean;
  restartPolicy?: string;
  storageOpt?: string;
  tmpfs?: string;
  capAdd?: string[];
  capDrop?: string[];
  volumeDriver?: string;
  volumes?: ContainerCreateWithNestedVolumesInput[];
  deviceMappings?: ContainerCreateWithNestedDeviceMappingsInput[];
};

export type ReleaseInputData = {
  version: string;
  containers?: ContainerInput[] | null;
  requiredSystemModels: ReleaseCreateRequiredSystemModelsInput[];
};

type ReleaseSubmitData = {
  version: string;
  containers?: ContainerSubmit[] | null;
  requiredSystemModels: ReleaseCreateRequiredSystemModelsInput[];
};

type ContainerSubmit = Omit<
  ContainerInput,
  "portBindings" | "tmpfs" | "storageOpt"
> & {
  portBindings?: string[];
  tmpfs?: string[];
  storageOpt?: string[];
};

export const CapDropList = [
  "CAP_AUDIT_WRITE",
  "CAP_CHOWN",
  "CAP_DAC_OVERRIDE",
  "CAP_FOWNER",
  "CAP_FSETID",
  "CAP_KILL",
  "CAP_MKNOD",
  "CAP_NET_BIND_SERVICE",
  "CAP_NET_RAW",
  "CAP_SETFCAP",
  "CAP_SETGID",
  "CAP_SETPCAP",
  "CAP_SETUID",
  "CAP_SYS_CHROOT",
] as const;

export const CapAddList = [
  "CAP_AUDIT_CONTROL",
  "CAP_BLOCK_SUSPEND",
  "CAP_DAC_READ_SEARCH",
  "CAP_IPC_LOCK",
  "CAP_IPC_OWNER",
  "CAP_LEASE",
  "CAP_LINUX_IMMUTABLE",
  "CAP_MAC_ADMIN",
  "CAP_MAC_OVERRIDE",
  "CAP_NET_ADMIN",
  "CAP_NET_BROADCAST",
  "CAP_SYS_ADMIN",
  "CAP_SYS_BOOT",
  "CAP_SYS_MODULE",
  "CAP_SYS_NICE",
  "CAP_SYS_PACCT",
  "CAP_SYS_PTRACE",
  "CAP_SYS_RAWIO",
  "CAP_SYS_RESOURCE",
  "CAP_SYS_TIME",
  "CAP_SYS_TTY_CONFIG",
  "CAP_SYSLOG",
  "CAP_WAKE_ALARM",
] as const;

// Yup schema for form validation
const applicationSchema = (intl: any) =>
  yup
    .object({
      version: yup.string().required(),
      containers: yup
        .array(
          yup.object({
            env: envSchema,
            extraHosts: extraHostsSchema,
            image: yup.object({
              reference: yup.string().required(),
              imageCredentialsId: yup.string().nullable(),
            }),
            hostname: yup
              .string()
              .nullable()
              .transform((value) => value?.trim()),
            privileged: yup.boolean().nullable(),
            restartPolicy: yup
              .string()
              .nullable()
              .transform((value) => value?.trim()),
            networkMode: yup
              .string()
              .nullable()
              .transform((value) => value?.trim()),
            portBindings: portBindingsSchema,
            memory: optionalNumberSchema
              .min(6 * 1024 * 1024)
              .integer()
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.memoryLabel",
                  defaultMessage: "Memory (bytes)",
                }),
              ),

            memoryReservation: optionalNumberSchema
              .integer()
              .min(0)
              .max(yup.ref("memory"))
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.memoryReservationLabel",
                  defaultMessage: "Memory Reservation (bytes)",
                }),
              ),
            memorySwap: optionalNumberSchema
              .integer()
              .test(
                "memorySwap-valid",
                intl.formatMessage({
                  id: "forms.CreateRelease.memorySwapInvalid",
                  defaultMessage:
                    "Memory Swap must be greater than/equal to Memory.",
                }),
                function (value) {
                  const memory = this.parent.memory;
                  if (
                    value === undefined ||
                    value === null ||
                    memory === undefined ||
                    memory === null
                  ) {
                    return true;
                  }
                  return value >= memory;
                },
              )
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.memorySwapLabel",
                  defaultMessage: "Memory Swap (bytes)",
                }),
              ),
            memorySwappiness: optionalNumberSchema
              .integer()
              .min(0)
              .max(100)
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.memorySwappinessLabel",
                  defaultMessage: "Memory Swappiness (0-100)",
                }),
              ),
            cpuPeriod: optionalNumberSchema
              .integer()
              .min(1_000)
              .max(1_000_000)
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.cpuPeriodLabel",
                  defaultMessage: "CPU Period (microseconds)",
                }),
              ),
            cpuQuota: optionalNumberSchema
              .integer()
              .min(1_000)
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.cpuQuotaLabel",
                  defaultMessage: "CPU Quota (microseconds)",
                }),
              )
              .test({
                name: "cpuQuotaPeriod",
                message: messages.cpuQuotaPeriod.id,
                test: function (cpuQuota) {
                  const { cpuPeriod } = this.parent;
                  const bothEmpty = cpuQuota == null && cpuPeriod == null;
                  const bothSet = cpuQuota != null && cpuPeriod != null;
                  return bothEmpty || bothSet;
                },
              }),
            cpuRealtimePeriod: optionalNumberSchema
              .integer()
              .min(1000)
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.cpuRealtimePeriodLabel",
                  defaultMessage: "CPU Real-Time Period (microseconds)",
                }),
              ),
            cpuRealtimeRuntime: optionalNumberSchema
              .integer()
              .max(yup.ref("cpuRealtimePeriod"))
              .nullable()
              .label(
                intl.formatMessage({
                  id: "forms.CreateRelease.cpuRealtimeRuntimeLabel",
                  defaultMessage: "CPU Real-Time Runtime (microseconds)",
                }),
              ),

            readOnlyRootfs: yup.boolean().nullable(),
            storageOpt: storageOptSchema,
            tmpfs: tmpfsOptSchema,
            capAdd: yup
              .array()
              .of(yup.string().required().oneOf(CapAddList))
              .nullable(),
            capDrop: yup
              .array()
              .of(yup.string().required().oneOf(CapDropList))
              .nullable(),
            volumeDriver: yup
              .string()
              .nullable()
              .transform((value) => value?.trim()),
            networks: yup
              .array(
                yup
                  .object({
                    id: yup.string(),
                  })
                  .required(),
              )
              .nullable(),
            volumes: yup
              .array(
                yup
                  .object({
                    id: yup.string(),
                    target: yup.string().required(),
                  })
                  .required(),
              )
              .distinctOnProperty("target")
              .nullable(),
            deviceMappings: yup
              .array(
                yup
                  .object({
                    pathInContainer: yup
                      .string()
                      .transform((value) => value?.trim())
                      .required(),
                    pathOnHost: yup
                      .string()
                      .transform((value) => value?.trim())
                      .required(),
                    cgroupPermissions: yup
                      .string()
                      .transform((value) => value?.trim())
                      .required(),
                  })
                  .required(),
              )
              .nullable(),
          }),
        )
        .nullable(),
      requiredSystemModels: yup.array(
        yup.object({ id: yup.string().required() }),
      ),
    })
    .required();

const initialData: ReleaseInputData = {
  version: "",
  containers: null,
  requiredSystemModels: [],
};

export const restartPolicyOptions = [
  { value: "no", label: "No" },
  { value: "always", label: "Always" },
  { value: "on_failure", label: "On Failure" },
  { value: "unless_stopped", label: "Unless Stopped" },
];

type Option = {
  value: string;
  label: string;
};

type CreateReleaseProps = {
  imageCredentialsOptionsRef: CreateRelease_ImageCredentialsOptionsFragment$key;
  networksOptionsRef: CreateRelease_NetworksOptionsFragment$key;
  volumesOptionsRef: CreateRelease_VolumesOptionsFragment$key;
  requiredSystemModelsOptionsRef: CreateRelease_SystemModelsOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ReleaseSubmitData) => void;
  showModal?: boolean;
  onToggleModal?: (show: boolean) => void;
};

type ContainerFormProps = {
  index: number;
  register: UseFormRegister<ReleaseInputData>;
  errors: FieldErrors<ReleaseInputData>;
  remove: (index: number) => void;
  imageCredentials: Option[];
  networks: Option[];
  volumes: Option[];
  control: Control<ReleaseInputData>;
  isImported?: boolean;
  isModified?: boolean;
  markUserInteraction: () => void;
};

const reduceEnv = (env: EnvironmentVariable[]) =>
  env.reduce((acc: any, envVar: EnvironmentVariable) => {
    envVar ? (acc[envVar.key] = envVar.value) : acc;
    return acc;
  }, {});
const envToString = (env: EnvironmentVariable[]) =>
  JSON.stringify(reduceEnv(env));

const envValidation = (envJson: any): void => {
  if (Array.isArray(envJson)) {
    throw new TypeError("expected an object, found: 'array'");
  }
  const entries = Object.entries(envJson);
  entries.forEach(([key, value]) => {
    const valueType = typeof value;
    if (valueType !== "string") {
      throw new TypeError(
        `the value of an environment variable can only be a string. Found '${Array.isArray(value) ? "array" : valueType}' for key: '${key}'`,
      );
    }
  });
};

const ContainerForm = ({
  index,
  register,
  errors,
  remove,
  imageCredentials,
  networks,
  volumes,
  control,
  isImported = false,
  isModified = false,
  markUserInteraction,
}: ContainerFormProps) => {
  const volumesForm = useFieldArray({
    control,
    name: `containers.${index}.volumes`,
    keyName: "id",
  });
  const volumesValues: ContainerCreateWithNestedVolumesInput[] =
    useWatch({
      control,
      name: `containers.${index}.volumes`,
    }) ?? [];

  const canAddVolume = volumesValues.every(
    (v) => v.id?.trim() && v.target?.trim(),
  );

  const deviceMappingsForm = useFieldArray({
    control,
    name: `containers.${index}.deviceMappings`,
    keyName: "id",
  });

  const deviceMappingsValues: ContainerCreateWithNestedDeviceMappingsInput[] =
    useWatch({
      control,
      name: `containers.${index}.deviceMappings`,
    }) ?? [];

  const canAddDeviceMapping = deviceMappingsValues.every(
    (dm) =>
      dm.pathInContainer?.trim() &&
      dm.pathOnHost?.trim() &&
      dm.cgroupPermissions?.trim(),
  );

  const dmFormInputProps = {
    containerIndex: index,
    deviceMappingsForm: deviceMappingsForm,
    canAddDeviceMapping: canAddDeviceMapping,
    errorFeedback: errors,
    register: register,
    removeDeviceMapping: (dmIndex: number) =>
      deviceMappingsForm.remove(dmIndex),
  };

  return (
    <div className="border p-3 mb-3">
      <h5 className="d-flex align-items-center gap-2">
        <FormattedMessage
          id="forms.CreateRelease.containerTitle"
          defaultMessage="Container {containerNumber}"
          values={{ containerNumber: index + 1 }}
        />
        {isImported && (
          <Tag className="bg-secondary">
            <FormattedMessage
              id="forms.CreateRelease.importedLabel"
              defaultMessage="Imported"
            />
          </Tag>
        )}
        {isModified && (
          <Tag className="bg-secondary">
            <FormattedMessage
              id="forms.CreateRelease.modifiedLabel"
              defaultMessage="Modified"
            />
          </Tag>
        )}
      </h5>
      <Stack gap={2}>
        <FormRow
          id={`containers-${index}-env`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.envLabel"
              defaultMessage="Environment (JSON String)"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.env`}
            render={({ field, fieldState: _fieldState }) => (
              <MonacoJsonEditor
                value={
                  field.value && typeof field.value !== "string"
                    ? envToString(field.value)
                    : field.value ?? ""
                }
                onChange={(value) => {
                  field.onChange(value ?? "");
                  markUserInteraction();
                }}
                defaultValue={
                  field.value && typeof field.value !== "string"
                    ? envToString(field.value)
                    : field.value ?? "{}"
                }
                additionalValidation={envValidation}
              />
            )}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-extraHosts`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.extraHostsLabel"
              defaultMessage="Extra Hosts"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.extraHosts`}
            render={({ field }) => {
              const extraHosts = field.value || [];

              const handleAddExtraHost = () => {
                field.onChange([...extraHosts, ""]);
                markUserInteraction();
              };

              const handleDeleteExtraHost = (i: number) => {
                field.onChange(extraHosts.filter((_, idx) => idx !== i));
                markUserInteraction();
              };

              const handleChangeHost = (i: number, value: string) => {
                const updated = [...extraHosts];
                updated[i] = value;
                field.onChange(updated);
                markUserInteraction();
              };

              return (
                <div className="p-3 mb-3 bg-light border rounded">
                  <Stack gap={3}>
                    {extraHosts.map((host, i) => {
                      const hostError =
                        errors.containers?.[index]?.extraHosts?.[i]?.message;

                      return (
                        <Stack direction="horizontal" gap={3} key={i}>
                          <Stack>
                            <Form.Control
                              value={host}
                              onChange={(e) =>
                                handleChangeHost(i, e.target.value)
                              }
                              isInvalid={!!hostError}
                              placeholder="e.g., myhost:127.0.0.1"
                            />
                            <Form.Control.Feedback type="invalid">
                              {errors.containers?.[index]?.extraHosts?.[i]
                                ?.message && (
                                <FormattedMessage
                                  id={
                                    errors.containers[index].extraHosts[i]
                                      .message
                                  }
                                />
                              )}
                            </Form.Control.Feedback>
                          </Stack>
                          <Button
                            className="mb-auto"
                            variant="shadow-danger"
                            onClick={() => handleDeleteExtraHost(i)}
                          >
                            <Icon className="text-danger" icon={"delete"} />
                          </Button>
                        </Stack>
                      );
                    })}
                    <Button
                      className="me-auto"
                      variant="outline-primary"
                      onClick={handleAddExtraHost}
                    >
                      <FormattedMessage
                        id="forms.CreateRelease.addExtraHostButton"
                        defaultMessage="Add Extra Host"
                      />
                    </Button>
                  </Stack>
                </div>
              );
            }}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-image-reference`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.imageReferenceLabel"
              defaultMessage="Image Reference"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.image.reference` as const)}
            isInvalid={!!errors.containers?.[index]?.image?.reference}
            placeholder="e.g., my-image:latest"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.image?.reference?.message && (
              <FormattedMessage
                id={errors.containers[index].image.reference.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-image-credentials`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.imageCredentialsLabel"
              defaultMessage="Image Credentials"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.image.imageCredentialsId`}
            render={({ field }) => {
              const selectedOption =
                imageCredentials.find((opt) => opt.value === field.value) ||
                null;

              return (
                <Select
                  value={selectedOption}
                  onChange={(option) => {
                    field.onChange(option ? option.value : null);
                    markUserInteraction();
                  }}
                  options={imageCredentials}
                  isClearable
                />
              );
            }}
          />

          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.image?.imageCredentialsId?.message && (
              <FormattedMessage
                id={errors.containers[index].image.imageCredentialsId.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-hostname`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.hostnameLabel"
              defaultMessage="Hostname"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.hostname` as const)}
            isInvalid={!!errors.containers?.[index]?.hostname}
            placeholder="Optional"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.hostname?.message && (
              <FormattedMessage
                id={errors.containers[index].hostname.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-networkMode`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.networkModeLabel"
              defaultMessage="Network Mode"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.networkMode` as const)}
            isInvalid={!!errors.containers?.[index]?.networkMode}
            placeholder="e.g., bridge"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.networkMode?.message && (
              <FormattedMessage
                id={errors.containers[index].networkMode.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-networks`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.networksLabel"
              defaultMessage="Networks"
            />
          }
        >
          <Controller
            name={`containers.${index}.networks`}
            control={control}
            render={({
              field: { value, onChange, onBlur },
              fieldState: { invalid },
            }) => {
              const mappedValue: Option[] = (value || []).map(
                (v: ContainerCreateWithNestedNetworksInput) => {
                  const id = v.id ?? "";
                  return (
                    networks.find((n) => n.value === id) || {
                      value: id,
                      label: id,
                    }
                  );
                },
              );

              return (
                <MultiSelect
                  invalid={invalid}
                  value={mappedValue}
                  onChange={(selected) => {
                    onChange(selected.map((s) => ({ id: s.value })));
                    markUserInteraction();
                  }}
                  onBlur={onBlur}
                  options={networks}
                  getOptionValue={(option) => option.value}
                  getOptionLabel={(option) => option.label}
                />
              );
            }}
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.networks && (
              <NetworksErrors errors={errors.containers[index].networks} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-portBindings`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.portBindingsLabel"
              defaultMessage="Port Bindings"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.portBindings` as const)}
            type="text"
            isInvalid={!!errors.containers?.[index]?.portBindings}
            placeholder="e.g., 8080:80, 443:443"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.portBindings?.message && (
              <FormattedMessage
                id={errors.containers[index].portBindings.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-restartPolicy`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.restartPolicyLabel"
              defaultMessage="Restart Policy"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.restartPolicy`}
            render={({ field }) => {
              const selectedOption =
                restartPolicyOptions.find((opt) => opt.value === field.value) ||
                null;

              return (
                <Select
                  value={selectedOption}
                  onChange={(option) => {
                    field.onChange(option ? option.value : null);
                    markUserInteraction();
                  }}
                  options={restartPolicyOptions}
                  isClearable
                />
              );
            }}
          />

          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.restartPolicy?.message && (
              <FormattedMessage
                id={errors.containers[index].restartPolicy.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id={`containers-${index}-volumes`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.volumesLabel"
              defaultMessage="Volumes"
            />
          }
        >
          <div className="p-3 mb-3 bg-light border rounded">
            <Stack gap={3}>
              {volumesForm.fields.map((volume, volIndex) => {
                const selectedIds = volumesValues
                  .map((v, i) => (i !== volIndex ? v.id : null))
                  .filter(Boolean) as string[];

                const availableOptions = volumes?.filter(
                  (vol) => !selectedIds.includes(vol.value),
                );

                const fieldErrors =
                  errors.containers?.[index]?.volumes?.[volIndex];

                return (
                  <Stack
                    direction="horizontal"
                    gap={3}
                    key={volume.id}
                    className="align-items-start"
                  >
                    <Stack
                      direction="horizontal"
                      gap={3}
                      className="align-items-start"
                    >
                      <FormRow
                        id={`containers-${index}-volumeId`}
                        label={
                          <FormattedMessage
                            id="forms.CreateRelease.volumeSelectLabel"
                            defaultMessage="Volume:"
                          />
                        }
                      >
                        <div style={{ width: "250px", margin: "0 auto" }}>
                          <Controller
                            name={`containers.${index}.volumes.${volIndex}.id`}
                            control={control}
                            render={({ field }) => {
                              return (
                                <Select
                                  name={field.name}
                                  value={
                                    availableOptions.find(
                                      (opt) => opt.value === field.value,
                                    ) || null
                                  }
                                  onChange={(selected) => {
                                    field.onChange(selected?.value);
                                    markUserInteraction();
                                  }}
                                  onBlur={field.onBlur}
                                  options={availableOptions}
                                  noOptionsMessage={() => (
                                    <FormattedMessage
                                      id="forms.CreateRelease.noVolumesMessage"
                                      defaultMessage="No volumes available"
                                    />
                                  )}
                                  className="basic-single"
                                  classNamePrefix="select"
                                  isSearchable
                                />
                              );
                            }}
                          />
                        </div>

                        <Form.Control.Feedback type="invalid">
                          {fieldErrors?.id?.message && (
                            <FormattedMessage id={fieldErrors.id.message} />
                          )}
                        </Form.Control.Feedback>
                      </FormRow>

                      <FormRow
                        id={`containers-${index}-volumeTarget-${volIndex}`}
                        label={
                          <FormattedMessage
                            id="forms.CreateRelease.volumeTargetLabel"
                            defaultMessage="Target:"
                          />
                        }
                      >
                        <Form.Control
                          {...register(
                            `containers.${index}.volumes.${volIndex}.target` as const,
                          )}
                          placeholder="Target"
                          isInvalid={!!fieldErrors?.target}
                        />
                        <Form.Control.Feedback type="invalid">
                          {fieldErrors?.target?.message && (
                            <FormattedMessage id={fieldErrors.target.message} />
                          )}
                        </Form.Control.Feedback>
                      </FormRow>
                    </Stack>

                    <Button
                      variant="shadow-danger"
                      type="button"
                      onClick={() => volumesForm.remove(volIndex)}
                      className="align-self-start"
                    >
                      <Icon className="text-danger" icon={"delete"} />
                    </Button>
                  </Stack>
                );
              })}

              <div>
                <Button
                  variant="outline-primary"
                  onClick={() => volumesForm.append({ id: "", target: "" })}
                  disabled={!canAddVolume}
                >
                  <FormattedMessage
                    id="forms.CreateRelease.addVolumeButton"
                    defaultMessage="Add Volume"
                  />
                </Button>
              </div>
            </Stack>
          </div>
        </FormRow>

        <FormRow
          id={`containers-${index}-memory`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.memoryLabel"
              defaultMessage="Memory (bytes)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.memory` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.memory}
            placeholder="e.g., 104857600 for 100MB"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.memory?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-memoryReservation`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.memoryReservationLabel"
              defaultMessage="Memory Reservation (bytes)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.memoryReservation` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.memoryReservation}
            placeholder="e.g., 104857600 for 100MB"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.memoryReservation?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-memorySwap`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.memorySwapLabel"
              defaultMessage="Memory Swap (bytes)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.memorySwap` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.memorySwap}
            placeholder="e.g., 209715200 for 200MB"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.memorySwap?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-memorySwappiness`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.memorySwappinessLabel"
              defaultMessage="Memory Swappiness (0-100)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.memorySwappiness` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.memorySwappiness}
            placeholder="e.g., 60"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.memorySwappiness?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuPeriod`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.cpuPeriodLabel"
              defaultMessage="CPU Period (microseconds)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.cpuPeriod` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.cpuPeriod}
            placeholder="e.g., 100000"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.cpuPeriod?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuQuota`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.cpuQuotaLabel"
              defaultMessage="CPU Quota (microseconds)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.cpuQuota` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.cpuQuota}
            placeholder="e.g., 50000"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.cpuQuota?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuRealtimePeriod`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.cpuRealtimePeriodLabel"
              defaultMessage="CPU Real-Time Period (microseconds)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.cpuRealtimePeriod` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.cpuRealtimePeriod}
            placeholder="e.g., 1000000"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.cpuRealtimePeriod?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuRealtimeRuntime`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.cpuRealtimeRuntimeLabel"
              defaultMessage="CPU Real-Time Runtime (microseconds)"
            />
          }
        >
          <Form.Control
            type="number"
            {...register(`containers.${index}.cpuRealtimeRuntime` as const, {
              valueAsNumber: true,
            })}
            isInvalid={!!errors.containers?.[index]?.cpuRealtimeRuntime}
            placeholder="e.g., 950000"
          />
          <FormFeedback
            feedback={errors.containers?.[index]?.cpuRealtimeRuntime?.message}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-privileged`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.privilegedLabel"
              defaultMessage="Privileged"
            />
          }
        >
          <Form.Check
            type="checkbox"
            {...register(`containers.${index}.privileged` as const)}
            isInvalid={!!errors.containers?.[index]?.privileged}
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.privileged?.message && (
              <FormattedMessage
                id={errors.containers[index].privileged.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-readOnlyRootfs`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.readOnlyRootfsLabel"
              defaultMessage="Read-Only Root Filesystem"
            />
          }
        >
          <Form.Check
            type="checkbox"
            {...register(`containers.${index}.readOnlyRootfs` as const)}
            isInvalid={!!errors.containers?.[index]?.readOnlyRootfs}
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.readOnlyRootfs?.message && (
              <FormattedMessage
                id={errors.containers[index].readOnlyRootfs.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-storageOpt`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.storageOptLabel"
              defaultMessage="Storage Options"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.storageOpt`}
            render={({ field, fieldState }) => (
              <>
                <MonacoJsonEditor
                  value={field.value ?? ""}
                  onChange={(value) => {
                    field.onChange(value ?? "");
                    markUserInteraction();
                  }}
                  defaultValue={field.value || "[]"}
                  initialLines={1}
                  aria-invalid={fieldState.invalid}
                />
                {fieldState.error && (
                  <Form.Control.Feedback type="invalid" className="d-block">
                    <FormattedMessage id={fieldState.error.message} />
                  </Form.Control.Feedback>
                )}
              </>
            )}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-tmpfs`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.tmpfsLabel"
              defaultMessage="Tmpfs Mounts"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.tmpfs`}
            render={({ field, fieldState }) => (
              <>
                <MonacoJsonEditor
                  value={field.value ?? ""}
                  onChange={(value) => {
                    field.onChange(value ?? "");
                    markUserInteraction();
                  }}
                  defaultValue={field.value || "[]"}
                  initialLines={1}
                  aria-invalid={fieldState.invalid}
                />
                {fieldState.error && (
                  <Form.Control.Feedback type="invalid" className="d-block">
                    <FormattedMessage id={fieldState.error.message} />
                  </Form.Control.Feedback>
                )}
              </>
            )}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-capAdd`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.capAddLabel"
              defaultMessage="Cap Add"
            />
          }
        >
          <Controller
            name={`containers.${index}.capAdd`}
            control={control}
            render={({
              field: { value, onChange, onBlur },
              fieldState: { invalid },
            }) => {
              const options = CapAddList.map((cap) => ({ id: cap, name: cap }));

              return (
                <MultiSelect
                  invalid={invalid}
                  value={(value || []).map((v: string) => ({ id: v, name: v }))}
                  onChange={(selected) => {
                    onChange(selected.map((s) => s.id));
                    markUserInteraction();
                  }}
                  onBlur={onBlur}
                  options={options}
                  getOptionValue={(option) => option.id}
                  getOptionLabel={(option) => option.name}
                />
              );
            }}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-capDrop`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.capDropLabel"
              defaultMessage="Cap Drop"
            />
          }
        >
          <Controller
            name={`containers.${index}.capDrop`}
            control={control}
            render={({
              field: { value, onChange, onBlur },
              fieldState: { invalid },
            }) => {
              const options = CapDropList.map((cap) => ({
                id: cap,
                name: cap,
              }));

              return (
                <MultiSelect
                  invalid={invalid}
                  value={(value || []).map((v: string) => ({ id: v, name: v }))}
                  onChange={(selected) => {
                    onChange(selected.map((s) => s.id));
                    markUserInteraction();
                  }}
                  onBlur={onBlur}
                  options={options}
                  getOptionValue={(option) => option.id}
                  getOptionLabel={(option) => option.name}
                />
              );
            }}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-volumeDriver`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.volumeDriverLabel"
              defaultMessage="Volume Driver"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.volumeDriver` as const)}
            isInvalid={!!errors.containers?.[index]?.volumeDriver}
            placeholder="e.g., local"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.volumeDriver?.message && (
              <FormattedMessage
                id={errors.containers[index].volumeDriver.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-deviceMappings`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.deviceMappingsLabel"
              defaultMessage="Device Mappings"
            />
          }
        >
          <div className="p-3 mb-3 bg-light border rounded">
            <DeviceMappingsFormInput
              editableProps={dmFormInputProps}
              readOnlyProps={null}
            />
          </div>
        </FormRow>

        <div className="d-flex justify-content-start align-items-center">
          <Button
            variant="danger"
            onClick={() => remove(index)}
            className="mt-3"
          >
            <FormattedMessage
              id="forms.CreateRelease.removeContainerButton"
              defaultMessage="Remove Container"
            />
          </Button>
        </div>
      </Stack>
    </div>
  );
};

const CreateRelease = ({
  imageCredentialsOptionsRef,
  networksOptionsRef,
  volumesOptionsRef,
  requiredSystemModelsOptionsRef,
  isLoading = false,
  onSubmit,
  showModal = false,
  onToggleModal,
}: CreateReleaseProps) => {
  const intl = useIntl();

  const { listImageCredentials } = useFragment(
    IMAGE_CREDENTIALS_OPTIONS_FRAGMENT,
    imageCredentialsOptionsRef,
  );

  const imageCredentialsOptions: Option[] =
    listImageCredentials?.edges?.map(({ node: imageCredentials }) => ({
      value: imageCredentials.id,
      label: `${imageCredentials.label} (${imageCredentials.username})`,
    })) ?? [];

  const { networks } = useFragment(
    NETWORKS_OPTIONS_FRAGMENT,
    networksOptionsRef,
  );

  const networkOptions: Option[] =
    networks?.edges?.map(({ node: network }) => ({
      value: network.id,
      label: network.label ?? "",
    })) ?? [];

  const { volumes } = useFragment(VOLUMES_OPTIONS_FRAGMENT, volumesOptionsRef);

  const volumeOptions: Option[] =
    volumes?.edges?.map(({ node: volume }) => ({
      value: volume.id,
      label: volume.label ?? "",
    })) ?? [];

  const { systemModels: requiredSystemModels } = useFragment(
    SYSTEM_MODELS_OPTIONS_FRAGMENT,
    requiredSystemModelsOptionsRef,
  );

  const systemModelsOptions: Option[] =
    requiredSystemModels?.edges?.map(({ node: systemModel }) => ({
      value: systemModel.id,
      label: systemModel.name,
    })) ?? [];

  const {
    register,
    handleSubmit,
    control,
    reset,
    setFocus,
    formState: { errors },
  } = useForm<ReleaseInputData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(applicationSchema(intl)),
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "containers",
  });

  const applicationsData =
    useLazyLoadQuery<CreateRelease_getApplicationsWithReleases_Query>(
      GET_APPLICATIONS_WITH_RELEASES_QUERY,
      {},
      { fetchPolicy: "store-and-network" },
    );

  const applications = applicationsData.applications?.edges ?? [];

  const [
    selectedContainersTemplateRelease,
    setSelectedContainersTemplateRelease,
  ] = useState<SingleValue<{ value: string; label: string }>>(null);

  const [selectedContainersTemplateApp, setSelectedContainersTemplateApp] =
    useState<
      SingleValue<{ value: string; label: string; releases: ReleaseNode[] }>
    >(null);

  const [showImportSuccess, setShowImportSuccess] = useState(false);
  const [importedData, setImportedData] = useState<ReleaseInputData | null>(
    null,
  );
  const [justImported, setJustImported] = useState(false);
  const isImportingRef = useRef(false);
  const userHasInteractedRef = useRef(false);

  // Watch all form values to detect changes
  const formValues = useWatch({ control });

  // Helper function to check if a specific container is modified
  const isContainerModified = (containerIndex: number): boolean => {
    // If we just imported or are currently importing, don't show modified tags yet
    if (justImported || isImportingRef.current) {
      return false;
    }

    // Only show modified if user has actually interacted with the form
    if (!userHasInteractedRef.current) {
      return false;
    }

    if (
      !importedData?.containers?.[containerIndex] ||
      !formValues?.containers?.[containerIndex]
    ) {
      return false;
    }

    // Simple JSON comparison - only after user interaction
    const importedContainer = importedData.containers[containerIndex];
    const currentContainer = formValues.containers[containerIndex];

    return (
      JSON.stringify(importedContainer) !== JSON.stringify(currentContainer)
    );
  };

  // Helper function to mark user interaction
  const markUserInteraction = () => {
    if (!isImportingRef.current && !justImported) {
      userHasInteractedRef.current = true;
    }
  };

  const parseJsonToStringArray = (jsonStr: string | undefined): string[] => {
    if (!jsonStr) return [];
    try {
      const parsed = JSON.parse(jsonStr);
      return Array.isArray(parsed) ? parsed.map(String) : [];
    } catch {
      console.error("Invalid JSON:", jsonStr);
      return [];
    }
  };

  return (
    <>
      <form
        onSubmit={handleSubmit((data: ReleaseInputData) => {
          const submitData: ReleaseSubmitData = {
            ...data,
            containers: data.containers?.map((container) => ({
              env: container.env || undefined,
              extraHosts: container.extraHosts || undefined,
              image: {
                reference: container.image.reference,
                imageCredentialsId:
                  container.image.imageCredentialsId || undefined,
              },
              hostname: container.hostname || undefined,
              privileged: container.privileged || undefined,
              memory: container.memory || undefined,
              memoryReservation: container.memoryReservation || undefined,
              memorySwap: container.memorySwap || undefined,
              memorySwappiness: container.memorySwappiness || undefined,
              cpuPeriod: container.cpuPeriod || undefined,
              cpuQuota: container.cpuQuota || undefined,
              cpuRealtimePeriod: container.cpuRealtimePeriod || undefined,
              cpuRealtimeRuntime: container.cpuRealtimeRuntime || undefined,
              readOnlyRootfs: container.readOnlyRootfs || undefined,
              storageOpt: parseJsonToStringArray(container.storageOpt),
              tmpfs: parseJsonToStringArray(container.tmpfs),
              volumeDriver: container.volumeDriver || undefined,
              restartPolicy: container.restartPolicy || undefined,
              networkMode: container.networkMode || undefined,
              portBindings: container.portBindings
                ? (container.portBindings
                    .split(",")
                    .map((v) => v.trim()) as string[])
                : undefined,
              networks: container.networks || undefined,
              volumes: container.volumes || undefined,
              capAdd: container.capAdd?.length ? container.capAdd : undefined,
              capDrop: container.capDrop?.length
                ? container.capDrop
                : undefined,
              deviceMappings: container.deviceMappings || undefined,
            })),
            requiredSystemModels: data.requiredSystemModels,
          };

          onSubmit(submitData);
        })}
        onChange={markUserInteraction}
        onInput={markUserInteraction}
      >
        <Stack gap={2}>
          {showImportSuccess && (
            <Alert
              variant="success"
              dismissible
              onClose={() => setShowImportSuccess(false)}
            >
              <FormattedMessage
                id="forms.CreateRelease.importSuccessMessage"
                defaultMessage="Release configuration has been successfully imported!"
              />
            </Alert>
          )}

          <FormRow
            id="application-form-version"
            label={
              <FormattedMessage
                id="forms.CreateRelease.versionLabel"
                defaultMessage="Version"
              />
            }
          >
            <Form.Control
              {...register("version")}
              isInvalid={!!errors.version}
              placeholder="e.g., 1.0.0"
            />
            <Form.Control.Feedback type="invalid">
              {errors.version?.message && (
                <FormattedMessage id={errors.version.message} />
              )}
            </Form.Control.Feedback>
          </FormRow>

          <FormRow
            id="application-release-form-required-system-models"
            label={
              <FormattedMessage
                id="forms.CreateRelease.supportedSystemModelsLabels"
                defaultMessage="Supported System Models"
              />
            }
          >
            <Controller
              control={control}
              name="requiredSystemModels"
              render={({ field: { value, onChange, onBlur } }) => {
                const mappedValue = (value || []).map((v) => {
                  const option = systemModelsOptions.find(
                    (sm) => sm.value === v.id,
                  );
                  return {
                    value: v.id ?? "",
                    label: option?.label ?? v.id ?? "",
                  };
                });

                return (
                  <MultiSelect
                    value={mappedValue}
                    onChange={(selected) => {
                      onChange(selected.map(({ value }) => ({ id: value })));
                      markUserInteraction();
                    }}
                    onBlur={onBlur}
                    options={systemModelsOptions}
                    getOptionValue={(option) => option.value}
                    getOptionLabel={(option) => option.label}
                  />
                );
              }}
            />
          </FormRow>
          <Stack className="mt-3">
            <h5>
              <FormattedMessage
                id="forms.CreateRelease.containersTitle"
                defaultMessage="Containers"
              />
            </h5>
            {fields.length === 0 && (
              <p>
                <FormattedMessage
                  id="forms.CreateRelease.noContainersFeedback"
                  defaultMessage="The release does not include any container."
                />
              </p>
            )}
          </Stack>

          {fields.map((field, index) => {
            // Check if this container was imported (either by index or by checking if any containers were imported)
            const hasImportedContainers = Boolean(
              importedData?.containers?.length,
            );
            const isThisContainerImported =
              hasImportedContainers &&
              index < (importedData?.containers?.length || 0);

            return (
              <ContainerForm
                key={field.id}
                index={index}
                register={register}
                errors={errors}
                remove={remove}
                imageCredentials={imageCredentialsOptions}
                networks={networkOptions}
                volumes={volumeOptions}
                control={control}
                isImported={isThisContainerImported}
                isModified={
                  isThisContainerImported && isContainerModified(index)
                }
                markUserInteraction={markUserInteraction}
              />
            );
          })}

          <div className="d-flex justify-content-start align-items-center gap-2">
            <Button
              variant="secondary"
              onClick={() => {
                append({ image: { reference: "" } });
                setTimeout(() => {
                  const newIndex = fields.length;
                  setFocus(`containers.${newIndex}.image.reference`);
                }, 0);
              }}
            >
              <FormattedMessage
                id="forms.CreateRelease.addContainerButton"
                defaultMessage="Add Container"
              />
            </Button>
          </div>

          <div className="d-flex justify-content-end align-items-center">
            <Button variant="primary" type="submit" disabled={isLoading}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="forms.CreateRelease.submitButton"
                defaultMessage="Create"
              />
            </Button>
          </div>
        </Stack>
      </form>

      {showModal && (
        <ConfirmModal
          title={intl.formatMessage({
            id: "forms.CreateRelease.reuseResourcesModalTitle",
            defaultMessage: "Reuse Resources Modal",
          })}
          confirmLabel={
            <FormattedMessage
              id="forms.CreateRelease.confirmButton"
              defaultMessage="Confirm"
            />
          }
          onCancel={() => onToggleModal?.(false)}
          onConfirm={() => {
            if (
              !selectedContainersTemplateRelease ||
              !selectedContainersTemplateApp
            )
              return;

            const release = selectedContainersTemplateApp?.releases?.find(
              (r) => r.id === selectedContainersTemplateRelease.value,
            );

            if (!release) return;

            const mappedContainers =
              release.containers?.edges?.map((containerEdge) => {
                const c = containerEdge.node;
                return {
                  env: (c.env as EnvironmentVariable[]) || undefined,
                  extraHosts: c.extraHosts ? [...c.extraHosts] : undefined,
                  image: {
                    reference: c.image.reference,
                    imageCredentialsId: c.image?.credentials?.id || undefined,
                  },
                  hostname: c.hostname || undefined,
                  privileged: c.privileged || undefined,
                  restartPolicy: c.restartPolicy || undefined,
                  networkMode: c.networkMode || undefined,
                  portBindings: c.portBindings?.join(",") || undefined,
                  cpuPeriod: c.cpuPeriod || undefined,
                  cpuQuota: c.cpuQuota || undefined,
                  cpuRealtimePeriod: c.cpuRealtimePeriod || undefined,
                  cpuRealtimeRuntime: c.cpuRealtimeRuntime || undefined,
                  memory: c.memory || undefined,
                  memorySwap: c.memorySwap || undefined,
                  memorySwappiness: c.memorySwappiness || undefined,
                  capAdd: c.capAdd ? [...c.capAdd] : undefined,
                  capDrop: c.capDrop ? [...c.capDrop] : undefined,
                  storageOpt: c.storageOpt
                    ? JSON.stringify(c.storageOpt)
                    : undefined,
                  tmpfs: c.tmpfs ? JSON.stringify(c.tmpfs) : undefined,
                  memoryReservation: c.memoryReservation || undefined,
                  readOnlyRootfs: c.readOnlyRootfs || undefined,
                  volumeDriver: c.volumeDriver || undefined,
                  networks:
                    c.networks?.edges?.map((n: any) => ({ id: n.node.id })) ??
                    undefined,
                  volumes:
                    c.containerVolumes?.edges?.map((v: any) => ({
                      id: v.node.volume.id,
                      target: v.node.target,
                    })) ?? undefined,
                  deviceMappings:
                    c.deviceMappings?.edges?.map((dm: any) => ({
                      pathInContainer: dm.node.pathInContainer,
                      pathOnHost: dm.node.pathOnHost,
                      cgroupPermissions: dm.node.cgroupPermissions,
                    })) ?? undefined,
                };
              }) ?? [];

            const newFormData = {
              requiredSystemModels: release.systemModels.map(({ id }) => ({
                id: id ?? undefined,
              })),
              containers: mappedContainers,
              version: "", // Keep the current version as it shouldn't be imported
            };

            // Reset the form and wait for it to complete
            reset(newFormData, {
              keepErrors: false,
              keepDirty: false,
              keepIsSubmitted: false,
              keepTouched: false,
              keepIsValid: false,
              keepSubmitCount: false,
            });

            // Set importing flags to prevent premature modification detection
            isImportingRef.current = true;
            setJustImported(true);
            setShowImportSuccess(true);

            // Immediately set imported data so tags can show
            setImportedData(newFormData);

            // Use requestAnimationFrame to wait for the reset to complete
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                // Clear flags after form reset is complete
                isImportingRef.current = false;
                setJustImported(false);
                userHasInteractedRef.current = false; // Reset interaction flag
              });
            });

            // Auto-hide success message after 5 seconds
            setTimeout(() => setShowImportSuccess(false), 5000);

            onToggleModal?.(false);
          }}
        >
          <p>
            <FormattedMessage
              id="forms.CreateRelease.confirmPrompt"
              defaultMessage="Choose a release from which you want to copy containers and their configurations."
            />
          </p>
          <div className="mt-3 mb-2 p-3 border rounded">
            <div className="mb-2 d-flex flex-column gap-2">
              <FormRow
                id="containers-reuseResources-application"
                label={intl.formatMessage({
                  id: "forms.CreateRelease.selectApplication",
                  defaultMessage: "Select Application",
                })}
              >
                <Select
                  value={selectedContainersTemplateApp}
                  onChange={(val) => {
                    setSelectedContainersTemplateApp(val);
                    setSelectedContainersTemplateRelease(null);
                  }}
                  classNamePrefix="select"
                  isSearchable
                  options={applications.map((app) => ({
                    value: app.node.id,
                    label: app.node.name,
                    releases:
                      app.node.releases?.edges?.map((e) => e.node) ?? [],
                  }))}
                />
              </FormRow>

              <FormRow
                id="containers-reuseResources-release"
                label={intl.formatMessage({
                  id: "forms.CreateRelease.selectRelease",
                  defaultMessage: "Select Release",
                })}
              >
                <Select
                  isDisabled={!selectedContainersTemplateApp}
                  value={selectedContainersTemplateRelease}
                  onChange={(val) => setSelectedContainersTemplateRelease(val)}
                  classNamePrefix="select"
                  isSearchable
                  options={
                    selectedContainersTemplateApp?.releases?.map((rel) => ({
                      value: rel.id,
                      label: rel.version,
                    })) || []
                  }
                />
              </FormRow>
            </div>
          </div>
        </ConfirmModal>
      )}
    </>
  );
};

export type { ReleaseSubmitData };

export default CreateRelease;
