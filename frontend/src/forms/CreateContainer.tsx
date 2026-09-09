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
import { useEffect, useState } from "react";
import {
  Controller,
  useFieldArray,
  useForm,
  useWatch,
  type UseFormReturn,
} from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { Card } from "react-bootstrap";

import type {
  ContainerEnvVarInput,
  CreateContainerInput,
} from "@/api/__generated__/ContainerCreate_createContainer_Mutation.graphql";
import type { ContainerCreate_getOptions_Query$data } from "@/api/__generated__/ContainerCreate_getOptions_Query.graphql";

import Button from "@/components/ui/button/Button";
import { useCollapsibleSections } from "@/components/ui/collapse-item/CollapseItem";
import {
  messages,
  Section,
  SectionKey,
  sectionsList,
} from "@/components/apps/containers/container-details/ContainerDetails";
import "@/components/apps/containers/container-details/ContainerDetails.scss";
import DeviceMappingsFormInput, {
  EditableFormInputProps,
} from "@/components/fleet/device-groups/device-mappings-form-input/DeviceMappingsFormInput";
import FieldHelp from "@/components/ui/field-help/FieldHelp";
import Form from "@/components/ui/form/Form";
import { FormRow } from "@/components/ui/form-row/FormRow";
import Icon from "@/components/ui/icon/Icon";
import MonacoJsonEditor from "@/components/ui/monaco-json-editor/MonacoJsonEditor";
import MultiSelect from "@/components/ui/multi-select/MultiSelect";
import {
  useImageCredentialOptions,
  useNetworkOptions,
  useVolumeOptions,
} from "@/hooks/options";
import Stack from "@/components/ui/stack/Stack";
import StringArrayFormInput from "@/components/apps/containers/string-array-form-input/StringArrayFormInput";
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

export const cgroupsModeOptions = [
  { value: "host", label: "Host" },
  { value: "private", label: "Private" },
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

const mapKeyValuePairs = (pairs?: { key: string; value: string }[] | null) => {
  if (!pairs?.length) return { keys: undefined, values: undefined };
  const keys = pairs.map((p) => p.key);
  const values = pairs.map((p) => p.value);
  return { keys, values };
};

const splitBySpace = (value: string) => value.split(" ").filter(Boolean);

const mapDeviceRequests = (requests: ContainerInputData["deviceRequests"]) =>
  requests?.map((request) => ({
    driver: request.driver,
    count: request.count,
    deviceIds: request.deviceIds ?? [],
    capabilities:
      request.capabilities?.map((group) =>
        group
          .split(",")
          .map((c) => c.trim())
          .filter(Boolean),
      ) ?? [],
    options: request.options,
  })) ?? [];

const omit = <T extends Record<string, unknown>, K extends keyof T>(
  obj: T,
  ...keys: K[]
): Omit<T, K> => {
  const copy = { ...obj } as Record<string, unknown>;
  for (const k of keys) delete copy[k as string];
  return copy as Omit<T, K>;
};

const mapCreateContainerToInput = (
  data: ContainerInputData,
): CreateContainerInput => {
  const { keys: labelKeys, values: labelValues } = mapKeyValuePairs(
    data.labels,
  );
  const { keys: storageOptKeys, values: storageOptValues } = mapKeyValuePairs(
    data.storageOpts,
  );
  const { keys: sysctlsKeys, values: sysctlsValues } = mapKeyValuePairs(
    data.sysctls,
  );
  const { keys: logConfigKeys, values: logConfigValues } = mapKeyValuePairs(
    data.logConfig,
  );
  const tmpfsPaths = data.tmpfs?.map((p) => p.path);
  const tmpfsOptions = data.tmpfs?.map((p) => p.options ?? "");
  const ulimitsName = data.ulimits?.map((u) => u.name);
  const ulimitsSoft = data.ulimits?.map((u) => u.soft);
  const ulimitsHard = data.ulimits?.map((u) => u.hard);
  const blkioWeightDevicePath = data.blkioWeightDevice?.map((d) => d.path);
  const blkioWeightDeviceWeight = data.blkioWeightDevice?.map((d) => d.weight);
  const blkioDeviceReadBpsPath = data.blkioDeviceReadBps?.map((d) => d.path);
  const blkioDeviceReadBpsRate = data.blkioDeviceReadBps?.map((d) => d.rate);
  const blkioDeviceWriteBpsPath = data.blkioDeviceWriteBps?.map((d) => d.path);
  const blkioDeviceWriteBpsRate = data.blkioDeviceWriteBps?.map((d) => d.rate);
  const blkioDeviceReadIopsPath = data.blkioDeviceReadIops?.map((d) => d.path);
  const blkioDeviceReadIopsRate = data.blkioDeviceReadIops?.map((d) => d.rate);
  const blkioDeviceWriteIopsPath = data.blkioDeviceWriteIops?.map(
    (d) => d.path,
  );
  const blkioDeviceWriteIopsRate = data.blkioDeviceWriteIops?.map(
    (d) => d.rate,
  );

  const {
    env,
    image,
    deviceRequests,
    command,
    entrypoint,
    healthcheckTest,
    ...restWithPairs
  } = data;
  const rest = omit(
    restWithPairs as Record<string, unknown>,
    "labels",
    "storageOpts",
    "tmpfs",
    "sysctls",
    "logConfig",
    "ulimits",
    "blkioWeightDevice",
    "blkioDeviceReadBps",
    "blkioDeviceWriteBps",
    "blkioDeviceReadIops",
    "blkioDeviceWriteIops",
  ) as Omit<
    ContainerInputData,
    | "labels"
    | "storageOpts"
    | "tmpfs"
    | "sysctls"
    | "logConfig"
    | "ulimits"
    | "blkioWeightDevice"
    | "blkioDeviceReadBps"
    | "blkioDeviceWriteBps"
    | "blkioDeviceReadIops"
    | "blkioDeviceWriteIops"
    | "env"
    | "image"
    | "deviceRequests"
    | "command"
    | "entrypoint"
    | "healthcheckTest"
  >;

  return {
    ...rest,
    command: command ? splitBySpace(command) : undefined,
    entrypoint: entrypoint ? splitBySpace(entrypoint) : undefined,
    healthcheckTest: healthcheckTest
      ? splitBySpace(healthcheckTest)
      : undefined,
    env: mapEnv(env),
    image: image
      ? {
          reference: image.reference,
          imageCredentialsId: image.imageCredentialsId,
        }
      : undefined,
    deviceRequests: mapDeviceRequests(deviceRequests),
    labelKeys,
    labelValues,
    storageOptKeys,
    storageOptValues,
    tmpfsPaths: tmpfsPaths?.length ? tmpfsPaths : undefined,
    tmpfsOptions: tmpfsOptions?.length ? tmpfsOptions : undefined,
    sysctlsKeys,
    sysctlsValues,
    logConfigKeys,
    logConfigValues,
    ulimitsName,
    ulimitsSoft,
    ulimitsHard,
    blkioWeightDevicePath,
    blkioWeightDeviceWeight,
    blkioDeviceReadBpsPath,
    blkioDeviceReadBpsRate,
    blkioDeviceWriteBpsPath,
    blkioDeviceWriteBpsRate,
    blkioDeviceReadIopsPath,
    blkioDeviceReadIopsRate,
    blkioDeviceWriteIopsPath,
    blkioDeviceWriteIopsRate,
  };
};

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
    <Card className="border-0 p-3 shadow-sm mb-2 rounded-3">
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
    </Card>
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
        id="domainname"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkDomainnameLabel"
            defaultMessage="Domainname"
          />
        }
      >
        <FieldHelp id="domainname">
          <Form.Control
            {...register("domainname")}
            isInvalid={!!errors.domainname}
          />
          <FormFeedback feedback={errors.domainname?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="networkDisabled"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkDisabledLabel"
            defaultMessage="Network Disabled"
          />
        }
      >
        <FieldHelp id="networkDisabled">
          <div
            className="d-flex align-items-center"
            style={{ minHeight: "38px" }}
          >
            <Form.Check
              type="checkbox"
              {...register("networkDisabled")}
              isInvalid={!!errors.networkDisabled}
            />
          </div>
          <FormFeedback feedback={errors.networkDisabled?.message} />
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
        id="dns"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkDnsLabel"
            defaultMessage="DNS"
          />
        }
      >
        <FieldHelp id="dns" itemsAlignment="center">
          <Controller
            control={control}
            name="dns"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={Array.isArray(errors.dns) ? errors.dns : undefined}
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.networkAddDnsButton"
                    defaultMessage="Add DNS"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="dnsOptions"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkDnsOptionsLabel"
            defaultMessage="DNS Options"
          />
        }
      >
        <FieldHelp id="dnsOptions" itemsAlignment="center">
          <Controller
            control={control}
            name="dnsOptions"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.dnsOptions)
                    ? errors.dnsOptions
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.networkAddDnsOptionsButton"
                    defaultMessage="Add DNS Option"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="dnsSearch"
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkDnsSearchLabel"
            defaultMessage="DNS Search"
          />
        }
      >
        <FieldHelp id="dnsSearch" itemsAlignment="center">
          <Controller
            control={control}
            name="dnsSearch"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.dnsSearch) ? errors.dnsSearch : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.networkAddDnsSearchButton"
                    defaultMessage="Add DNS Search"
                  />
                }
              />
            )}
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

      <FormRow
        id={`exposedPorts`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.networkExposedPortsLabel"
            defaultMessage="Exposed Ports"
          />
        }
      >
        <FieldHelp id="exposedPorts" itemsAlignment="center">
          <Controller
            control={control}
            name={`exposedPorts`}
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.exposedPorts)
                    ? errors.exposedPorts
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.networkAddExposedPortButton"
                    defaultMessage="Add Exposed Port"
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

const KeyValuePairsInput = ({
  control,
  name,
  errors,
  keyLabel = (
    <FormattedMessage
      id="forms.CreateContainer.keyValuePairsKeyLabel"
      defaultMessage="Key"
    />
  ),
  valueLabel = (
    <FormattedMessage
      id="forms.CreateContainer.keyValuePairsValueLabel"
      defaultMessage="Value"
    />
  ),
  addLabel,
}: {
  control: UseFormReturn<ContainerInputData>["control"];
  name: `labels` | `storageOpts` | `sysctls` | `logConfig`;
  errors: unknown;
  keyLabel?: React.ReactNode;
  valueLabel?: React.ReactNode;
  addLabel: React.ReactNode;
}) => {
  const pairs = useFieldArray({ control, name, keyName: "id" });
  const watched = (useWatch({ control, name }) as unknown[]) ?? [];
  const canAdd =
    watched.length === 0 ||
    watched.every(
      (p: unknown) =>
        (p as { key?: string; value?: string })?.key?.trim() &&
        (p as { key?: string; value?: string })?.value?.trim(),
    );
  const fieldErrors = errors as
    { key?: { message?: string }; value?: { message?: string } }[] | undefined;
  return (
    <div className="p-3 border rounded">
      <Stack gap={3}>
        {pairs.fields.map((field, i) => {
          const err = fieldErrors?.[i];
          return (
            <Stack
              key={field.id}
              direction="horizontal"
              gap={3}
              className="align-items-start"
            >
              <FormRow id={`${name}-key-${i}`} label={keyLabel}>
                <Form.Control
                  {...((control.register as unknown as (n: string) => unknown)(
                    `${name}.${i}.key` as const,
                  ) as object)}
                  isInvalid={!!err?.key}
                />
                <FormFeedback feedback={err?.key?.message} />
              </FormRow>
              <FormRow id={`${name}-value-${i}`} label={valueLabel}>
                <Form.Control
                  {...((control.register as unknown as (n: string) => unknown)(
                    `${name}.${i}.value` as const,
                  ) as object)}
                  isInvalid={!!err?.value}
                />
                <FormFeedback feedback={err?.value?.message} />
              </FormRow>
              <Button variant="shadow-danger" onClick={() => pairs.remove(i)}>
                <Icon className="text-danger" icon="delete" />
              </Button>
            </Stack>
          );
        })}
        <Button
          className="me-auto"
          variant="outline-primary"
          type="button"
          disabled={!canAdd}
          onClick={() => pairs.append({ key: "", value: "" } as never)}
        >
          {addLabel}
        </Button>
      </Stack>
    </div>
  );
};

const TmpfsInput = ({
  control,
  register,
  errors,
}: {
  control: UseFormReturn<ContainerInputData>["control"];
  register: UseFormReturn<ContainerInputData>["register"];
  errors: unknown;
}) => {
  const arr = useFieldArray({ control, name: "tmpfs", keyName: "id" });
  const watched =
    (useWatch({ control, name: "tmpfs" }) as { path?: string }[] | undefined) ??
    [];
  const canAdd = watched.length === 0 || watched.every((t) => t?.path?.trim());
  const errs = errors as
    | { path?: { message?: string }; options?: { message?: string } }[]
    | undefined;
  return (
    <div className="p-3 border rounded">
      <Stack gap={3}>
        {arr.fields.map((field, i) => {
          const err = errs?.[i];
          return (
            <Stack
              key={field.id}
              direction="horizontal"
              gap={3}
              className="align-items-start"
            >
              <FormRow
                id={`tmpfs-path-${i}`}
                label={
                  <FormattedMessage
                    id="forms.CreateContainer.tmpfsPathLabel"
                    defaultMessage="Path"
                  />
                }
              >
                <Form.Control
                  {...register(`tmpfs.${i}.path` as const)}
                  isInvalid={!!err?.path}
                />
                <FormFeedback feedback={err?.path?.message} />
              </FormRow>
              <FormRow
                id={`tmpfs-options-${i}`}
                label={
                  <FormattedMessage
                    id="forms.CreateContainer.tmpfsOptionsLabel"
                    defaultMessage="Options"
                  />
                }
              >
                <Form.Control
                  {...register(`tmpfs.${i}.options` as const)}
                  isInvalid={!!err?.options}
                />
                <FormFeedback feedback={err?.options?.message} />
              </FormRow>
              <Button variant="shadow-danger" onClick={() => arr.remove(i)}>
                <Icon className="text-danger" icon="delete" />
              </Button>
            </Stack>
          );
        })}
        <Button
          className="me-auto"
          variant="outline-primary"
          disabled={!canAdd}
          onClick={() => arr.append({ path: "", options: "" } as never)}
        >
          <FormattedMessage
            id="forms.CreateContainer.storageAddTmpfsButton"
            defaultMessage="Add Tmpfs Mount"
          />
        </Button>
      </Stack>
    </div>
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
                const error = (
                  errors.volumes as unknown as
                    | {
                        id?: { message?: string };
                        target?: { message?: string };
                      }[]
                    | undefined
                )?.[i];

                const excludedIds = watched.flatMap((v, idx) =>
                  idx !== i && v.id ? [v.id] : [],
                );

                const availableVolumeOptions = volumeOptions.filter(
                  (option) => !excludedIds.includes(option.value),
                );

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
                          options={availableVolumeOptions}
                          name={`volumes.${i}.id`}
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

              <Button
                className="me-auto"
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
        id={`storageOpts`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageOptLabel"
            defaultMessage="Storage Options"
          />
        }
      >
        <FieldHelp id="storageOpts" itemsAlignment="center">
          <KeyValuePairsInput
            control={control}
            name="storageOpts"
            errors={errors.storageOpts}
            keyLabel={
              <FormattedMessage
                id="forms.CreateContainer.storageOptsKeyLabel"
                defaultMessage="Key"
              />
            }
            valueLabel={
              <FormattedMessage
                id="forms.CreateContainer.storageOptsValueLabel"
                defaultMessage="Value"
              />
            }
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.storageAddStorageOptButton"
                defaultMessage="Add Storage Option"
              />
            }
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
          <TmpfsInput
            control={control}
            register={register}
            errors={errors.tmpfs}
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

      <FormRow
        id={`autoRemove`}
        label={
          <FormattedMessage
            id="forms.CreateContainer.storageAutoRemoveLabel"
            defaultMessage="Auto Remove"
          />
        }
      >
        <FieldHelp id="autoRemove">
          <div
            className="d-flex align-items-center"
            style={{ minHeight: "38px" }}
          >
            <Form.Check
              type="checkbox"
              {...register(`autoRemove` as const)}
              isInvalid={!!errors.autoRemove}
            />
          </div>
          <FormFeedback feedback={errors.autoRemove?.message} />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const UlimitsInput = ({
  control,
  register,
  errors,
}: {
  control: UseFormReturn<ContainerInputData>["control"];
  register: UseFormReturn<ContainerInputData>["register"];
  errors: unknown;
}) => {
  const arr = useFieldArray({ control, name: "ulimits", keyName: "id" });
  const watched =
    (useWatch({ control, name: "ulimits" }) as
      { name?: string }[] | undefined) ?? [];
  const canAdd = watched.every((u) => u?.name?.trim());
  const errs = errors as
    | {
        name?: { message?: string };
        soft?: { message?: string };
        hard?: { message?: string };
      }[]
    | undefined;
  return (
    <div className="p-3 border rounded">
      <Stack gap={3}>
        {arr.fields.map((f, i) => (
          <Stack
            key={f.id}
            direction="horizontal"
            gap={3}
            className="align-items-start"
          >
            <FormRow
              id={`ulimits-name-${i}`}
              label={
                <FormattedMessage
                  id="forms.CreateContainer.ulimitsNameLabel"
                  defaultMessage="Name"
                />
              }
            >
              <Form.Control
                {...register(`ulimits.${i}.name` as const)}
                isInvalid={!!errs?.[i]?.name}
              />
              <FormFeedback feedback={errs?.[i]?.name?.message} />
            </FormRow>
            <FormRow
              id={`ulimits-soft-${i}`}
              label={
                <FormattedMessage
                  id="forms.CreateContainer.ulimitsSoftLabel"
                  defaultMessage="Soft"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`ulimits.${i}.soft` as const, {
                  setValueAs: (v: string) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errs?.[i]?.soft}
              />
              <FormFeedback feedback={errs?.[i]?.soft?.message} />
            </FormRow>
            <FormRow
              id={`ulimits-hard-${i}`}
              label={
                <FormattedMessage
                  id="forms.CreateContainer.ulimitsHardLabel"
                  defaultMessage="Hard"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`ulimits.${i}.hard` as const, {
                  setValueAs: (v: string) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errs?.[i]?.hard}
              />
              <FormFeedback feedback={errs?.[i]?.hard?.message} />
            </FormRow>
            <Button variant="shadow-danger" onClick={() => arr.remove(i)}>
              <Icon className="text-danger" icon="delete" />
            </Button>
          </Stack>
        ))}
        <Button
          className="me-auto"
          variant="outline-primary"
          disabled={!canAdd && watched.length > 0}
          onClick={() => arr.append({ name: "", soft: "", hard: "" } as never)}
        >
          <FormattedMessage
            id="forms.CreateContainer.ulimitsAddButton"
            defaultMessage="Add Ulimit"
          />
        </Button>
      </Stack>
    </div>
  );
};

const ResourceLimitsSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    control,
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
              defaultMessage="Memory + Swap (bytes)"
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
          id={`cpuShares`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsCpuSharesLabel"
              defaultMessage="CPU Shares"
            />
          }
        >
          <FieldHelp id="cpuShares">
            <Form.Control
              type="text"
              {...register(`cpuShares` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.cpuShares}
            />
            <FormFeedback feedback={errors.cpuShares?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`cpusetCpus`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsCpusetCpusLabel"
              defaultMessage="Cpu Sets"
            />
          }
        >
          <FieldHelp id="cpusetCpus">
            <Form.Control
              {...register(`cpusetCpus` as const)}
              isInvalid={!!errors.cpusetCpus}
            />
            <FormFeedback feedback={errors.cpusetCpus?.message} />
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
              defaultMessage="CPU Real Time Period (microseconds)"
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
              defaultMessage="CPU Realtime Runtime (microseconds)"
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

        <FormRow
          id={`shmSize`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsShmSizeLabel"
              defaultMessage="Shm Size (bytes)"
            />
          }
        >
          <FieldHelp id="shmSize">
            <Form.Control
              type="text"
              {...register(`shmSize` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.shmSize}
            />
            <FormFeedback feedback={errors.shmSize?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id={`oomScoreAdjustment`}
          label={
            <FormattedMessage
              id="forms.CreateContainer.resourceLimitsOomScoreAdjLabel"
              defaultMessage="OOM Score Adjustment"
            />
          }
        >
          <FieldHelp id="oomScoreAdjustment">
            <Form.Control
              type="text"
              {...register(`oomScoreAdjustment` as const, {
                setValueAs: (v) => (v === "" ? undefined : Number(v)),
              })}
              isInvalid={!!errors.oomScoreAdjustment}
            />
            <FormFeedback feedback={errors.oomScoreAdjustment?.message} />
          </FieldHelp>
        </FormRow>

        <FormRow
          id="ulimits"
          label={
            <FormattedMessage
              id="forms.CreateContainer.ulimitsLabel"
              defaultMessage="Ulimits"
            />
          }
        >
          <FieldHelp id="ulimits" itemsAlignment="center">
            <UlimitsInput
              control={control}
              register={register}
              errors={errors.ulimits}
            />
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
            defaultMessage="Add Capabilities"
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
            defaultMessage="Drop Capabilities"
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

      <FormRow
        id="cgroupsMode"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityCgroupsModeLabel"
            defaultMessage="Cgroups Mode"
          />
        }
      >
        <FieldHelp id="cgroupsMode">
          <SelectFormField
            control={control}
            name="cgroupsMode"
            options={cgroupsModeOptions}
          />
          <FormFeedback feedback={errors.cgroupsMode?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="ipcMode"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityIpcModeLabel"
            defaultMessage="Ipc Mode"
          />
        }
      >
        <FieldHelp id="ipcMode">
          <Form.Control {...register("ipcMode")} isInvalid={!!errors.ipcMode} />
          <FormFeedback feedback={errors.ipcMode?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="usernsMode"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityUsernsModeLabel"
            defaultMessage="User Namespace Mode"
          />
        }
      >
        <FieldHelp id="usernsMode">
          <Form.Control
            {...register("usernsMode")}
            isInvalid={!!errors.usernsMode}
          />
          <FormFeedback feedback={errors.usernsMode?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="pidMode"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityPidModeLabel"
            defaultMessage="PID Mode"
          />
        }
      >
        <FieldHelp id="pidMode">
          <Form.Control {...register("pidMode")} isInvalid={!!errors.pidMode} />
          <FormFeedback feedback={errors.pidMode?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="securityopt"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securitySecurityOptLabel"
            defaultMessage="Security Opt"
          />
        }
      >
        <FieldHelp id="securityopt" itemsAlignment="center">
          <Controller
            control={control}
            name="securityopt"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.securityopt)
                    ? errors.securityopt
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.securityAddSecurityOptButton"
                    defaultMessage="Add Security Opt"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="maskedPaths"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityMaskedPathsLabel"
            defaultMessage="Masked Paths"
          />
        }
      >
        <FieldHelp id="maskedPaths" itemsAlignment="center">
          <Controller
            control={control}
            name="maskedPaths"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.maskedPaths)
                    ? errors.maskedPaths
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.securityAddMaskedPathButton"
                    defaultMessage="Add Masked Path"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="readonlyPaths"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityReadonlyPathsLabel"
            defaultMessage="Readonly Paths"
          />
        }
      >
        <FieldHelp id="readonlyPaths" itemsAlignment="center">
          <Controller
            control={control}
            name="readonlyPaths"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.readonlyPaths)
                    ? errors.readonlyPaths
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.securityAddReadonlyPathButton"
                    defaultMessage="Add Readonly Path"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="groupAdd"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityGroupAddLabel"
            defaultMessage="Additional groups"
          />
        }
      >
        <FieldHelp id="groupAdd" itemsAlignment="center">
          <Controller
            control={control}
            name="groupAdd"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.groupAdd) ? errors.groupAdd : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.securityAddGroupAddButton"
                    defaultMessage="Add Group"
                  />
                }
              />
            )}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="deviceCgroupRules"
        label={
          <FormattedMessage
            id="forms.CreateContainer.securityDeviceCgroupRulesLabel"
            defaultMessage="Device Cgroup Rules"
          />
        }
      >
        <FieldHelp id="deviceCgroupRules" itemsAlignment="center">
          <Controller
            control={control}
            name="deviceCgroupRules"
            render={({ field }) => (
              <StringArrayFormInput
                value={field.value || []}
                onChange={field.onChange}
                errors={
                  Array.isArray(errors.deviceCgroupRules)
                    ? errors.deviceCgroupRules
                    : undefined
                }
                addButtonLabel={
                  <FormattedMessage
                    id="forms.CreateContainer.securityAddDeviceCgroupRuleButton"
                    defaultMessage="Add Rule"
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

const RuntimeSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    control,
    register,
    formState: { errors },
  } = form;

  return (
    <Section open={open} onToggle={onToggle} label={messages.runtimeSection}>
      <FormRow
        id="runtime"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeEnvironmentRuntimeLabel"
            defaultMessage="Runtime"
          />
        }
      >
        <FieldHelp id="runtime">
          <Form.Control {...register("runtime")} isInvalid={!!errors.runtime} />
          <FormFeedback feedback={errors.runtime?.message} />
        </FieldHelp>
      </FormRow>

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
          <SelectFormField
            control={control}
            name="restartPolicy"
            options={restartPolicyOptions}
            valueType="object"
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="restartPolicyMaximumRetryCount"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeRestartPolicyMaxRetryLabel"
            defaultMessage="Restart Policy Max Retry Count"
          />
        }
      >
        <FieldHelp id="restartPolicyMaximumRetryCount">
          <Form.Control
            type="text"
            {...register("restartPolicyMaximumRetryCount", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.restartPolicyMaximumRetryCount}
          />
          <FormFeedback
            feedback={errors.restartPolicyMaximumRetryCount?.message}
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="stopSignal"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeStopSignalLabel"
            defaultMessage="Stop Signal"
          />
        }
      >
        <FieldHelp id="stopSignal">
          <Form.Control
            {...register("stopSignal")}
            isInvalid={!!errors.stopSignal}
          />
          <FormFeedback feedback={errors.stopSignal?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="stopTimeout"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeStopTimeoutLabel"
            defaultMessage="Stop Timeout"
          />
        }
      >
        <FieldHelp id="stopTimeout">
          <Form.Control
            type="text"
            {...register("stopTimeout", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.stopTimeout}
          />
          <FormFeedback feedback={errors.stopTimeout?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="labels"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeLabelsLabel"
            defaultMessage="Labels"
          />
        }
      >
        <FieldHelp id="labels" itemsAlignment="center">
          <KeyValuePairsInput
            control={control}
            name="labels"
            errors={errors.labels}
            keyLabel={
              <FormattedMessage
                id="forms.CreateContainer.labelsKeyLabel"
                defaultMessage="Key"
              />
            }
            valueLabel={
              <FormattedMessage
                id="forms.CreateContainer.labelsValueLabel"
                defaultMessage="Value"
              />
            }
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.runtimeAddLabelButton"
                defaultMessage="Add Label"
              />
            }
          />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="sysctls"
        label={
          <FormattedMessage
            id="forms.CreateContainer.runtimeSysctlsLabel"
            defaultMessage="Sysctls"
          />
        }
      >
        <FieldHelp id="sysctls" itemsAlignment="center">
          <KeyValuePairsInput
            control={control}
            name="sysctls"
            errors={errors.sysctls}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.runtimeAddSysctlButton"
                defaultMessage="Add Sysctl"
              />
            }
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

const DeviceRequestsSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const [selectedRequest, setSelectedRequest] = useState(0);

  const {
    control,
    register,
    formState: { errors },
  } = form;

  const deviceRequests = useFieldArray({
    control,
    name: "deviceRequests",
    keyName: "key",
  });

  const removeRequest = (index: number) => {
    deviceRequests.remove(index);

    if (selectedRequest >= index && selectedRequest > 0) {
      setSelectedRequest(selectedRequest - 1);
    }
  };

  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.deviceRequestsLabel}
    >
      {deviceRequests.fields.length === 0 ? (
        <>
          <FormRow
            id={`deviceMappings`}
            label={
              <FormattedMessage
                id="forms.CreateContainer.deviceMappingsLabel"
                defaultMessage="Device Mappings"
              />
            }
          >
            <FieldHelp id="deviceRequests" itemsAlignment="center">
              <div className="border rounded p-3">
                <Button
                  variant="outline-primary"
                  onClick={() => {
                    deviceRequests.append({
                      driver: "",
                      count: -1,
                      deviceIds: [],
                      capabilities: [],
                      options: "{}",
                    });

                    setSelectedRequest(0);
                  }}
                >
                  <FormattedMessage
                    id="forms.CreateContainer.deviceRequestsAddButton"
                    defaultMessage="Add Device Request"
                  />
                </Button>
              </div>
            </FieldHelp>
          </FormRow>
        </>
      ) : (
        <div className="d-flex align-items-stretch gap-4 mt-2">
          <div className="border-end pe-5">
            <Stack gap={1}>
              {deviceRequests.fields.map((field, index) => (
                <Button
                  key={field.key}
                  variant="light"
                  className={`containerListItem ${
                    selectedRequest === index ? "active" : ""
                  }`}
                  onClick={() => setSelectedRequest(index)}
                >
                  <FormattedMessage
                    id="forms.CreateContainer.deviceRequestIndex"
                    defaultMessage="Request {index}"
                    values={{ index: index + 1 }}
                  />
                </Button>
              ))}

              <Button
                variant="link"
                className="text-start text-decoration-none px-3 py-2"
                onClick={() => {
                  deviceRequests.append({
                    driver: "",
                    count: -1,
                    deviceIds: [],
                    capabilities: [],
                    options: "{}",
                  });

                  setSelectedRequest(deviceRequests.fields.length);
                }}
              >
                <Icon icon="plus" className="me-2" />
                <FormattedMessage
                  id="forms.CreateContainer.requestsAddButton"
                  defaultMessage="Add Request"
                />
              </Button>
            </Stack>
          </div>

          <div className="flex-grow-1 ps-2 w-75" style={{ minWidth: 0 }}>
            {deviceRequests.fields[selectedRequest] &&
              (() => {
                const error = (
                  errors.deviceRequests as unknown as
                    | {
                        driver?: { message?: string };
                        count?: { message?: string };
                        deviceIds?: { message?: string }[];
                        capabilities?: { message?: string }[];
                        options?: { message?: string };
                      }[]
                    | undefined
                )?.[selectedRequest];

                return (
                  <Stack
                    key={deviceRequests.fields[selectedRequest].key}
                    gap={2}
                  >
                    <FieldHelp id="driver">
                      <FormRow
                        id={`device-request-driver-${selectedRequest}`}
                        label="Driver"
                      >
                        <Form.Control
                          {...register(
                            `deviceRequests.${selectedRequest}.driver`,
                          )}
                          isInvalid={!!error?.driver}
                        />
                        <FormFeedback feedback={error?.driver?.message} />
                      </FormRow>
                    </FieldHelp>

                    <FieldHelp id="count">
                      <FormRow
                        id={`device-request-count-${selectedRequest}`}
                        label="Count"
                      >
                        <Form.Control
                          {...register(
                            `deviceRequests.${selectedRequest}.count`,
                            {
                              setValueAs: (value) =>
                                value === "" ? undefined : Number(value),
                            },
                          )}
                          isInvalid={!!error?.count}
                        />
                        <FormFeedback feedback={error?.count?.message} />
                      </FormRow>
                    </FieldHelp>

                    <FieldHelp id="deviceIDs" itemsAlignment="center">
                      <FormRow
                        id={`device-request-deviceIds-${selectedRequest}`}
                        label="Device IDs"
                      >
                        <Controller
                          control={control}
                          name={`deviceRequests.${selectedRequest}.deviceIds`}
                          render={({ field }) => (
                            <StringArrayFormInput
                              value={field.value || []}
                              onChange={field.onChange}
                              errors={
                                Array.isArray(error?.deviceIds)
                                  ? error.deviceIds
                                  : undefined
                              }
                              addButtonLabel="Add Device ID"
                              canAddItem={
                                field.value?.every((id) => id.trim() !== "") ??
                                true
                              }
                            />
                          )}
                        />
                      </FormRow>
                    </FieldHelp>

                    <FieldHelp id="capabilities" itemsAlignment="center">
                      <FormRow
                        id={`device-request-capabilities-${selectedRequest}`}
                        label="Capabilities"
                      >
                        <Controller
                          control={control}
                          name={`deviceRequests.${selectedRequest}.capabilities`}
                          render={({ field }) => (
                            <StringArrayFormInput
                              value={field.value ?? []}
                              onChange={field.onChange}
                              errors={
                                Array.isArray(error?.capabilities)
                                  ? error.capabilities
                                  : undefined
                              }
                              addButtonLabel="Add Capability"
                              canAddItem={
                                field.value?.every(
                                  (capability) => capability.trim() !== "",
                                ) ?? true
                              }
                            />
                          )}
                        />
                      </FormRow>
                    </FieldHelp>

                    <FieldHelp id="driverOptions" itemsAlignment="center">
                      <FormRow
                        id="options"
                        label={
                          <FormattedMessage
                            id="forms.CreateContainer.driverOptionsLabel"
                            defaultMessage="Driver Options (JSON String)"
                          />
                        }
                      >
                        <Controller
                          control={control}
                          name={`deviceRequests.${selectedRequest}.options`}
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
                      </FormRow>
                    </FieldHelp>

                    <div className="pt-3 mt-2 d-flex justify-content-end">
                      <Button
                        variant="outline-danger"
                        onClick={() => {
                          removeRequest(selectedRequest);
                        }}
                      >
                        <Icon icon="delete" className="me-2" />
                        <FormattedMessage
                          id="forms.CreateContainer.removeDeviceRequestButton"
                          defaultMessage="Remove Request"
                        />
                      </Button>
                    </div>
                  </Stack>
                );
              })()}
          </div>
        </div>
      )}
    </Section>
  );
};

const ProcessSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    register,
    formState: { errors },
  } = form;
  return (
    <Section open={open} onToggle={onToggle} label={messages.processSection}>
      <FormRow
        id="user"
        label={
          <FormattedMessage
            id="forms.CreateContainer.processUserLabel"
            defaultMessage="User"
          />
        }
      >
        <FieldHelp id="user">
          <Form.Control {...register("user")} isInvalid={!!errors.user} />
          <FormFeedback feedback={errors.user?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="workingDirectory"
        label={
          <FormattedMessage
            id="forms.CreateContainer.processWorkingDirectoryLabel"
            defaultMessage="Working Directory"
          />
        }
      >
        <FieldHelp id="workingDirectory">
          <Form.Control
            {...register("workingDirectory")}
            isInvalid={!!errors.workingDirectory}
          />
          <FormFeedback feedback={errors.workingDirectory?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="command"
        label={
          <FormattedMessage
            id="forms.CreateContainer.processCommandLabel"
            defaultMessage="Command"
          />
        }
      >
        <FieldHelp id="command">
          <Form.Control {...register("command")} isInvalid={!!errors.command} />
          <FormFeedback feedback={errors.command?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="entrypoint"
        label={
          <FormattedMessage
            id="forms.CreateContainer.processEntrypointLabel"
            defaultMessage="Entrypoint"
          />
        }
      >
        <FieldHelp id="entrypoint">
          <Form.Control
            {...register("entrypoint")}
            isInvalid={!!errors.entrypoint}
          />
          <FormFeedback feedback={errors.entrypoint?.message} />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const HealthcheckSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    register,
    formState: { errors },
  } = form;
  return (
    <Section
      open={open}
      onToggle={onToggle}
      label={messages.healthcheckSection}
    >
      <FormRow
        id="healthcheckTest"
        label={
          <FormattedMessage
            id="forms.CreateContainer.healthcheckTestLabel"
            defaultMessage="Healthcheck Test"
          />
        }
      >
        <FieldHelp id="healthcheckTest">
          <Form.Control
            {...register("healthcheckTest")}
            isInvalid={!!errors.healthcheckTest}
          />
          <FormFeedback feedback={errors.healthcheckTest?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="healthcheckInterval"
        label={
          <FormattedMessage
            id="forms.CreateContainer.healthcheckIntervalLabel"
            defaultMessage="Healthcheck Interval (ns)"
          />
        }
      >
        <FieldHelp id="healthcheckInterval">
          <Form.Control
            type="text"
            {...register("healthcheckInterval", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.healthcheckInterval}
          />
          <FormFeedback feedback={errors.healthcheckInterval?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="healthcheckTimeout"
        label={
          <FormattedMessage
            id="forms.CreateContainer.healthcheckTimeoutLabel"
            defaultMessage="Healthcheck Timeout (ns)"
          />
        }
      >
        <FieldHelp id="healthcheckTimeout">
          <Form.Control
            type="text"
            {...register("healthcheckTimeout", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.healthcheckTimeout}
          />
          <FormFeedback feedback={errors.healthcheckTimeout?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="healthcheckRetries"
        label={
          <FormattedMessage
            id="forms.CreateContainer.healthcheckRetriesLabel"
            defaultMessage="Healthcheck Retries"
          />
        }
      >
        <FieldHelp id="healthcheckRetries">
          <Form.Control
            type="text"
            {...register("healthcheckRetries", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.healthcheckRetries}
          />
          <FormFeedback feedback={errors.healthcheckRetries?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="healthcheckStartPeriod"
        label={
          <FormattedMessage
            id="forms.CreateContainer.healthcheckStartPeriodLabel"
            defaultMessage="Healthcheck Start Period (ns)"
          />
        }
      >
        <FieldHelp id="healthcheckStartPeriod">
          <Form.Control
            type="text"
            {...register("healthcheckStartPeriod", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.healthcheckStartPeriod}
          />
          <FormFeedback feedback={errors.healthcheckStartPeriod?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="healthcheckStartInterval"
        label={
          <FormattedMessage
            id="forms.CreateContainer.healthcheckStartIntervalLabel"
            defaultMessage="Healthcheck Start Interval (ns)"
          />
        }
      >
        <FieldHelp id="healthcheckStartInterval">
          <Form.Control
            type="text"
            {...register("healthcheckStartInterval", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.healthcheckStartInterval}
          />
          <FormFeedback feedback={errors.healthcheckStartInterval?.message} />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

type BlkioError = {
  path?: { message?: string };
  weight?: { message?: string };
  rate?: { message?: string };
};

const BlkioInput = ({
  control,
  register,
  name,
  valueField,
  errors,
  addLabel,
}: {
  control: UseFormReturn<ContainerInputData>["control"];
  register: UseFormReturn<ContainerInputData>["register"];
  name:
    | "blkioWeightDevice"
    | "blkioDeviceReadBps"
    | "blkioDeviceWriteBps"
    | "blkioDeviceReadIops"
    | "blkioDeviceWriteIops";
  valueField: "weight" | "rate";
  errors: unknown;
  addLabel: React.ReactNode;
}) => {
  const arr = useFieldArray({ control, name, keyName: "id" });
  const watched =
    (useWatch({ control, name }) as
      | { path?: string; weight?: number; rate?: number | string }[]
      | undefined) ?? [];
  const canAdd = watched.every((b) => {
    const hasPath = !!b?.path?.trim();
    const raw = (b as Record<string, unknown>)[valueField];
    const hasValue =
      raw !== undefined && raw !== null && String(raw).trim() !== "";
    return hasPath && hasValue;
  });

  const blkioErrors = errors as BlkioError[] | undefined;
  type RegisterType = (
    n: string,
    opts: Parameters<typeof register>[1],
  ) => ReturnType<typeof register>;

  const blkioFieldHasErrors = (
    error: BlkioError | undefined,
    field: typeof valueField,
  ): boolean => !!error?.[field];

  return (
    <div className="p-3 border rounded">
      <Stack gap={3}>
        {arr.fields.map((f, i) => (
          <Stack
            key={f.id}
            direction="horizontal"
            gap={3}
            className="align-items-start"
          >
            <FormRow
              id={`${name}-path-${i}`}
              label={
                <FormattedMessage
                  id="forms.CreateContainer.blkioPathLabel"
                  defaultMessage="Path"
                />
              }
            >
              <Form.Control
                {...register(`${name}.${i}.path` as never)}
                isInvalid={!!blkioErrors?.[i]?.path}
              />
              <FormFeedback feedback={blkioErrors?.[i]?.path?.message} />
            </FormRow>
            <FormRow
              id={`${name}-${valueField}-${i}`}
              label={
                valueField === "weight" ? (
                  <FormattedMessage
                    id="forms.CreateContainer.blkioWeightValueLabel"
                    defaultMessage="Weight"
                  />
                ) : (
                  <FormattedMessage
                    id="forms.CreateContainer.blkioRateValueLabel"
                    defaultMessage="Rate"
                  />
                )
              }
            >
              <Form.Control
                type="text"
                {...(register as RegisterType)(`${name}.${i}.${valueField}`, {
                  setValueAs: (v: string) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={blkioFieldHasErrors(blkioErrors?.[i], valueField)}
              />
              <FormFeedback
                feedback={
                  (
                    blkioErrors?.[i] as
                      Record<string, { message?: string }> | undefined
                  )?.[valueField]?.message
                }
              />
            </FormRow>
            <Button variant="shadow-danger" onClick={() => arr.remove(i)}>
              <Icon className="text-danger" icon="delete" />
            </Button>
          </Stack>
        ))}
        <Button
          className="me-auto"
          variant="outline-primary"
          disabled={!canAdd && watched.length > 0}
          onClick={() => arr.append({ path: "", [valueField]: "" } as never)}
        >
          {addLabel}
        </Button>
      </Stack>
    </div>
  );
};

const BlkioSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    control,
    register,
    formState: { errors },
  } = form;
  return (
    <Section open={open} onToggle={onToggle} label={messages.blkioSection}>
      <FormRow
        id="blkioWeight"
        label={
          <FormattedMessage
            id="forms.CreateContainer.blkioWeightLabel"
            defaultMessage="Block I/O Weight (0-1000)"
          />
        }
      >
        <FieldHelp id="blkioWeight">
          <Form.Control
            type="text"
            {...register("blkioWeight", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.blkioWeight}
          />
          <FormFeedback feedback={errors.blkioWeight?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="blkioWeightDevice"
        label={
          <FormattedMessage
            id="forms.CreateContainer.blkioWeightDeviceLabel"
            defaultMessage="Block I/O Device Weight"
          />
        }
      >
        <FieldHelp id="blkioWeightDevice" itemsAlignment="center">
          <BlkioInput
            control={control}
            register={register}
            name="blkioWeightDevice"
            valueField="weight"
            errors={errors.blkioWeightDevice}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.blkioAddWeightButton"
                defaultMessage="Add Weight"
              />
            }
          />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="blkioDeviceReadBps"
        label={
          <FormattedMessage
            id="forms.CreateContainer.blkioDeviceReadBpsLabel"
            defaultMessage="Block I/O Device Read Limit Bps"
          />
        }
      >
        <FieldHelp id="blkioDeviceReadBps" itemsAlignment="center">
          <BlkioInput
            control={control}
            register={register}
            name="blkioDeviceReadBps"
            valueField="rate"
            errors={errors.blkioDeviceReadBps}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.blkioAddRateLimitButton"
                defaultMessage="Add Rate Limit"
              />
            }
          />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="blkioDeviceWriteBps"
        label={
          <FormattedMessage
            id="forms.CreateContainer.blkioDeviceWriteBpsLabel"
            defaultMessage="Block I/O Device Write Limit Bps"
          />
        }
      >
        <FieldHelp id="blkioDeviceWriteBps" itemsAlignment="center">
          <BlkioInput
            control={control}
            register={register}
            name="blkioDeviceWriteBps"
            valueField="rate"
            errors={errors.blkioDeviceWriteBps}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.blkioAddRateLimitButton"
                defaultMessage="Add Rate Limit"
              />
            }
          />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="blkioDeviceReadIops"
        label={
          <FormattedMessage
            id="forms.CreateContainer.blkioDeviceReadIopsLabel"
            defaultMessage="Block I/O Device Read Limit Iops"
          />
        }
      >
        <FieldHelp id="blkioDeviceReadIops" itemsAlignment="center">
          <BlkioInput
            control={control}
            register={register}
            name="blkioDeviceReadIops"
            valueField="rate"
            errors={errors.blkioDeviceReadIops}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.blkioAddRateLimitButton"
                defaultMessage="Add Rate Limit"
              />
            }
          />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="blkioDeviceWriteIops"
        label={
          <FormattedMessage
            id="forms.CreateContainer.blkioDeviceWriteIopsLabel"
            defaultMessage="Block I/O Device Write Limit Iops"
          />
        }
      >
        <FieldHelp id="blkioDeviceWriteIops" itemsAlignment="center">
          <BlkioInput
            control={control}
            register={register}
            name="blkioDeviceWriteIops"
            valueField="rate"
            errors={errors.blkioDeviceWriteIops}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.blkioAddRateLimitButton"
                defaultMessage="Add Rate Limit"
              />
            }
          />
        </FieldHelp>
      </FormRow>
    </Section>
  );
};

const LoggingSection = ({ form, open, onToggle }: BaseSectionProps) => {
  const {
    control,
    register,
    formState: { errors },
  } = form;
  return (
    <Section open={open} onToggle={onToggle} label={messages.loggingSection}>
      <FormRow
        id="logType"
        label={
          <FormattedMessage
            id="forms.CreateContainer.loggingLogTypeLabel"
            defaultMessage="Log Type"
          />
        }
      >
        <FieldHelp id="logType">
          <Form.Control {...register("logType")} isInvalid={!!errors.logType} />
          <FormFeedback feedback={errors.logType?.message} />
        </FieldHelp>
      </FormRow>
      <FormRow
        id="logConfig"
        label={
          <FormattedMessage
            id="forms.CreateContainer.loggingLogConfigLabel"
            defaultMessage="Log Config"
          />
        }
      >
        <FieldHelp id="logConfig" itemsAlignment="center">
          <KeyValuePairsInput
            control={control}
            name="logConfig"
            errors={errors.logConfig}
            addLabel={
              <FormattedMessage
                id="forms.CreateContainer.loggingAddLogConfigButton"
                defaultMessage="Add Log Config"
              />
            }
          />
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
    resolver: zodResolver(containerSchema) as never,
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

        <DeviceRequestsSection
          form={form}
          open={isSectionOpen("deviceRequests")}
          onToggle={() => toggleSection("deviceRequests")}
        />

        <ProcessSection
          form={form}
          open={isSectionOpen("process")}
          onToggle={() => toggleSection("process")}
        />

        <HealthcheckSection
          form={form}
          open={isSectionOpen("healthcheck")}
          onToggle={() => toggleSection("healthcheck")}
        />

        <BlkioSection
          form={form}
          open={isSectionOpen("blkio")}
          onToggle={() => toggleSection("blkio")}
        />

        <LoggingSection
          form={form}
          open={isSectionOpen("logging")}
          onToggle={() => toggleSection("logging")}
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
