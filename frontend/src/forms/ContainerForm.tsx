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

import type { Control, FieldErrors, UseFormRegister } from "react-hook-form";
import { useState } from "react";
import { Controller, useFieldArray, useWatch } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import Select from "react-select";
import { Collapse } from "react-bootstrap";

import {
  ContainerCreateWithNestedDeviceMappingsInput,
  ContainerCreateWithNestedNetworksInput,
  ContainerCreateWithNestedVolumesInput,
} from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import type {
  EnvironmentVariable,
  ReleaseInputData,
} from "@/forms/CreateRelease";
import Button from "@/components/Button";
import DeviceMappingsFormInput from "@/components/DeviceMappingsFormInput";
import FieldHelp from "@/components/FieldHelp";
import Form from "@/components/Form";
import FormFeedback from "@/forms/FormFeedback";
import { FormRow } from "@/components/FormRow";
import Icon from "@/components/Icon";
import MonacoJsonEditor from "@/components/MonacoJsonEditor";
import MultiSelect from "@/components/MultiSelect";
import Stack from "@/components/Stack";
import StringArrayFormInput from "@/components/StringArrayFormInput";
import {
  CapAddList,
  CapDropList,
  restartPolicyOptions,
} from "@/forms/CreateRelease";
import "./ContainerForm.scss";

type Option = {
  value: string;
  label: string;
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
  onRequestRemove: (index: number) => void;
};

type Section =
  | "image"
  | "network"
  | "storage"
  | "resourceLimits"
  | "securityCapabilities"
  | "runtimeEnvironment"
  | "deviceMappings";

// react-hook-form returns targetGroups validation error as Array<Record<string, FieldError>> type
// ignoring eventual minimum length validation error type.
// TargetGroupsErrors handles errors as unknown and uses type guards to render type-safe error message.
// TODO: update RHF
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
  imageCredentials,
  networks,
  volumes,
  control,
  onRequestRemove,
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

  const [openSections, setOpenSections] = useState<Section[]>([
    "image",
    "network",
    "storage",
    "resourceLimits",
    "securityCapabilities",
    "runtimeEnvironment",
    "deviceMappings",
  ]);

  const toggleSection = (section: Section) => {
    setOpenSections((current) =>
      current.includes(section)
        ? current.filter((s) => s !== section)
        : [...current, section],
    );
  };

  return (
    <div className="mb-3 container-configuration">
      <Stack gap={2}>
        {/* Image Configuration Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("image") ? "border-bottom pb-3" : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("image")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.imageSection"
                defaultMessage="Image Configuration"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("image") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("image")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-image-reference`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.imageReferenceLabel"
                    defaultMessage="Image Reference"
                  />
                }
              >
                <FieldHelp id="imageReference">
                  <Form.Control
                    {...register(
                      `containers.${index}.image.reference` as const,
                    )}
                    isInvalid={!!errors.containers?.[index]?.image?.reference}
                  />
                  <Form.Control.Feedback type="invalid">
                    {errors.containers?.[index]?.image?.reference?.message && (
                      <FormattedMessage
                        id={errors.containers[index].image.reference.message}
                      />
                    )}
                  </Form.Control.Feedback>
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-image-credentials`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.imageCredentialsLabel"
                    defaultMessage="Image Credentials"
                  />
                }
              >
                <FieldHelp id="imageCredentials">
                  <Controller
                    control={control}
                    name={`containers.${index}.image.imageCredentialsId`}
                    render={({ field }) => {
                      const selectedOption =
                        imageCredentials.find(
                          (opt) => opt.value === field.value,
                        ) || null;

                      return (
                        <Select
                          value={selectedOption}
                          onChange={(option) => {
                            field.onChange(option ? option.value : null);
                          }}
                          options={imageCredentials}
                          isClearable
                        />
                      );
                    }}
                  />
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Network Configuration Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("network") ? "border-bottom pb-3" : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("network")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.networkSection"
                defaultMessage="Network Configuration"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("network") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("network")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-hostname`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.networkHostnameLabel"
                    defaultMessage="Hostname"
                  />
                }
              >
                <FieldHelp id="hostname">
                  <Form.Control
                    {...register(`containers.${index}.hostname` as const)}
                    isInvalid={!!errors.containers?.[index]?.hostname}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.hostname?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-networkMode`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.networkModeLabel"
                    defaultMessage="Network Mode"
                  />
                }
              >
                <FieldHelp id="networkMode">
                  <Form.Control
                    {...register(`containers.${index}.networkMode` as const)}
                    isInvalid={!!errors.containers?.[index]?.networkMode}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.networkMode?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-networks`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.networkMultiselectLabel"
                    defaultMessage="Networks"
                  />
                }
              >
                <FieldHelp id="networks">
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
                      <NetworksErrors
                        errors={errors.containers[index].networks}
                      />
                    )}
                  </Form.Control.Feedback>
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-extraHosts`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.networkExtraHostsLabel"
                    defaultMessage="Extra Hosts"
                  />
                }
              >
                <FieldHelp id="extraHosts">
                  <Controller
                    control={control}
                    name={`containers.${index}.extraHosts`}
                    render={({ field }) => (
                      <StringArrayFormInput
                        value={field.value || []}
                        onChange={field.onChange}
                        errors={
                          Array.isArray(errors.containers?.[index]?.extraHosts)
                            ? errors.containers[index].extraHosts
                            : undefined
                        }
                        addButtonLabel={
                          <FormattedMessage
                            id="forms.ContainerForm.networkAddExtraHostButton"
                            defaultMessage="Add Extra Host"
                          />
                        }
                      />
                    )}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-portBindings`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.networkPortBindingsLabel"
                    defaultMessage="Port Bindings"
                  />
                }
              >
                <FieldHelp id="portBindings">
                  <Controller
                    control={control}
                    name={`containers.${index}.portBindings`}
                    render={({ field }) => (
                      <StringArrayFormInput
                        value={field.value || []}
                        onChange={field.onChange}
                        errors={
                          Array.isArray(
                            errors.containers?.[index]?.portBindings,
                          )
                            ? errors.containers[index].portBindings
                            : undefined
                        }
                        addButtonLabel={
                          <FormattedMessage
                            id="forms.ContainerForm.networkAddPortBindingButton"
                            defaultMessage="Add Port Binding"
                          />
                        }
                      />
                    )}
                  />
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Storage Configuration Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("storage") ? "border-bottom pb-3" : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("storage")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.storageSection"
                defaultMessage="Storage Configuration"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("storage") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("storage")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-binds`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.storageBindsLabel"
                    defaultMessage="Binds"
                  />
                }
              >
                <FieldHelp id="binds">
                  <Controller
                    control={control}
                    name={`containers.${index}.binds`}
                    render={({ field }) => (
                      <StringArrayFormInput
                        value={field.value || []}
                        onChange={field.onChange}
                        errors={
                          Array.isArray(errors.containers?.[index]?.binds)
                            ? errors.containers[index].binds
                            : undefined
                        }
                        addButtonLabel={
                          <FormattedMessage
                            id="forms.ContainerForm.storageAddBindsButton"
                            defaultMessage="Add Binds"
                          />
                        }
                      />
                    )}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-volumes`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.storageVolumesLabel"
                    defaultMessage="Volumes"
                  />
                }
              >
                <FieldHelp id="volumes">
                  <div className="p-3 bg-light border rounded">
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
                                    id="forms.ContainerForm.storageVolumeSelectLabel"
                                    defaultMessage="Volume:"
                                  />
                                }
                              >
                                <div
                                  style={{ width: "250px", margin: "0 auto" }}
                                >
                                  <Controller
                                    name={`containers.${index}.volumes.${volIndex}.id`}
                                    control={control}
                                    render={({ field }) => {
                                      return (
                                        <Select
                                          name={field.name}
                                          value={
                                            availableOptions.find(
                                              (opt) =>
                                                opt.value === field.value,
                                            ) || null
                                          }
                                          onChange={(selected) => {
                                            field.onChange(selected?.value);
                                          }}
                                          onBlur={field.onBlur}
                                          options={availableOptions}
                                          noOptionsMessage={() => (
                                            <FormattedMessage
                                              id="forms.ContainerForm.storageNoVolumesMessage"
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
                                <FormFeedback
                                  feedback={fieldErrors?.id?.message}
                                />
                              </FormRow>

                              <FormRow
                                id={`containers-${index}-volumeTarget-${volIndex}`}
                                label={
                                  <FormattedMessage
                                    id="forms.ContainerForm.storageVolumeTargetLabel"
                                    defaultMessage="Target:"
                                  />
                                }
                              >
                                <Form.Control
                                  {...register(
                                    `containers.${index}.volumes.${volIndex}.target` as const,
                                  )}
                                  isInvalid={!!fieldErrors?.target}
                                />
                                <FormFeedback
                                  feedback={fieldErrors?.target?.message}
                                />
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
                          onClick={() =>
                            volumesForm.append({ id: "", target: "" })
                          }
                          disabled={!canAddVolume}
                        >
                          <FormattedMessage
                            id="forms.ContainerForm.storageAddVolumeButton"
                            defaultMessage="Add Volume"
                          />
                        </Button>
                      </div>
                    </Stack>
                  </div>
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-volumeDriver`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.storageVolumeDriverLabel"
                    defaultMessage="Volume Driver"
                  />
                }
              >
                <FieldHelp id="volumeDriver">
                  <Form.Control
                    {...register(`containers.${index}.volumeDriver` as const)}
                    isInvalid={!!errors.containers?.[index]?.volumeDriver}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.volumeDriver?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-storageOpt`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.storageOptLabel"
                    defaultMessage="Storage Options"
                  />
                }
              >
                <FieldHelp id="storageOpt">
                  <Controller
                    control={control}
                    name={`containers.${index}.storageOpt`}
                    render={({ field }) => (
                      <StringArrayFormInput
                        value={field.value || []}
                        onChange={field.onChange}
                        errors={
                          Array.isArray(errors.containers?.[index]?.storageOpt)
                            ? errors.containers[index].storageOpt
                            : undefined
                        }
                        addButtonLabel={
                          <FormattedMessage
                            id="forms.ContainerForm.storageAddStorageOptButton"
                            defaultMessage="Add Storage Option"
                          />
                        }
                      />
                    )}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-tmpfs`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.storageTmpfsLabel"
                    defaultMessage="Tmpfs Mounts"
                  />
                }
              >
                <FieldHelp id="tmpfs">
                  <Controller
                    control={control}
                    name={`containers.${index}.tmpfs`}
                    render={({ field }) => (
                      <StringArrayFormInput
                        value={field.value || []}
                        onChange={field.onChange}
                        errors={
                          Array.isArray(errors.containers?.[index]?.tmpfs)
                            ? errors.containers[index].tmpfs
                            : undefined
                        }
                        addButtonLabel={
                          <FormattedMessage
                            id="forms.ContainerForm.storageAddTmpfsButton"
                            defaultMessage="Add Tmpfs Mount"
                          />
                        }
                      />
                    )}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-readOnlyRootfs`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.storageReadOnlyRootfsLabel"
                    defaultMessage="Read-Only Root Filesystem"
                  />
                }
              >
                <FieldHelp id="readOnlyRootfs">
                  <Form.Check
                    type="checkbox"
                    {...register(`containers.${index}.readOnlyRootfs` as const)}
                    isInvalid={!!errors.containers?.[index]?.readOnlyRootfs}
                  />
                  <FormFeedback
                    feedback={
                      errors.containers?.[index]?.readOnlyRootfs?.message
                    }
                  />
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Resource Limits Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("resourceLimits")
              ? "border-bottom pb-3"
              : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("resourceLimits")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.resourceLimitsSection"
                defaultMessage="Resource Limits"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("resourceLimits") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("resourceLimits")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-memory`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsMemoryLabel"
                    defaultMessage="Memory (bytes)"
                  />
                }
              >
                <FieldHelp id="memory">
                  <Form.Control
                    type="number"
                    {...register(`containers.${index}.memory` as const, {
                      valueAsNumber: true,
                    })}
                    isInvalid={!!errors.containers?.[index]?.memory}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.memory?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-memoryReservation`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsMemoryReservationLabel"
                    defaultMessage="Memory Reservation (bytes)"
                  />
                }
              >
                <FieldHelp id="memoryReservation">
                  <Form.Control
                    type="number"
                    {...register(
                      `containers.${index}.memoryReservation` as const,
                      {
                        valueAsNumber: true,
                      },
                    )}
                    isInvalid={!!errors.containers?.[index]?.memoryReservation}
                  />
                  <FormFeedback
                    feedback={
                      errors.containers?.[index]?.memoryReservation?.message
                    }
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-memorySwap`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsMemorySwapLabel"
                    defaultMessage="Memory Swap (bytes)"
                  />
                }
              >
                <FieldHelp id="memorySwap">
                  <Form.Control
                    type="number"
                    {...register(`containers.${index}.memorySwap` as const, {
                      valueAsNumber: true,
                    })}
                    isInvalid={!!errors.containers?.[index]?.memorySwap}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.memorySwap?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-memorySwappiness`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsMemorySwappinessLabel"
                    defaultMessage="Memory Swappiness (0-100)"
                  />
                }
              >
                <FieldHelp id="memorySwappiness">
                  <Form.Control
                    type="number"
                    {...register(
                      `containers.${index}.memorySwappiness` as const,
                      {
                        valueAsNumber: true,
                      },
                    )}
                    isInvalid={!!errors.containers?.[index]?.memorySwappiness}
                  />
                  <FormFeedback
                    feedback={
                      errors.containers?.[index]?.memorySwappiness?.message
                    }
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-cpuPeriod`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsCpuPeriodLabel"
                    defaultMessage="CPU Period (microseconds)"
                  />
                }
              >
                <FieldHelp id="cpuPeriod">
                  <Form.Control
                    type="number"
                    {...register(`containers.${index}.cpuPeriod` as const, {
                      valueAsNumber: true,
                    })}
                    isInvalid={!!errors.containers?.[index]?.cpuPeriod}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.cpuPeriod?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-cpuQuota`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsCpuQuotaLabel"
                    defaultMessage="CPU Quota (microseconds)"
                  />
                }
              >
                <FieldHelp id="cpuQuota">
                  <Form.Control
                    type="number"
                    {...register(`containers.${index}.cpuQuota` as const, {
                      valueAsNumber: true,
                    })}
                    isInvalid={!!errors.containers?.[index]?.cpuQuota}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.cpuQuota?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-cpuRealtimePeriod`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsCpuRealtimePeriodLabel"
                    defaultMessage="CPU Real-Time Period (microseconds)"
                  />
                }
              >
                <FieldHelp id="cpuRealtimePeriod">
                  <Form.Control
                    type="number"
                    {...register(
                      `containers.${index}.cpuRealtimePeriod` as const,
                      {
                        valueAsNumber: true,
                      },
                    )}
                    isInvalid={!!errors.containers?.[index]?.cpuRealtimePeriod}
                  />
                  <FormFeedback
                    feedback={
                      errors.containers?.[index]?.cpuRealtimePeriod?.message
                    }
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-cpuRealtimeRuntime`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.resourceLimitsCpuRealtimeRuntimeLabel"
                    defaultMessage="CPU Real-Time Runtime (microseconds)"
                  />
                }
              >
                <FieldHelp id="cpuRealtimeRuntime">
                  <Form.Control
                    type="number"
                    {...register(
                      `containers.${index}.cpuRealtimeRuntime` as const,
                      {
                        valueAsNumber: true,
                      },
                    )}
                    isInvalid={!!errors.containers?.[index]?.cpuRealtimeRuntime}
                  />
                  <FormFeedback
                    feedback={
                      errors.containers?.[index]?.cpuRealtimeRuntime?.message
                    }
                  />
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Security & Capabilities Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("securityCapabilities")
              ? "border-bottom pb-3"
              : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("securityCapabilities")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.securityCapabilitiesSection"
                defaultMessage="Security & Capabilities"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("securityCapabilities") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("securityCapabilities")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-privileged`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.securityCapabilitiesPrivilegedLabel"
                    defaultMessage="Privileged"
                  />
                }
              >
                <FieldHelp id="privileged">
                  <Form.Check
                    type="checkbox"
                    {...register(`containers.${index}.privileged` as const)}
                    isInvalid={!!errors.containers?.[index]?.privileged}
                  />
                  <FormFeedback
                    feedback={errors.containers?.[index]?.privileged?.message}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-capAdd`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.securityCapabilitiesCapAddLabel"
                    defaultMessage="Cap Add"
                  />
                }
              >
                <FieldHelp id="capAdd">
                  <Controller
                    name={`containers.${index}.capAdd`}
                    control={control}
                    render={({
                      field: { value, onChange, onBlur },
                      fieldState: { invalid },
                    }) => {
                      const options = CapAddList.map((cap) => ({
                        id: cap,
                        name: cap,
                      }));

                      return (
                        <MultiSelect
                          invalid={invalid}
                          value={(value || []).map((v: string) => ({
                            id: v,
                            name: v,
                          }))}
                          onChange={(selected) => {
                            onChange(selected.map((s) => s.id));
                          }}
                          onBlur={onBlur}
                          options={options}
                          getOptionValue={(option) => option.id}
                          getOptionLabel={(option) => option.name}
                        />
                      );
                    }}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-capDrop`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.securityCapabilitiesCapDropLabel"
                    defaultMessage="Cap Drop"
                  />
                }
              >
                <FieldHelp id="capDrop">
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
                          value={(value || []).map((v: string) => ({
                            id: v,
                            name: v,
                          }))}
                          onChange={(selected) => {
                            onChange(selected.map((s) => s.id));
                          }}
                          onBlur={onBlur}
                          options={options}
                          getOptionValue={(option) => option.id}
                          getOptionLabel={(option) => option.name}
                        />
                      );
                    }}
                  />
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Runtime & Environment Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("runtimeEnvironment")
              ? "border-bottom pb-3"
              : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("runtimeEnvironment")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.runtimeEnvironmentSection"
                defaultMessage="Runtime & Environment"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("runtimeEnvironment") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("runtimeEnvironment")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-restartPolicy`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.runtimeEnvironmentRestartPolicyLabel"
                    defaultMessage="Restart Policy"
                  />
                }
              >
                <FieldHelp id="restartPolicy">
                  <Controller
                    control={control}
                    name={`containers.${index}.restartPolicy`}
                    render={({ field }) => {
                      const selectedOption =
                        restartPolicyOptions.find(
                          (opt) => opt.value === field.value,
                        ) || null;

                      return (
                        <Select
                          value={selectedOption}
                          onChange={(option) => {
                            field.onChange(option ? option.value : null);
                          }}
                          options={restartPolicyOptions}
                          isClearable
                        />
                      );
                    }}
                  />
                </FieldHelp>
              </FormRow>

              <FormRow
                id={`containers-${index}-env`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.runtimeEnvironmentEnvLabel"
                    defaultMessage="Environment (JSON String)"
                  />
                }
              >
                <FieldHelp id="env" itemsAlignment="center">
                  <Controller
                    control={control}
                    name={`containers.${index}.env`}
                    render={({ field, fieldState: _fieldState }) => (
                      <MonacoJsonEditor
                        value={
                          field.value && typeof field.value !== "string"
                            ? envToString(field.value)
                            : (field.value ?? "")
                        }
                        onChange={(value) => {
                          field.onChange(value ?? "");
                        }}
                        defaultValue={
                          field.value && typeof field.value !== "string"
                            ? envToString(field.value)
                            : (field.value ?? "{}")
                        }
                        additionalValidation={envValidation}
                      />
                    )}
                  />
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Device Mappings Section */}
        <div
          className={
            "container-configuration-section " +
            (openSections.includes("deviceMappings")
              ? "border-bottom pb-3"
              : "pb-1")
          }
        >
          <Button
            className="w-100 d-flex align-items-start fw-bold ps-0 pe-1 container-configuration-section-header-button"
            onClick={() => toggleSection("deviceMappings")}
          >
            <h6 className="container-configuration-section-header me-auto flex-grow-1 d-flex align-items-center">
              <FormattedMessage
                id="forms.ContainerForm.deviceMappingsSection"
                defaultMessage="Device Mappings"
              />
            </h6>
            <Icon
              icon={"chevronDown"}
              className={
                "status-chevron-icon " +
                (openSections.includes("deviceMappings") ? "closed" : "")
              }
            />
          </Button>
          <Collapse in={openSections.includes("deviceMappings")}>
            <Stack gap={2}>
              <FormRow
                id={`containers-${index}-deviceMappings`}
                label={
                  <FormattedMessage
                    id="forms.ContainerForm.deviceMappingsLabel"
                    defaultMessage="Device Mappings"
                  />
                }
              >
                <FieldHelp id="deviceMappings" itemsAlignment="center">
                  <div className="p-3 bg-light border rounded">
                    <DeviceMappingsFormInput
                      editableProps={dmFormInputProps}
                      readOnlyProps={null}
                    />
                  </div>
                </FieldHelp>
              </FormRow>
            </Stack>
          </Collapse>
        </div>

        {/* Actions */}
        <div className="d-flex justify-content-start align-items-center">
          <Button
            variant="danger"
            onClick={() => onRequestRemove(index)}
            className="mt-3"
          >
            <FormattedMessage
              id="forms.ContainerForm.removeContainerButton"
              defaultMessage="Remove Container"
            />
          </Button>
        </div>
      </Stack>
    </div>
  );
};

export default ContainerForm;
