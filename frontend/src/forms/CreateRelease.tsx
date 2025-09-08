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

import React, { useCallback, useState } from "react";
import { useForm, useFieldArray, Controller, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment, useLazyLoadQuery } from "react-relay/hooks";
import type { UseFormRegister } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";

import type {
  CreateRelease_ImageCredentialsOptionsFragment$key,
  CreateRelease_ImageCredentialsOptionsFragment$data,
} from "api/__generated__/CreateRelease_ImageCredentialsOptionsFragment.graphql";
import type {
  CreateRelease_NetworksOptionsFragment$key,
  CreateRelease_NetworksOptionsFragment$data,
} from "api/__generated__/CreateRelease_NetworksOptionsFragment.graphql";
import type {
  CreateRelease_VolumesOptionsFragment$key,
  CreateRelease_VolumesOptionsFragment$data,
} from "api/__generated__/CreateRelease_VolumesOptionsFragment.graphql";
import type { CreateRelease_SystemModelsOptionsFragment$key } from "api/__generated__/CreateRelease_SystemModelsOptionsFragment.graphql";
import {
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
import {
  yup,
  envSchema,
  portBindingsSchema,
  tmpfsOptSchema,
  storageOptSchema,
  extraHostsSchema,
} from "./index";
import MultiSelect from "components/MultiSelect";
import Select, { SingleValue } from "react-select";
import Icon from "components/Icon";
import MonacoJsonEditor from "components/MonacoJsonEditor";
import ConfirmModal from "components/ConfirmModal";

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
                containers {
                  edges {
                    node {
                      id
                      env
                      hostname
                      networkMode
                      restartPolicy
                      privileged
                      portBindings
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

type ContainerInput = {
  cpuPeriod?: number;
  cpuQuota?: number;
  cpuRealtimePeriod?: number;
  cpuRealtimeRuntime?: number;
  extraHosts?: string[];
  env?: string; // JsonString
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
};

type ReleaseInputData = {
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
const applicationSchema = yup
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
          memory: yup.number().nullable(),
          memoryReservation: yup.number().nullable(),
          memorySwap: yup.number().nullable(),
          memorySwappiness: yup.number().min(0).max(100).nullable(),
          cpuPeriod: yup.number().nullable(),
          cpuQuota: yup.number().nullable(),
          cpuRealtimePeriod: yup.number().nullable(),
          cpuRealtimeRuntime: yup.number().nullable(),
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

const restartPolicyOptions = [
  { value: "no", label: "No" },
  { value: "always", label: "Always" },
  { value: "on_failure", label: "On Failure" },
  { value: "unless_stopped", label: "Unless Stopped" },
];

type CreateReleaseProps = {
  imageCredentialsOptionsRef: CreateRelease_ImageCredentialsOptionsFragment$key;
  networksOptionsRef: CreateRelease_NetworksOptionsFragment$key;
  volumesOptionsRef: CreateRelease_VolumesOptionsFragment$key;
  requiredSystemModelsOptionsRef: CreateRelease_SystemModelsOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ReleaseSubmitData) => void;
};

type ContainerFormProps = {
  index: number;
  register: UseFormRegister<ReleaseInputData>;
  errors: any;
  remove: (index: number) => void;
  listImageCredentials: CreateRelease_ImageCredentialsOptionsFragment$data["listImageCredentials"];
  networks: CreateRelease_NetworksOptionsFragment$data["networks"];
  volumes: CreateRelease_VolumesOptionsFragment$data["volumes"];
  intl: ReturnType<typeof useIntl>;
  control: any;
};

const ContainerForm = ({
  index,
  register,
  errors,
  remove,
  listImageCredentials,
  networks,
  volumes,
  intl,
  control,
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

  const extraHostsForm = useFieldArray({
    control,
    name: `containers.${index}.extraHosts`,
  });

  const handleAddExtraHost = useCallback(() => {
    extraHostsForm.append("");
  }, [extraHostsForm]);

  const handleDeleteExtraHost = useCallback(
    (i: number) => {
      extraHostsForm.remove(i);
    },
    [extraHostsForm],
  );

  const canAddVolume = volumesValues.every(
    (v) => v.id?.trim() && v.target?.trim(),
  );

  return (
    <div className="border p-3 mb-3">
      <h5>
        <FormattedMessage
          id="components.CreateRelease.containerTitle"
          defaultMessage="Container {containerNumber}"
          values={{ containerNumber: index + 1 }}
        />
      </h5>{" "}
      <Stack gap={2}>
        <FormRow
          id={`containers-${index}-env`}
          label={
            <FormattedMessage
              id="components.CreateRelease.envLabel"
              defaultMessage="Environment (JSON String)"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.env`}
            render={({ field, fieldState: _fieldState }) => (
              <MonacoJsonEditor
                language="json"
                value={field.value ?? ""}
                onChange={(value) => {
                  field.onChange(value ?? "");
                }}
                defaultValue={field.value || "{}"}
              />
            )}
          />
        </FormRow>

        <FormRow
          id={`containers-${index}-extraHosts`}
          label={
            <FormattedMessage
              id="components.CreateRelease.extraHostsLabel"
              defaultMessage="Extra Hosts"
            />
          }
        >
          <div className="p-3 mb-3 bg-light border rounded">
            <Stack gap={3}>
              {extraHostsForm.fields.map((field, i) => (
                <Stack direction="horizontal" gap={3} key={field.id}>
                  <Stack>
                    <Form.Control
                      {...register(
                        `containers.${index}.extraHosts.${i}` as const,
                      )}
                      isInvalid={!!errors.containers?.[index]?.extraHosts?.[i]}
                      placeholder="e.g., myhost:127.0.0.1"
                    />
                    <Form.Control.Feedback type="invalid">
                      {errors.containers?.[index]?.extraHosts?.[i]?.message && (
                        <FormattedMessage
                          id={errors.containers[index].extraHosts[i].message}
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
              ))}
              <Button
                className="me-auto"
                variant="outline-primary"
                onClick={handleAddExtraHost}
              >
                <FormattedMessage
                  id="components.CreateRelease.addExtraHostButton"
                  defaultMessage="Add Extra Host"
                />
              </Button>
            </Stack>
          </div>
        </FormRow>

        <FormRow
          id={`containers-${index}-image-reference`}
          label={
            <FormattedMessage
              id="components.CreateRelease.imageReferenceLabel"
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
              id="components.CreateRelease.imageCredentialsLabel"
              defaultMessage="Image Credentials"
            />
          }
        >
          <Controller
            control={control}
            name={`containers.${index}.image.imageCredentialsId`}
            render={({ field }) => {
              const options =
                listImageCredentials?.edges?.map((ic) => ({
                  value: ic.node.id,
                  label: `${ic.node.label} (${ic.node.username})`,
                })) || [];

              const selectedOption =
                options.find((opt) => opt.value === field.value) || null;

              return (
                <Select
                  value={selectedOption}
                  onChange={(option) => {
                    field.onChange(option ? option.value : null);
                  }}
                  options={options}
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
              id="components.CreateRelease.hostnameLabel"
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
              id="components.CreateRelease.networkModeLabel"
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
              id="components.CreateRelease.networksLabel"
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
              const mappedValue = (value || []).map(
                (v: { id: string }) =>
                  networks?.edges?.find((n) => n.node.id === v.id) || v,
              );

              return (
                <MultiSelect
                  invalid={invalid}
                  value={mappedValue}
                  onChange={onChange}
                  onBlur={onBlur}
                  options={networks?.edges || []}
                  getOptionValue={(option) => option.node.id!}
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
              id="components.CreateRelease.portBindingsLabel"
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
              id="components.CreateRelease.restartPolicyLabel"
              defaultMessage="Restart Policy"
            />
          }
        >
          <Form.Select
            {...register(`containers.${index}.restartPolicy` as const)}
            isInvalid={!!errors.containers?.[index]?.restartPolicy}
            defaultValue=""
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "components.CreateRelease.restartPolicyOption",
                defaultMessage: "Select a Restart Policy",
              })}
            </option>
            {restartPolicyOptions.map((option) => (
              <option
                key={option.value}
                value={option.value}
                disabled={option.value === ""}
              >
                {option.label}
              </option>
            ))}
          </Form.Select>
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

                const availableOptions = volumes?.edges?.filter(
                  (vol) => !selectedIds.includes(vol.node.id),
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
                            id="components.CreateRelease.volumeSelectLabel"
                            defaultMessage="Volume:"
                          />
                        }
                      >
                        <div style={{ width: "250px", margin: "0 auto" }}>
                          <Controller
                            name={`containers.${index}.volumes.${volIndex}.id`}
                            control={control}
                            render={({ field }) => {
                              const selectOptions =
                                availableOptions?.map((vol) => ({
                                  value: vol.node.id,
                                  label: vol.node.label,
                                })) || [];
                              return (
                                <Select
                                  name={field.name}
                                  value={
                                    selectOptions.find(
                                      (opt) => opt.value === field.value,
                                    ) || null
                                  }
                                  onChange={(selected) =>
                                    field.onChange(selected?.value)
                                  }
                                  onBlur={field.onBlur}
                                  options={selectOptions}
                                  noOptionsMessage={() => (
                                    <FormattedMessage
                                      id="components.CreateRelease.noVolumesMessage"
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
                        id={`containers-${index}-volumeTarget`}
                        label={
                          <FormattedMessage
                            id="components.CreateRelease.volumeTargetLabel"
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
              id="components.CreateRelease.memoryLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.memory?.message && (
              <FormattedMessage id={errors.containers[index].memory.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-memoryReservation`}
          label={
            <FormattedMessage
              id="components.CreateRelease.memoryReservationLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.memoryReservation?.message && (
              <FormattedMessage
                id={errors.containers[index].memoryReservation.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-memorySwap`}
          label={
            <FormattedMessage
              id="components.CreateRelease.memorySwapLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.memorySwap?.message && (
              <FormattedMessage
                id={errors.containers[index].memorySwap.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-memorySwappiness`}
          label={
            <FormattedMessage
              id="components.CreateRelease.memorySwappinessLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.memorySwappiness?.message && (
              <FormattedMessage
                id={errors.containers[index].memorySwappiness.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuPeriod`}
          label={
            <FormattedMessage
              id="components.CreateRelease.cpuPeriodLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.cpuPeriod?.message && (
              <FormattedMessage
                id={errors.containers[index].cpuPeriod.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuQuota`}
          label={
            <FormattedMessage
              id="components.CreateRelease.cpuQuotaLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.cpuQuota?.message && (
              <FormattedMessage
                id={errors.containers[index].cpuQuota.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuRealtimePeriod`}
          label={
            <FormattedMessage
              id="components.CreateRelease.cpuRealtimePeriodLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.cpuRealtimePeriod?.message && (
              <FormattedMessage
                id={errors.containers[index].cpuRealtimePeriod.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-cpuRealtimeRuntime`}
          label={
            <FormattedMessage
              id="components.CreateRelease.cpuRealtimeRuntimeLabel"
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
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.cpuRealtimeRuntime?.message && (
              <FormattedMessage
                id={errors.containers[index].cpuRealtimeRuntime.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-privileged`}
          label={
            <FormattedMessage
              id="components.CreateRelease.privilegedLabel"
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
              id="components.CreateRelease.readOnlyRootfsLabel"
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
              id="components.CreateRelease.storageOptLabel"
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
                  language="json"
                  value={field.value ?? ""}
                  onChange={(value) => field.onChange(value ?? "")}
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
              id="components.CreateRelease.tmpfsLabel"
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
                  language="json"
                  value={field.value ?? ""}
                  onChange={(value) => field.onChange(value ?? "")}
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
              id="components.CreateRelease.capAddLabel"
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
                  onChange={(selected) => onChange(selected.map((s) => s.id))}
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
              id="components.CreateRelease.capDropLabel"
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
                  onChange={(selected) => onChange(selected.map((s) => s.id))}
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
              id="components.CreateRelease.volumeDriverLabel"
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

        <div className="d-flex justify-content-start align-items-center">
          <Button
            variant="danger"
            onClick={() => remove(index)}
            className="mt-3"
          >
            <FormattedMessage
              id="components.CreateRelease.removeContainerButton"
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
}: CreateReleaseProps) => {
  const intl = useIntl();

  const { listImageCredentials } = useFragment(
    IMAGE_CREDENTIALS_OPTIONS_FRAGMENT,
    imageCredentialsOptionsRef,
  );

  const { networks } = useFragment(
    NETWORKS_OPTIONS_FRAGMENT,
    networksOptionsRef,
  );
  const { volumes } = useFragment(VOLUMES_OPTIONS_FRAGMENT, volumesOptionsRef);
  const { systemModels: requiredSystemModels } = useFragment(
    SYSTEM_MODELS_OPTIONS_FRAGMENT,
    requiredSystemModelsOptionsRef,
  );

  const {
    register,
    handleSubmit,
    control,
    formState: { errors },
  } = useForm<ReleaseInputData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(applicationSchema),
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

  const [showModal, setShowModal] = useState(false);

  const [
    selectedContainersTemplateRelease,
    setSelectedContainersTemplateRelease,
  ] = useState<SingleValue<{ value: string; label: string }>>(null);

  const [selectedContainersTemplateApp, setSelectedContainersTemplateApp] =
    useState<
      SingleValue<{ value: string; label: string; releases: ReleaseNode[] }>
    >(null);

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
            })),
            requiredSystemModels: data.requiredSystemModels,
          };

          onSubmit(submitData);
        })}
      >
        <Stack gap={2}>
          <FormRow
            id="application-form-version"
            label={
              <FormattedMessage
                id="components.CreateRelease.versionLabel"
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
                id="components.CreateRelease.requiredSystemModelsLabels"
                defaultMessage="Required System Models"
              />
            }
          >
            <Controller
              control={control}
              name="requiredSystemModels"
              render={({ field: { value, onChange, onBlur } }) => {
                const nodes =
                  requiredSystemModels?.edges?.map(({ node }) => node) || [];
                const options = nodes.map((n) => ({
                  value: n.id,
                  label: n.name,
                }));
                const mappedValue = (value || []).map((v) => {
                  const node = nodes.find((sm) => sm.id === v.id);
                  return { value: v.id ?? "", label: node?.name ?? v.id ?? "" };
                });

                return (
                  <MultiSelect
                    value={mappedValue}
                    onChange={(selected) =>
                      onChange(selected.map(({ value }) => ({ id: value })))
                    }
                    onBlur={onBlur}
                    options={options}
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
                id="components.CreateRelease.containersTitle"
                defaultMessage="Containers"
              />
            </h5>
            {fields.length === 0 && (
              <p>
                <FormattedMessage
                  id="components.CreateRelease.noContainersFeedback"
                  defaultMessage="The release does not include any container."
                />
              </p>
            )}
          </Stack>

          {fields.map((field, index) => (
            <ContainerForm
              key={field.id}
              index={index}
              register={register}
              errors={errors}
              remove={remove}
              listImageCredentials={listImageCredentials}
              networks={networks}
              volumes={volumes}
              intl={intl}
              control={control}
            />
          ))}

          <div className="d-flex justify-content-start align-items-center gap-2">
            <Button
              variant="secondary"
              onClick={() => append({ image: { reference: "" } })}
            >
              <FormattedMessage
                id="components.CreateRelease.addContainerButton"
                defaultMessage="Add Container"
              />
            </Button>

            <Button
              variant="primary"
              title={intl.formatMessage({
                id: "components.CreateRelease.reuseResourcesTitleButton",
                defaultMessage:
                  "Copy containers and their configurations from an existing release",
              })}
              onClick={() => setShowModal(true)}
            >
              <FormattedMessage
                id="components.CreateRelease.reuseResourcesButton"
                defaultMessage="Reuse Containers"
              />
            </Button>
          </div>

          <div className="d-flex justify-content-end align-items-center">
            <Button variant="primary" type="submit" disabled={isLoading}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="components.CreateRelease.submitButton"
                defaultMessage="Create"
              />
            </Button>
          </div>
        </Stack>
      </form>

      {showModal && (
        <ConfirmModal
          title={intl.formatMessage({
            id: "components.CreateRelease.reuseResourcesModalTitle",
            defaultMessage: "Reuse Resources Modal",
          })}
          confirmLabel={
            <FormattedMessage
              id="components.CreateRelease.confirmButton"
              defaultMessage="Confirm"
            />
          }
          onCancel={() => setShowModal(false)}
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

            remove();

            release.containers?.edges?.forEach((containerEdge) => {
              const c = containerEdge.node;
              append({
                env: c.env || "",
                image: {
                  reference: c.image?.reference || "",
                  imageCredentialsId: c.image?.credentials?.id || undefined,
                },
                hostname: c.hostname || "",
                privileged: c.privileged || false,
                restartPolicy: c.restartPolicy || "",
                networkMode: c.networkMode || "",
                portBindings: c.portBindings?.join(",") || "",
                networks:
                  c.networks?.edges?.map((n: any) => ({ id: n.node.id })) ?? [],
                volumes:
                  c.containerVolumes?.edges?.map((v: any) => ({
                    id: v.node.volume.id,
                    target: v.node.target,
                  })) ?? [],
              });
            });

            setShowModal(false);
          }}
        >
          <p>
            <FormattedMessage
              id="components.CreateRelease.confirmPrompt"
              defaultMessage="Choose a release from which you want to copy containers and their configurations."
            />
          </p>
          <div className="mt-3 mb-2 p-3 border rounded">
            <div className="mb-2 d-flex flex-column gap-2">
              <FormRow
                id="containers-reuseResources-application"
                label={intl.formatMessage({
                  id: "components.CreateRelease.selectApplication",
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
                  id: "components.CreateRelease.selectRelease",
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
