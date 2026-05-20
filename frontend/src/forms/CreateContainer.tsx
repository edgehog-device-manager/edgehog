// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
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

import { zodResolver } from "@hookform/resolvers/zod";
import { useEffect } from "react";
import {
  Controller,
  useFieldArray,
  useForm,
  useWatch,
  type UseFormReturn,
} from "react-hook-form";
import { FormattedMessage } from "react-intl";
import Select from "react-select";

import type {
  ContainerEnvVarInput,
  CreateContainerInput,
} from "@/api/__generated__/ContainerCreate_createContainer_Mutation.graphql";
import type { ContainerCreate_getOptions_Query$data } from "@/api/__generated__/ContainerCreate_getOptions_Query.graphql";

import Button from "@/components/Button";
import { useCollapsibleSections } from "@/components/CollapseItem";
import {
  messages,
  Section,
  SectionKey,
  sectionsList,
} from "@/components/ContainerDetails";
import "@/components/ContainerDetails.scss";
import DeviceMappingsFormInput, {
  EditableFormInputProps,
} from "@/components/DeviceMappingsFormInput";
import FieldHelp from "@/components/FieldHelp";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Icon from "@/components/Icon";
import MonacoJsonEditor from "@/components/MonacoJsonEditor";
import MultiSelect from "@/components/MultiSelect";
import {
  useImageCredentialOptions,
  useNetworkOptions,
  useVolumeOptions,
} from "@/components/options/hooks";
import Stack from "@/components/Stack";
import StringArrayFormInput from "@/components/StringArrayFormInput";
import FormFeedback from "@/forms/FormFeedback";
import MultiSelectFormField from "@/forms/MultiSelectFormField";
import SelectFormField from "@/forms/SelectFormFIeld";
import {
  CapAddList,
  CapDropList,
  containerSchema,
  KeyValue,
  type ContainerInputData,
} from "@/forms/validation";

export const restartPolicyOptions = [
  { value: "no", label: "No" },
  { value: "always", label: "Always" },
  { value: "on_failure", label: "On Failure" },
  { value: "unless_stopped", label: "Unless Stopped" },
];

const mapEnv = (
  env?: KeyValue<string>[] | null,
): ContainerEnvVarInput[] | undefined => {
  if (!env?.length) return undefined;

  return env
    .filter(
      (item): item is { key: string; value: string } =>
        !!item && typeof item === "object" && "key" in item && "value" in item,
    )
    .map((item) => ({
      key: item.key,
      value: item.value,
    }));
};

const reduceEnv = (env: ContainerEnvVarInput[]) =>
  env.reduce((acc: Record<string, string>, envVar) => {
    acc[envVar.key] = envVar.value;
    return acc;
  }, {});

const envToString = (env: ContainerEnvVarInput[]) =>
  JSON.stringify(reduceEnv(env), null, 2);

const mapCreateContainerToInput = (
  data: ContainerInputData,
): CreateContainerInput => ({
  ...data,
  env: mapEnv(data.env),
});

type BaseSectionProps = {
  form: UseFormReturn<ContainerInputData>;
  open: boolean;
  onToggle: () => void;
};

type SectionWithQueryProps = BaseSectionProps & {
  queryRef: ContainerCreate_getOptions_Query$data;
};

const NameSection = ({ form }: { form: UseFormReturn<ContainerInputData> }) => {
  const {
    register,
    formState: { errors },
  } = form;

  return (
    <div className="ps-2">
      <FormRow
        id="name"
        label={
          <FormattedMessage
            id="forms.CreateContainer.nameLabel"
            defaultMessage="Container Name"
          />
        }
      >
        <Form.Control {...register("name")} isInvalid={!!errors.name} />
        <FormFeedback feedback={errors.name?.message} />
      </FormRow>
    </div>
  );
};

const ImageSection = ({
  form,
  queryRef,
  open,
  onToggle,
}: SectionWithQueryProps) => {
  const {
    register,
    control,
    formState: { errors },
  } = form;

  const imageCredentialsOptions = useImageCredentialOptions(queryRef);

  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.imageConfigSection}
    >
      <FormRow
        id="image-reference"
        label={
          <FormattedMessage
            id="forms.CreateContainer.ReferenceLabel"
            defaultMessage="Image Reference"
          />
        }
      >
        <FieldHelp id="imageReference">
          <Form.Control
            {...register("image.reference")}
            isInvalid={!!errors.image?.reference}
          />
          <FormFeedback feedback={errors.image?.reference?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="image-credentials"
        label={
          <FormattedMessage
            id="forms.CreateContainer.imageCredentialsLabel"
            defaultMessage="Image Credentials"
          />
        }
      >
        <FieldHelp id="imageCredentials">
          <SelectFormField
            control={control}
            name="image.imageCredentialsId"
            options={imageCredentialsOptions}
          />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const NetworkSection = ({
  form,
  queryRef,
  open,
  onToggle,
}: SectionWithQueryProps) => {
  const {
    register,
    control,
    formState: { errors },
  } = form;

  const networkOptions = useNetworkOptions(queryRef);

  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.networkConfigSection}
    >
      <FormRow
        id="hostname"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkHostnameLabel"
            defaultMessage="Hostname"
          />
        }
      >
        <FieldHelp id="hostname">
          <Form.Control
            {...register("hostname")}
            isInvalid={!!errors.hostname}
          />
          <FormFeedback feedback={errors.hostname?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="networkMode"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkModeLabel"
            defaultMessage="Network Mode"
          />
        }
      >
        <FieldHelp id="networkMode">
          <Form.Control
            {...register("networkMode")}
            isInvalid={!!errors.networkMode}
          />
          <FormFeedback feedback={errors.networkMode?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="networks"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkMultiselectLabel"
            defaultMessage="Networks"
          />
        }
      >
        <FieldHelp id="networks">
          <MultiSelectFormField
            control={control}
            name="networks"
            options={networkOptions}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="extraHosts"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkExtraHostsLabel"
            defaultMessage="Extra Hosts"
          />
        }
      >
        <FieldHelp id="extraHosts" itemsAlignment="center">
          <Controller
            control={control}
            name="extraHosts"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.extraHosts)
                    ? errors.extraHosts
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.networkAddExtraHostButton"
                    defaultMessage="Add Extra Host"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id={`portBindings`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkPortBindingsLabel"
            defaultMessage="Port Bindings"
          />
        }
      >
        <FieldHelp id="portBindings" itemsAlignment="center">
          <Controller
            control={control}
            name={`portBindings`}
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.portBindings)
                    ? errors.portBindings
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.networkAddPortBindingButton"
                    defaultMessage="Add Port Binding"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const StorageSection = ({
  form,
  queryRef,
  open,
  onToggle,
}: SectionWithQueryProps) => {
  const {
    control,
    register,
    formState: { errors },
  } = form;

  const volumes = useFieldArray({
    control,
    name: "volumes",
    keyName: "key",
  });

  const watched =
    useWatch({
      control,
      name: "volumes",
    }) ?? [];

  const canAddVolume = watched.every((v) => v?.id?.trim() && v?.target?.trim());
  const volumeOptions = useVolumeOptions(queryRef);

  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.storageConfigSection}
    >
      <FormRow
        id={`binds`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageBindsLabel"
            defaultMessage="Binds"
          />
        }
      >
        <FieldHelp id="binds" itemsAlignment="center">
          <Controller
            control={control}
            name={`binds`}
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={Array.isArray(errors.binds) ? errors.binds : undefined}
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.storageAddBindsButton"
                    defaultMessage="Add Binds"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="volumes"
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageVolumesLabel"
            defaultMessage="Volumes"
          />
        }
      >
        <FieldHelp id="volumes" itemsAlignment="center">
          <div className="p-3 border rounded">
            <Stack gap={3}>
              {volumes.fields.map((volume, i) => {
                const error = errors.volumes?.[i];

                const excludedIds = watched
                  .map((v, idx) => (idx !== i ? v.id : null))
                  .filter(Boolean) as string[];

                return (
                  <Stack
                    key={volume.key}
                    direction="horizontal"
                    gap={3}
                    className="align-items-start"
                  >
                    <FormRow
                      id={`volume-${i}`}
                      label={
                        <FormattedMessage
                          id="forms.CreateContainer.storageVolumeSelectLabel"
                          defaultMessage="Volume"
                        />
                      }
                    >
                      <div style={{ width: "250px", margin: "0 auto" }}>
                        <SelectFormField
                          control={control}
                          options={volumeOptions}
                          name={`volumes.${i}.id`}
                          excludedIds={excludedIds}
                        />
                      </div>
                      <FormFeedback feedback={error?.id?.message} />
                    </FormRow>

                    <FormRow
                      id={`volume-target-${i}`}
                      label={
                        <FormattedMessage
                          id="forms.CreateContainer.storageVolumeTargetLabel"
                          defaultMessage="Target"
                        />
                      }
                    >
                      <Form.Control
                        {...register(`volumes.${i}.target`)}
                        isInvalid={!!error?.target}
                      />
                      <FormFeedback feedback={error?.target?.message} />
                    </FormRow>

                    <Button
                      variant="shadow-danger"
                      onClick={() => volumes.remove(i)}
                    >
                      <Icon className="text-danger" icon="delete" />
                    </Button>
                  </Stack>
                );
              })}

              <div>
                <Button
                  variant="outline-primary"
                  type="button"
                  disabled={!canAddVolume}
                  onClick={() =>
                    volumes.append({
                      id: "",
                      target: "",
                    })
                  }
                >
                  <FormattedMessage
                    id="forms.CreateContainer.storageAddVolumeButton"
                    defaultMessage="Add Volume"
                  />
                </Button>
              </div>
            </Stack>
          </div>
        </FieldHelp>
      </FormRow>

      <FormRow
        id={`volumeDriver`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageVolumeDriverLabel"
            defaultMessage="Volume Driver"
          />
        }
      >
        <FieldHelp id="volumeDriver">
          <Form.Control
            {...register(`volumeDriver` as const)}
            isInvalid={!!errors.volumeDriver}
          />
          <FormFeedback feedback={errors.volumeDriver?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id={`storageOpt`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageOptLabel"
            defaultMessage="Storage Options"
          />
        }
      >
        <FieldHelp id="storageOpt" itemsAlignment="center">
          <Controller
            control={control}
            name={`storageOpt`}
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.storageOpt)
                    ? errors.storageOpt
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.storageAddStorageOptButton"
                    defaultMessage="Add Storage Option"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id={`tmpfs`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageTmpfsLabel"
            defaultMessage="Tmpfs Mounts"
          />
        }
      >
        <FieldHelp id="tmpfs" itemsAlignment="center">
          <Controller
            control={control}
            name={`tmpfs`}
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={Array.isArray(errors.tmpfs) ? errors.tmpfs : undefined}
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.storageAddTmpfsButton"
                    defaultMessage="Add Tmpfs Mount"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id={`readOnlyRootfs`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageReadOnlyRootfsLabel"
            defaultMessage="Read-Only Root Filesystem"
          />
        }
      >
        <FieldHelp id="readOnlyRootfs">
          <div
            className="d-flex align-items-center"
            style={{ minHeight: "38px" }}
          >
            <Form.Check
              type="checkbox"
              {...register(`readOnlyRootfs` as const)}
              isInvalid={!!errors.readOnlyRootfs}
            />
          </div>
          <FormFeedback feedback={errors.readOnlyRootfs?.message} />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const ResourceLimitsSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    register,
    formState: { errors },
  } = form;

  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.resourceLimitsSection}
    >
      <Stack gap={2}>
        <FormRow
          id={`memory`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsMemoryLabel"
              defaultMessage="Memory (bytes)"
            />
          }
        >
          <FieldHelp id="memory">
            <Form.Control
              type="text"
              {...register(`memory` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.memory}
            />
            <FormFeedback feedback={errors.memory?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`memoryReservation`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsMemoryReservationLabel"
              defaultMessage="Memory Reservation (bytes)"
            />
          }
        >
          <FieldHelp id="memoryReservation">
            <Form.Control
              type="text"
              {...register(`memoryReservation` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.memoryReservation}
            />
            <FormFeedback feedback={errors.memoryReservation?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`memorySwap`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsMemorySwapLabel"
              defaultMessage="Memory Swap (bytes)"
            />
          }
        >
          <FieldHelp id="memorySwap">
            <Form.Control
              type="text"
              {...register(`memorySwap` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.memorySwap}
            />
            <FormFeedback feedback={errors.memorySwap?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`memorySwappiness`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsMemorySwappinessLabel"
              defaultMessage="Memory Swappiness (0-100)"
            />
          }
        >
          <FieldHelp id="memorySwappiness">
            <Form.Control
              type="text"
              {...register(`memorySwappiness` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.memorySwappiness}
            />
            <FormFeedback feedback={errors.memorySwappiness?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`cpuPeriod`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsCpuPeriodLabel"
              defaultMessage="CPU Period (microseconds)"
            />
          }
        >
          <FieldHelp id="cpuPeriod">
            <Form.Control
              type="text"
              {...register(`cpuPeriod` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.cpuPeriod}
            />
            <FormFeedback feedback={errors.cpuPeriod?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`cpuQuota`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsCpuQuotaLabel"
              defaultMessage="CPU Quota (microseconds)"
            />
          }
        >
          <FieldHelp id="cpuQuota">
            <Form.Control
              type="text"
              {...register(`cpuQuota` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.cpuQuota}
            />
            <FormFeedback feedback={errors.cpuQuota?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`cpuRealtimePeriod`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsCpuRealtimePeriodLabel"
              defaultMessage="CPU Real-Time Period (microseconds)"
            />
          }
        >
          <FieldHelp id="cpuRealtimePeriod">
            <Form.Control
              type="text"
              {...register(`cpuRealtimePeriod` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.cpuRealtimePeriod}
            />
            <FormFeedback feedback={errors.cpuRealtimePeriod?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`cpuRealtimeRuntime`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsCpuRealtimeRuntimeLabel"
              defaultMessage="CPU Real-Time Runtime (microseconds)"
            />
          }
        >
          <FieldHelp id="cpuRealtimeRuntime">
            <Form.Control
              type="text"
              {...register(`cpuRealtimeRuntime` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.cpuRealtimeRuntime}
            />
            <FormFeedback feedback={errors.cpuRealtimeRuntime?.message} />
          </FieldHelp>
        </FormRow>
      </Stack>
    </Section>
  );
};

const SecuritySection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    control,
    register,
    formState: { errors },
  } = form;

  return (
    <Section open={open} onToggle={onToggle} label={messages.securitySection}>
      <FormRow
        id="privileged"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityCapabilitiesPrivilegedLabel"
            defaultMessage="Privileged"
          />
        }
      >
        <FieldHelp id="privileged">
          <div
            className="d-flex align-items-center"
            style={{ minHeight: "38px" }}
          >
            <Form.Check
              type="checkbox"
              {...register("privileged")}
              isInvalid={!!errors.privileged}
            />
          </div>
          <FormFeedback feedback={errors.privileged?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id={`capAdd`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityCapabilitiesCapAddLabel"
            defaultMessage="Cap Add"
          />
        }
      >
        <FieldHelp id="capAdd">
          <Controller
            name={`capAdd`}
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
        id={`capDrop`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityCapabilitiesCapDropLabel"
            defaultMessage="Cap Drop"
          />
        }
      >
        <FieldHelp id="capDrop">
          <Controller
            name={`capDrop`}
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
    </Section>
  );
};

const RuntimeSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const { control } = form;

  return (
    <Section open={open} onToggle={onToggle} label={messages.runtimeSection}>
      <FormRow
        id="restartPolicy"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeEnvironmentRestartPolicyLabel"
            defaultMessage="Restart Policy"
          />
        }
      >
        <FieldHelp id="restartPolicy">
          <Controller
            control={control}
            name="restartPolicy"
            render={({ field }) => (
              <Select
                value={restartPolicyOptions.find(
                  (o) => o.value === field.value,
                )}
                onChange={(o) => field.onChange(o?.value ?? null)}
                options={restartPolicyOptions}
                isClearable
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="env"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeEnvironmentEnvLabel"
            defaultMessage="Environment (JSON String)"
          />
        }
      >
        <FieldHelp id="env" itemsAlignment="center">
          <Controller
            control={control}
            name="env"
            render={({ field, fieldState }) => (
              <MonacoJsonEditor
                value={
                  field.value && typeof field.value !== "string"
                    ? envToString(field.value)
                    : (field.value ?? "")
                }
                defaultValue={
                  field.value && typeof field.value !== "string"
                    ? envToString(field.value)
                    : "{}"
                }
                onChange={(value) => field.onChange(value ?? "")}
                error={fieldState.error?.message}
              />
            )}
          />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const DeviceMappingsSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    control,
    register,
    formState: { errors },
  } = form;

  const deviceMappingsForm = useFieldArray({
    control,
    name: "deviceMappings",
    keyName: "id",
  });

  const deviceMappingsValues =
    useWatch({
      control,
      name: "deviceMappings",
    }) ?? [];

  const canAddDeviceMapping = deviceMappingsValues.every(
    (dm) =>
      dm?.pathInContainer?.trim() &&
      dm?.pathOnHost?.trim() &&
      dm?.cgroupPermissions?.trim(),
  );

  const editableProps: EditableFormInputProps = {
    register,
    deviceMappingsForm,
    canAddDeviceMapping,
    errorFeedback: errors,
    removeDeviceMapping: (i: number) => deviceMappingsForm.remove(i),
  };

  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.deviceMappingsLabel}
    >
      <FormRow
        id={`deviceMappings`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.deviceMappingsLabel"
            defaultMessage="Device Mappings"
          />
        }
      >
        <FieldHelp id="deviceMappings" itemsAlignment="center">
          <div className="p-3 border rounded">
            <DeviceMappingsFormInput
              editableProps={editableProps}
              readOnlyProps={null}
            />
          </div>
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

type CreateContainerProps = {
  queryRef: ContainerCreate_getOptions_Query$data;
  isLoading?: boolean;
  onSubmit: (data: CreateContainerInput) => void;
  initialData: Partial<ContainerInputData>;
};

const CreateContainer = ({
  queryRef,
  isLoading,
  onSubmit,
  initialData,
}: CreateContainerProps) => {
  const form = useForm<ContainerInputData>({
    mode: "onTouched",
    resolver: zodResolver(containerSchema),
  });

  const { handleSubmit, reset } = form;

  useEffect(() => {
    reset(initialData);
  }, [initialData, reset]);

  const { toggleSection, isSectionOpen } =
    useCollapsibleSections<SectionKey>(sectionsList);

  return (
    <Form
      onSubmit={handleSubmit((data) =>
        onSubmit(mapCreateContainerToInput(data)),
      )}
    >
      <div className="containerFormLayout">
        <NameSection form={form} />

        <ImageSection
          form={form}
          queryRef={queryRef}
          open={isSectionOpen("image")}
          onToggle={() => toggleSection("image")}
        />

        <NetworkSection
          form={form}
          queryRef={queryRef}
          open={isSectionOpen("network")}
          onToggle={() => toggleSection("network")}
        />

        <StorageSection
          form={form}
          queryRef={queryRef}
          open={isSectionOpen("storage")}
          onToggle={() => toggleSection("storage")}
        />

        <ResourceLimitsSection
          form={form}
          open={isSectionOpen("resourceLimits")}
          onToggle={() => toggleSection("resourceLimits")}
        />

        <SecuritySection
          form={form}
          open={isSectionOpen("securityCapabilities")}
          onToggle={() => toggleSection("securityCapabilities")}
        />

        <RuntimeSection
          form={form}
          open={isSectionOpen("runtimeEnvironment")}
          onToggle={() => toggleSection("runtimeEnvironment")}
        />

        <DeviceMappingsSection
          form={form}
          open={isSectionOpen("deviceMappings")}
          onToggle={() => toggleSection("deviceMappings")}
        />
      </div>

      <div className="d-flex justify-content-end mt-3">
        <Button type="submit" disabled={isLoading}>
          <FormattedMessage
            id="forms.CreateContainer.submitButton"
            defaultMessage="Create Container"
          />
        </Button>
      </div>
    </Form>
  );
};

export default CreateContainer;
