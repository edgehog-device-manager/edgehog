/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { useFieldArray, Controller, useWatch } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import type { Control, FieldErrors, UseFormRegister } from "react-hook-form";
import Select from "react-select";

import {
  ContainerCreateWithNestedDeviceMappingsInput,
  ContainerCreateWithNestedNetworksInput,
  ContainerCreateWithNestedVolumesInput,
} from "api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import type {
  EnvironmentVariable,
  ReleaseInputData,
} from "forms/CreateRelease";
import {
  CapAddList,
  CapDropList,
  restartPolicyOptions,
} from "forms/CreateRelease";
import Button from "components/Button";
import Form from "components/Form";
import Stack from "components/Stack";
import Tag from "components/Tag";
import Icon from "components/Icon";
import MonacoJsonEditor from "components/MonacoJsonEditor";
import FormFeedback from "forms/FormFeedback";
import DeviceMappingsFormInput from "components/DeviceMappingsFormInput";
import { FormRow } from "components/FormRow";
import MultiSelect from "components/MultiSelect";
import FieldHelp from "components/FieldHelp";

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
  isImported?: boolean;
  isModified?: boolean;
  markUserInteraction: () => void;
};

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

      <Stack gap={3}>
        {/* Image Configuration Section */}
        <div className="border-bottom pb-3 mt-2">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.imageConfigSection"
              defaultMessage="Image Configuration"
            />
          </h6>
          <Stack gap={2}>
            <FormRow
              id={`containers-${index}-image-reference`}
              label={
                <FormattedMessage
                  id="forms.CreateRelease.imageReferenceLabel"
                  defaultMessage="Image Reference"
                />
              }
            >
              <FieldHelp id="imageReference">
                <Form.Control
                  {...register(`containers.${index}.image.reference` as const)}
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
                  id="forms.CreateRelease.imageCredentialsLabel"
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
                          markUserInteraction();
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
        </div>

        {/* Network Configuration Section */}
        <div className="border-bottom pb-3">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.networkConfigSection"
              defaultMessage="Network Configuration"
            />
          </h6>
          <Stack gap={2}>
            <FormRow
              id={`containers-${index}-hostname`}
              label={
                <FormattedMessage
                  id="forms.CreateRelease.hostnameLabel"
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
                  id="forms.CreateRelease.networkModeLabel"
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
                  id="forms.CreateRelease.networksLabel"
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
                  id="forms.CreateRelease.extraHostsLabel"
                  defaultMessage="Extra Hosts"
                />
              }
            >
              <FieldHelp id="extraHosts">
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
                              errors.containers?.[index]?.extraHosts?.[i]
                                ?.message;

                            return (
                              <Stack direction="horizontal" gap={3} key={i}>
                                <Stack>
                                  <Form.Control
                                    value={host}
                                    onChange={(e) =>
                                      handleChangeHost(i, e.target.value)
                                    }
                                    isInvalid={!!hostError}
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
                                  <Icon
                                    className="text-danger"
                                    icon={"delete"}
                                  />
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
              </FieldHelp>
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
              <FieldHelp id="portBindings">
                <Form.Control
                  {...register(`containers.${index}.portBindings` as const)}
                  type="text"
                  isInvalid={!!errors.containers?.[index]?.portBindings}
                />

                <Form.Control.Feedback type="invalid">
                  {errors.containers?.[index]?.portBindings?.message && (
                    <FormattedMessage
                      id={errors.containers[index].portBindings.message}
                    />
                  )}
                </Form.Control.Feedback>
              </FieldHelp>
            </FormRow>
          </Stack>
        </div>

        {/* Storage Configuration Section */}
        <div className="border-bottom pb-3">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.storageConfigSection"
              defaultMessage="Storage Configuration"
            />
          </h6>
          <Stack gap={2}>
            <FormRow
              id={`containers-${index}-binds`}
              label={
                <FormattedMessage
                  id="forms.CreateRelease.bindsLabel"
                  defaultMessage="Binds"
                />
              }
            >
              <FieldHelp id="binds">
                <Form.Control
                  {...register(`containers.${index}.binds` as const)}
                  type="text"
                  isInvalid={!!errors.containers?.[index]?.binds}
                />

                <Form.Control.Feedback type="invalid">
                  {errors.containers?.[index]?.binds?.message && (
                    <FormattedMessage
                      id={errors.containers[index].binds.message}
                    />
                  )}
                </Form.Control.Feedback>
              </FieldHelp>
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
              <FieldHelp id="volumes">
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
                              <FormFeedback
                                feedback={fieldErrors?.id?.message}
                              />
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
                          id="forms.CreateRelease.addVolumeButton"
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
                  id="forms.CreateRelease.volumeDriverLabel"
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
                  id="forms.CreateRelease.storageOptLabel"
                  defaultMessage="Storage Options"
                />
              }
            >
              <FieldHelp id="storageOpt">
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
                        <Form.Control.Feedback
                          type="invalid"
                          className="d-block"
                        >
                          <FormattedMessage id={fieldState.error.message} />
                        </Form.Control.Feedback>
                      )}
                    </>
                  )}
                />
              </FieldHelp>
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
              <FieldHelp id="tmpfs">
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
                        <Form.Control.Feedback
                          type="invalid"
                          className="d-block"
                        >
                          <FormattedMessage id={fieldState.error.message} />
                        </Form.Control.Feedback>
                      )}
                    </>
                  )}
                />
              </FieldHelp>
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
              <FieldHelp id="readOnlyRootfs">
                <Form.Check
                  type="checkbox"
                  {...register(`containers.${index}.readOnlyRootfs` as const)}
                  isInvalid={!!errors.containers?.[index]?.readOnlyRootfs}
                />
                <FormFeedback
                  feedback={errors.containers?.[index]?.readOnlyRootfs?.message}
                />
              </FieldHelp>
            </FormRow>
          </Stack>
        </div>

        {/* Resource Limits Section */}
        <div className="border-bottom pb-3">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.resourceLimitsSection"
              defaultMessage="Resource Limits"
            />
          </h6>
          <Stack gap={2}>
            <FormRow
              id={`containers-${index}-memory`}
              label={
                <FormattedMessage
                  id="forms.CreateRelease.memoryLabel"
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
                  id="forms.CreateRelease.memoryReservationLabel"
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
                  id="forms.CreateRelease.memorySwapLabel"
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
                  id="forms.CreateRelease.memorySwappinessLabel"
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
                  id="forms.CreateRelease.cpuPeriodLabel"
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
                  id="forms.CreateRelease.cpuQuotaLabel"
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
                  id="forms.CreateRelease.cpuRealtimePeriodLabel"
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
                  id="forms.CreateRelease.cpuRealtimeRuntimeLabel"
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
        </div>

        {/* Security & Capabilities Section */}
        <div className="border-bottom pb-3">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.securitySection"
              defaultMessage="Security & Capabilities"
            />
          </h6>
          <Stack gap={2}>
            <FormRow
              id={`containers-${index}-privileged`}
              label={
                <FormattedMessage
                  id="forms.CreateRelease.privilegedLabel"
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
                  id="forms.CreateRelease.capAddLabel"
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
              </FieldHelp>
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
              </FieldHelp>
            </FormRow>
          </Stack>
        </div>

        {/* Runtime & Environment Section */}
        <div className="border-bottom pb-3">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.runtimeSection"
              defaultMessage="Runtime & Environment"
            />
          </h6>
          <Stack gap={2}>
            <FormRow
              id={`containers-${index}-restartPolicy`}
              label={
                <FormattedMessage
                  id="forms.CreateRelease.restartPolicyLabel"
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
                          markUserInteraction();
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
                  id="forms.CreateRelease.envLabel"
                  defaultMessage="Environment (JSON String)"
                />
              }
            >
              <FieldHelp id="env">
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
                        markUserInteraction();
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
        </div>

        {/* Device Mappings Section */}
        <div className="border-bottom pb-3">
          <h6 className="mb-3">
            <FormattedMessage
              id="forms.ContainerForm.deviceMappingsSection"
              defaultMessage="Device Mappings"
            />
          </h6>
          <FormRow
            id={`containers-${index}-deviceMappings`}
            label={
              <FormattedMessage
                id="forms.CreateRelease.deviceMappingsLabel"
                defaultMessage="Device Mappings"
              />
            }
          >
            <FieldHelp id="deviceMappings">
              <div className="p-3 mb-3 bg-light border rounded">
                <DeviceMappingsFormInput
                  editableProps={dmFormInputProps}
                  readOnlyProps={null}
                />
              </div>
            </FieldHelp>
          </FormRow>
        </div>

        {/* Actions */}
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

export default ContainerForm;
