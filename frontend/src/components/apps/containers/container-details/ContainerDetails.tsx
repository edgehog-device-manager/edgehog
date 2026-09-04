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

import React, { useMemo, useState } from "react";
import { Button, Stack } from "react-bootstrap";
import {
  FormattedMessage,
  MessageDescriptor,
  defineMessages,
} from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ContainerDetailsFragment$data,
  ContainerDetailsFragment$key,
} from "@/api/__generated__/ContainerDetailsFragment.graphql";

import CollapseItem, {
  useCollapsibleSections,
} from "@/components/ui/collapse-item/CollapseItem";
import DeviceMappingsFormInput from "@/components/fleet/device-groups/device-mappings-form-input/DeviceMappingsFormInput";
import Form from "@/components/ui/form/Form";
import {
  FormRow as BaseFormRow,
  FormRowProps,
} from "@/components/ui/form-row/FormRow";
import MonacoJsonEditor from "@/components/ui/monaco-json-editor/MonacoJsonEditor";
import MultiSelect from "@/components/ui/multi-select/MultiSelect";
import StringArrayFormInput from "@/components/apps/containers/string-array-form-input/StringArrayFormInput";
import "@/components/apps/containers/container-details/ContainerDetails.scss";
import { restartPolicyOptions } from "@/forms/CreateContainer";

const messages = defineMessages({
  nameLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.nameLabel",
    defaultMessage: "Container Name",
  },
  imageConfigSection: {
    id: "components.apps.containers.container-details.ContainerDetails.imageConfigSection",
    defaultMessage: "Image Configuration",
  },
  imageReference: {
    id: "components.apps.containers.container-details.ContainerDetails.imageReferenceLabel",
    defaultMessage: "Image Reference",
  },
  imageCredentials: {
    id: "components.apps.containers.container-details.ContainerDetails.imageCredentialsLabel",
    defaultMessage: "Image Credentials",
  },
  processSection: {
    id: "components.apps.containers.container-details.ContainerDetails.processSection",
    defaultMessage: "Process Configuration",
  },
  user: {
    id: "components.apps.containers.container-details.ContainerDetails.userLabel",
    defaultMessage: "User",
  },
  workingDirectory: {
    id: "components.apps.containers.container-details.ContainerDetails.workingDirectoryLabel",
    defaultMessage: "Working Directory",
  },
  command: {
    id: "components.apps.containers.container-details.ContainerDetails.commandLabel",
    defaultMessage: "Command",
  },
  entrypoint: {
    id: "components.apps.containers.container-details.ContainerDetails.entrypointLabel",
    defaultMessage: "Entrypoint",
  },
  healthcheckSection: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckSection",
    defaultMessage: "Healthcheck",
  },
  healthcheckTest: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckTestLabel",
    defaultMessage: "Healthcheck Test",
  },
  healthcheckInterval: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckIntervalLabel",
    defaultMessage: "Healthcheck Interval (ns)",
  },
  healthcheckTimeout: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckTimeoutLabel",
    defaultMessage: "Healthcheck Timeout (ns)",
  },
  healthcheckRetries: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckRetriesLabel",
    defaultMessage: "Healthcheck Retries",
  },
  healthcheckStartPeriod: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckStartPeriodLabel",
    defaultMessage: "Healthcheck Start Period (ns)",
  },
  healthcheckStartInterval: {
    id: "components.apps.containers.container-details.ContainerDetails.healthcheckStartIntervalLabel",
    defaultMessage: "Healthcheck Start Interval (ns)",
  },
  networkConfigSection: {
    id: "components.apps.containers.container-details.ContainerDetails.networkConfigSection",
    defaultMessage: "Network Configuration",
  },
  hostname: {
    id: "components.apps.containers.container-details.ContainerDetails.hostnameLabel",
    defaultMessage: "Hostname",
  },
  domainname: {
    id: "components.apps.containers.container-details.ContainerDetails.domainnameLabel",
    defaultMessage: "Domainname",
  },
  networkDisabled: {
    id: "components.apps.containers.container-details.ContainerDetails.networkDisabledLabel",
    defaultMessage: "Network Disabled",
  },
  networkMode: {
    id: "components.apps.containers.container-details.ContainerDetails.networkModeLabel",
    defaultMessage: "Network Mode",
  },
  dns: {
    id: "components.apps.containers.container-details.ContainerDetails.dnsLabel",
    defaultMessage: "DNS",
  },
  dnsOptions: {
    id: "components.apps.containers.container-details.ContainerDetails.dnsOptionsLabel",
    defaultMessage: "DNS Options",
  },
  dnsSearch: {
    id: "components.apps.containers.container-details.ContainerDetails.dnsSearchLabel",
    defaultMessage: "DNS Search",
  },
  extraHosts: {
    id: "components.apps.containers.container-details.ContainerDetails.extraHostsLabel",
    defaultMessage: "Extra Hosts",
  },
  portBindings: {
    id: "components.apps.containers.container-details.ContainerDetails.portBindingsLabel",
    defaultMessage: "Port Bindings",
  },
  exposedPorts: {
    id: "components.apps.containers.container-details.ContainerDetails.exposedPortsLabel",
    defaultMessage: "Exposed Ports",
  },
  storageConfigSection: {
    id: "components.apps.containers.container-details.ContainerDetails.storageConfigSection",
    defaultMessage: "Storage Configuration",
  },
  binds: {
    id: "components.apps.containers.container-details.ContainerDetails.bindsLabel",
    defaultMessage: "Binds",
  },
  volumeDriver: {
    id: "components.apps.containers.container-details.ContainerDetails.volumeDriver",
    defaultMessage: "Volume Driver",
  },
  storageOpt: {
    id: "components.apps.containers.container-details.ContainerDetails.storageOptLabel",
    defaultMessage: "Storage Options",
  },
  tmpfs: {
    id: "components.apps.containers.container-details.ContainerDetails.tmpfsLabel",
    defaultMessage: "Tmpfs",
  },
  readOnlyRootfs: {
    id: "components.apps.containers.container-details.ContainerDetails.readOnlyRootfsLabel",
    defaultMessage: "Read-Only Root Filesystem",
  },
  autoRemove: {
    id: "components.apps.containers.container-details.ContainerDetails.autoRemoveLabel",
    defaultMessage: "Auto Remove",
  },
  resourceLimitsSection: {
    id: "components.apps.containers.container-details.ContainerDetails.resourceLimitsSection",
    defaultMessage: "Resource Limits",
  },
  memory: {
    id: "components.apps.containers.container-details.ContainerDetails.memoryLabel",
    defaultMessage: "Memory (bytes)",
  },
  memoryReservation: {
    id: "components.apps.containers.container-details.ContainerDetails.memoryReservationLabel",
    defaultMessage: "Memory Reservation (bytes)",
  },
  memorySwap: {
    id: "components.apps.containers.container-details.ContainerDetails.memorySwapLabel",
    defaultMessage: "Memory + Swap (bytes)",
  },
  memorySwappiness: {
    id: "components.apps.containers.container-details.ContainerDetails.memorySwappinessLabel",
    defaultMessage: "Memory Swappiness (0-100)",
  },
  cpuShares: {
    id: "components.apps.containers.container-details.ContainerDetails.cpuSharesLabel",
    defaultMessage: "CPU Shares",
  },
  cpusetCpus: {
    id: "components.apps.containers.container-details.ContainerDetails.cpusetCpusLabel",
    defaultMessage: "Cpu Sets",
  },
  cpuPeriod: {
    id: "components.apps.containers.container-details.ContainerDetails.cpuPeriodLabel",
    defaultMessage: "CPU Period (microseconds)",
  },
  cpuQuota: {
    id: "components.apps.containers.container-details.ContainerDetails.cpuQuotaLabel",
    defaultMessage: "CPU Quota (microseconds)",
  },
  cpuRealtimePeriod: {
    id: "components.apps.containers.container-details.ContainerDetails.cpuRealtimePeriodLabel",
    defaultMessage: "CPU Real Time Period (microseconds)",
  },
  cpuRealtimeRuntime: {
    id: "components.apps.containers.container-details.ContainerDetails.cpuRealtimeRuntimeLabel",
    defaultMessage: "CPU Realtime Runtime (microseconds)",
  },
  shmSize: {
    id: "components.apps.containers.container-details.ContainerDetails.shmSizeLabel",
    defaultMessage: "Shm Size (bytes)",
  },
  oomScoreAdjustment: {
    id: "components.apps.containers.container-details.ContainerDetails.oomScoreAdjustmentLabel",
    defaultMessage: "OOM Score Adjustment",
  },
  blkioSection: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioSection",
    defaultMessage: "Block I/O",
  },
  blkioWeight: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioWeightLabel",
    defaultMessage: "Block I/O Weight (0-1000)",
  },
  blkioWeightDevice: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioWeightDeviceLabel",
    defaultMessage: "Block I/O Device Weight",
  },
  blkioDeviceReadBps: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioDeviceReadBpsLabel",
    defaultMessage: "Block I/O Device Read Limit Bps",
  },
  blkioDeviceWriteBps: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioDeviceWriteBpsLabel",
    defaultMessage: "Block I/O Device Write Limit Bps",
  },
  blkioDeviceReadIops: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioDeviceReadIopsLabel",
    defaultMessage: "Block I/O Device Read Limit Iops",
  },
  blkioDeviceWriteIops: {
    id: "components.apps.containers.container-details.ContainerDetails.blkioDeviceWriteIopsLabel",
    defaultMessage: "Block I/O Device Write Limit Iops",
  },
  ulimits: {
    id: "components.apps.containers.container-details.ContainerDetails.ulimitsLabel",
    defaultMessage: "Ulimits",
  },
  securitySection: {
    id: "components.apps.containers.container-details.ContainerDetails.securitySection",
    defaultMessage: "Security & Capabilities",
  },
  privileged: {
    id: "components.apps.containers.container-details.ContainerDetails.privilegedLabel",
    defaultMessage: "Privileged",
  },
  capAdd: {
    id: "components.apps.containers.container-details.ContainerDetails.capAdd",
    defaultMessage: "Add Capabilities",
  },
  capDrop: {
    id: "components.apps.containers.container-details.ContainerDetails.capDrop",
    defaultMessage: "Drop Capabilities",
  },
  cgroupsMode: {
    id: "components.apps.containers.container-details.ContainerDetails.cgroupsModeLabel",
    defaultMessage: "Cgroups Mode",
  },
  ipcMode: {
    id: "components.apps.containers.container-details.ContainerDetails.ipcModeLabel",
    defaultMessage: "Ipc Mode",
  },
  usernsMode: {
    id: "components.apps.containers.container-details.ContainerDetails.usernsModeLabel",
    defaultMessage: "User Namespace Mode",
  },
  pidMode: {
    id: "components.apps.containers.container-details.ContainerDetails.pidModeLabel",
    defaultMessage: "PID Mode",
  },
  securityopt: {
    id: "components.apps.containers.container-details.ContainerDetails.securityoptLabel",
    defaultMessage: "Security Opt",
  },
  maskedPaths: {
    id: "components.apps.containers.container-details.ContainerDetails.maskedPathsLabel",
    defaultMessage: "Masked Paths",
  },
  readonlyPaths: {
    id: "components.apps.containers.container-details.ContainerDetails.readonlyPathsLabel",
    defaultMessage: "Readonly Paths",
  },
  groupAdd: {
    id: "components.apps.containers.container-details.ContainerDetails.groupAddLabel",
    defaultMessage: "Group Add",
  },
  deviceCgroupRules: {
    id: "components.apps.containers.container-details.ContainerDetails.deviceCgroupRulesLabel",
    defaultMessage: "Device Cgroup Rules",
  },
  runtimeSection: {
    id: "components.apps.containers.container-details.ContainerDetails.runtimeSection",
    defaultMessage: "Runtime & Environment",
  },
  runtime: {
    id: "components.apps.containers.container-details.ContainerDetails.runtimeLabel",
    defaultMessage: "Runtime",
  },
  restartPolicy: {
    id: "components.apps.containers.container-details.ContainerDetails.restartPolicyLabel",
    defaultMessage: "Restart Policy",
  },
  restartPolicyMaximumRetryCount: {
    id: "components.apps.containers.container-details.ContainerDetails.restartPolicyMaximumRetryCountLabel",
    defaultMessage: "Restart Policy Max Retry Count",
  },
  stopSignal: {
    id: "components.apps.containers.container-details.ContainerDetails.stopSignalLabel",
    defaultMessage: "Stop Signal",
  },
  stopTimeout: {
    id: "components.apps.containers.container-details.ContainerDetails.stopTimeoutLabel",
    defaultMessage: "Stop Timeout",
  },
  labels: {
    id: "components.apps.containers.container-details.ContainerDetails.labelsLabel",
    defaultMessage: "Labels",
  },
  sysctls: {
    id: "components.apps.containers.container-details.ContainerDetails.sysctlsLabel",
    defaultMessage: "Sysctls",
  },
  env: {
    id: "components.apps.containers.container-details.ContainerDetails.envLabel",
    defaultMessage: "Environment (JSON String)",
  },
  loggingSection: {
    id: "components.apps.containers.container-details.ContainerDetails.loggingSection",
    defaultMessage: "Logging",
  },
  logType: {
    id: "components.apps.containers.container-details.ContainerDetails.logTypeLabel",
    defaultMessage: "Log Type",
  },
  logConfig: {
    id: "components.apps.containers.container-details.ContainerDetails.logConfigLabel",
    defaultMessage: "Log Config",
  },
  volumesLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.volumesLabel",
    defaultMessage: "Volumes",
  },
  noVolumes: {
    id: "components.apps.containers.container-details.ContainerDetails.noVolumes",
    defaultMessage: "No volumes assigned.",
  },
  targetLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.targetLabel",
    defaultMessage: "Target",
  },
  volumeLabelLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.volumeLabelLabel",
    defaultMessage: "Label",
  },
  volumeDriverLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.volumeDriverLabel",
    defaultMessage: "Driver",
  },
  options: {
    id: "components.apps.containers.container-details.ContainerDetails.options",
    defaultMessage: "Options",
  },
  networksLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.networksLabel",
    defaultMessage: "Networks",
  },
  noNetworks: {
    id: "components.apps.containers.container-details.ContainerDetails.noNetworks",
    defaultMessage: "No networks assigned.",
  },
  networkLabelLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.networkLabelLabel",
    defaultMessage: "Label",
  },
  networkDriverLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.networkDriverLabel",
    defaultMessage: "Driver",
  },
  networkInternalLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.networkInternalLabel",
    defaultMessage: "Internal",
  },
  networkEnableIPv6Label: {
    id: "components.apps.containers.container-details.ContainerDetails.networkEnableIPv6Label",
    defaultMessage: "Enable IPv6",
  },
  networkOptionsLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.networkOptionsLabel",
    defaultMessage: "Options (JSON)",
  },
  deviceMappingsLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.deviceMappingsLabel",
    defaultMessage: "Device Mappings",
  },
  noDeviceMappings: {
    id: "components.apps.containers.container-details.ContainerDetails.noDeviceMappings",
    defaultMessage: "No device mappings assigned.",
  },
  deviceRequestsLabel: {
    id: "components.apps.containers.container-details.ContainerDetails.deviceRequestLabel",
    defaultMessage: "Device Requests",
  },
  noDeviceRequests: {
    id: "components.apps.containers.container-details.ContainerDetails.noDeviceRequests",
    defaultMessage: "No device requests assigned.",
  },
  driver: {
    id: "components.apps.containers.container-details.ContainerDetails.driver",
    defaultMessage: "Driver",
  },
  count: {
    id: "components.apps.containers.container-details.ContainerDetails.count",
    defaultMessage: "Count",
  },
  deviceIDs: {
    id: "components.apps.containers.container-details.ContainerDetails.deviceIDs",
    defaultMessage: "Device IDs",
  },
  capabilities: {
    id: "components.apps.containers.container-details.ContainerDetails.capabilities",
    defaultMessage: "Capabilities",
  },
  driverOptions: {
    id: "components.apps.containers.container-details.ContainerDetails.driverOptions",
    defaultMessage: "Driver Options",
  },
});

const CONTAINER_DETAILS_FRAGMENT = graphql`
  fragment ContainerDetailsFragment on Container {
    id
    name
    domainname
    user
    command
    healthcheckTest
    healthcheckInterval
    healthcheckTimeout
    healthcheckRetries
    healthcheckStartPeriod
    healthcheckStartInterval
    workingDirectory
    entrypoint
    networkDisabled
    labelKeys
    labelValues
    stopSignal
    stopTimeout
    restartPolicy
    restartPolicyMaximumRetryCount
    env {
      key
      value
    }
    extraHosts
    hostname
    networkMode
    portBindings
    exposedPorts
    binds
    restartPolicy
    privileged
    memory
    memorySwap
    memoryReservation
    memorySwappiness
    cpuShares
    cpusetCpus
    cpuPeriod
    cpuQuota
    cpuRealtimePeriod
    cpuRealtimeRuntime
    shmSize
    oomScoreAdjustment
    blkioWeight
    blkioWeightDevicePath
    blkioWeightDeviceWeight
    blkioDeviceReadBpsPath
    blkioDeviceReadBpsRate
    blkioDeviceWriteBpsPath
    blkioDeviceWriteBpsRate
    blkioDeviceReadIopsPath
    blkioDeviceReadIopsRate
    blkioDeviceWriteIopsPath
    blkioDeviceWriteIopsRate
    tmpfsPaths
    tmpfsOptions
    storageOptKeys
    storageOptValues
    readOnlyRootfs
    autoRemove
    cgroupsMode
    dns
    dnsOptions
    dnsSearch
    groupAdd
    ipcMode
    usernsMode
    sysctlsKeys
    sysctlsValues
    runtime
    logType
    logConfigKeys
    logConfigValues
    capAdd
    capDrop
    securityopt
    pidMode
    maskedPaths
    readonlyPaths
    deviceCgroupRules
    ulimitsName
    ulimitsSoft
    ulimitsHard
    volumeDriver
    image {
      reference
      credentials {
        id
        label
        username
      }
    }
    networks {
      edges {
        node {
          id
          driver
          internal
          label
          options
          enableIpv6
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
            driver
            options
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
    deviceRequests {
      edges {
        node {
          id
          driver
          count
          deviceIds
          capabilities
          options
        }
      }
    }
  }
`;

const FormRow = (props: FormRowProps) => (
  <BaseFormRow {...props} className="mb-2" />
);

const formatJson = (value: unknown) => {
  try {
    if (!value) return "";
    if (typeof value === "string")
      return JSON.stringify(JSON.parse(value), null, 2);
    return JSON.stringify(value, null, 2);
  } catch {
    return "";
  }
};

type SectionKey =
  | "image"
  | "process"
  | "healthcheck"
  | "network"
  | "storage"
  | "resourceLimits"
  | "blkio"
  | "securityCapabilities"
  | "runtimeEnvironment"
  | "logging"
  | "deviceMappings"
  | "deviceRequests";

const sectionsList: SectionKey[] = [
  "image",
  "network",
  "storage",
  "resourceLimits",
  "securityCapabilities",
  "runtimeEnvironment",
  "deviceMappings",
  "deviceRequests",
  "process",
  "healthcheck",
  "blkio",
  "logging",
];

type SectionProps = {
  label: MessageDescriptor;
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
};

const Section = ({ label, open, onToggle, children }: SectionProps) => (
  <CollapseItem
    title={<FormattedMessage {...label} />}
    open={open}
    onToggle={onToggle}
    caretPosition="right"
    className={`containerSectionCard ${open ? "pb-3 mb-2" : "mb-1"}`}
    headerClassName="fw-bold bg-transparent border-0 ps-0 pe-1 text-primary"
  >
    <Stack gap={2}>{children}</Stack>
  </CollapseItem>
);

interface PrimitiveFieldProps {
  id: string;
  label: MessageDescriptor;
  value?: string | number | null;
}

const PrimitiveField = ({ id, label, value }: PrimitiveFieldProps) => (
  <FormRow id={id} label={<FormattedMessage {...label} />}>
    <Form.Control value={value != null ? String(value) : ""} readOnly />
  </FormRow>
);

type CheckboxFieldProps = {
  id: string;
  label: MessageDescriptor;
  checked?: boolean;
};
const CheckboxField = ({ id, label, checked }: CheckboxFieldProps) => (
  <FormRow id={id} label={<FormattedMessage {...label} />}>
    <Form.Check type="checkbox" checked={checked === true} readOnly />
  </FormRow>
);

type StringArrayFieldProps = {
  id: string;
  label: MessageDescriptor;
  value?: readonly string[] | null;
};
const StringArrayField = ({ id, label, value }: StringArrayFieldProps) => (
  <FormRow id={id} label={<FormattedMessage {...label} />}>
    <StringArrayFormInput value={[...(value ?? [])]} mode="details" />
  </FormRow>
);

type JsonEditorFieldProps = {
  id: string;
  label: MessageDescriptor;
  value: unknown;
};
const JsonEditorField = ({ id, label, value }: JsonEditorFieldProps) => {
  const formatted = useMemo(() => formatJson(value), [value]);
  return (
    <FormRow id={id} label={<FormattedMessage {...label} />}>
      <MonacoJsonEditor
        value={formatted}
        defaultValue={formatted}
        onChange={() => {}}
        readonly
        initialLines={1}
      />
    </FormRow>
  );
};

type CapabilityFieldProps = {
  id: string;
  label: MessageDescriptor;
  value?: readonly string[] | null;
};
const CapabilityField = ({ id, label, value }: CapabilityFieldProps) => {
  const caps = [...(value ?? [])];

  return (
    <FormRow id={id} label={<FormattedMessage {...label} />}>
      {caps.length ? (
        <MultiSelect
          value={caps.map((cap) => ({ id: cap, name: cap }))}
          getOptionValue={(o) => o.id}
          getOptionLabel={(o) => o.name}
          disabled
        />
      ) : (
        <Form.Control value="" readOnly />
      )}
    </FormRow>
  );
};

type KeyValuePairsFieldProps = {
  id: string;
  label: MessageDescriptor;
  keys?: readonly string[] | null;
  values?: readonly string[] | null;
};
const KeyValuePairsField = ({
  id,
  label,
  keys,
  values,
}: KeyValuePairsFieldProps) => {
  const pairs = (keys ?? []).map((k, i) => `${k}=${values?.[i] ?? ""}`);
  return <StringArrayField id={id} label={label} value={pairs} />;
};

type PathOptionFieldProps = {
  id: string;
  label: MessageDescriptor;
  paths?: readonly string[] | null;
  options?: readonly string[] | null;
};
const PathOptionField = ({
  id,
  label,
  paths,
  options,
}: PathOptionFieldProps) => {
  const pairs = (paths ?? []).map((p, i) => `${p}:${options?.[i] ?? ""}`);
  return <StringArrayField id={id} label={label} value={pairs} />;
};

type UlimitsFieldProps = {
  ulimitsName?: readonly string[] | null;
  ulimitsSoft?: readonly number[] | null;
  ulimitsHard?: readonly number[] | null;
};
const UlimitsField = ({
  ulimitsName,
  ulimitsSoft,
  ulimitsHard,
}: UlimitsFieldProps) => {
  const rows = (ulimitsName ?? []).map(
    (name, i) =>
      `${name} soft=${ulimitsSoft?.[i] ?? ""} hard=${ulimitsHard?.[i] ?? ""}`,
  );
  return (
    <StringArrayField id="ulimits" label={messages.ulimits} value={rows} />
  );
};

type BlkioWeightDeviceFieldProps = {
  paths?: readonly string[] | null;
  weights?: readonly number[] | null;
};
const BlkioWeightDeviceField = ({
  paths,
  weights,
}: BlkioWeightDeviceFieldProps) => {
  const rows = (paths ?? []).map((p, i) => `${p}:${weights?.[i] ?? ""}`);
  return (
    <StringArrayField
      id="blkioWeightDevice"
      label={messages.blkioWeightDevice}
      value={rows}
    />
  );
};

type BlkioPathRateFieldProps = {
  id: string;
  label: MessageDescriptor;
  paths?: readonly string[] | null;
  rates?: readonly (number | string)[] | null;
};
const BlkioPathRateField = ({
  id,
  label,
  paths,
  rates,
}: BlkioPathRateFieldProps) => {
  const rows = (paths ?? []).map((p, i) => `${p}:${rates?.[i] ?? ""}`);
  return <StringArrayField id={id} label={label} value={rows} />;
};

const VolumeDetails = ({
  containerVolumes,
}: {
  containerVolumes: ContainerDetailsFragment$data["containerVolumes"];
}) => {
  const edges = containerVolumes?.edges ?? [];
  const { toggleSection, isSectionOpen } = useCollapsibleSections<number>(
    edges.map((_, i) => i),
  );

  return (
    <div className="mt-1 d-flex flex-column gap-2">
      <div className="mb-1 fw-semibold">
        <FormattedMessage {...messages.volumesLabel} />
      </div>

      {!edges.length ? (
        <p className="fst-italic mb-0">
          <FormattedMessage {...messages.noVolumes} />
        </p>
      ) : (
        edges.map((edge, index) => {
          const mount = edge.node;

          return (
            <CollapseItem
              key={mount?.volume.id ?? index}
              title={mount?.volume.label ?? `Volume ${index}`}
              open={isSectionOpen(index)}
              onToggle={() => toggleSection(index)}
              caretPosition="end"
              headerClassName="fw-bold border rounded"
              contentClassName="border rounded px-2 py-1 overflow-hidden"
              style={{ fontSize: "0.9rem" }}
            >
              <PrimitiveField
                id={`volume-${index}-target`}
                label={messages.targetLabel}
                value={mount?.target}
              />

              <PrimitiveField
                id={`volume-${index}-driver`}
                label={messages.volumeDriverLabel}
                value={mount?.volume.driver}
              />

              <JsonEditorField
                id={`volume-${index}-options`}
                label={messages.options}
                value={mount?.volume.options}
              />
            </CollapseItem>
          );
        })
      )}
    </div>
  );
};

const NetworkDetails = ({
  networks,
}: {
  networks: ContainerDetailsFragment$data["networks"];
}) => {
  const edges = networks?.edges ?? [];
  const { toggleSection, isSectionOpen } = useCollapsibleSections<number>(
    edges.map((_, i) => i),
  );

  return (
    <div className="mt-1 d-flex flex-column gap-2">
      <div className="mb-2">
        <FormattedMessage {...messages.networksLabel} />
      </div>
      {!edges.length ? (
        <p className="fst-italic">
          <FormattedMessage {...messages.noNetworks} />
        </p>
      ) : (
        edges.map((edge, index) => {
          const network = edge.node;
          return (
            <CollapseItem
              key={network?.id ?? index}
              title={network?.label ?? `Network ${index}`}
              open={isSectionOpen(index)}
              onToggle={() => toggleSection(index)}
              caretPosition="end"
              headerClassName="fw-bold border rounded"
              contentClassName="border rounded p-2"
              style={{ fontSize: "0.9rem" }}
            >
              <PrimitiveField
                id={`network-${index}-label`}
                label={messages.networkLabelLabel}
                value={network?.label}
              />

              <PrimitiveField
                id={`network-${index}-driver`}
                label={messages.networkDriverLabel}
                value={network?.driver}
              />

              <CheckboxField
                id={`network-${index}-internal`}
                label={messages.networkInternalLabel}
                checked={network?.internal}
              />

              <CheckboxField
                id={`network-${index}-ipv6`}
                label={messages.networkEnableIPv6Label}
                checked={network?.enableIpv6}
              />

              <JsonEditorField
                id={`network-${index}-options`}
                label={messages.networkOptionsLabel}
                value={network?.options}
              />
            </CollapseItem>
          );
        })
      )}
    </div>
  );
};

const DeviceMappingDetails = ({
  deviceMappings,
}: {
  deviceMappings: ContainerDetailsFragment$data["deviceMappings"];
}) => {
  const edges = deviceMappings?.edges ?? [];

  return (
    <>
      {!edges.length ? (
        <p className="fst-italic mb-0">
          <FormattedMessage {...messages.noDeviceMappings} />
        </p>
      ) : (
        <div className="p-2 mb-2 border rounded bg-light">
          <DeviceMappingsFormInput
            readOnly={true}
            readOnlyProps={{ deviceMappings: edges.map((e) => e.node) }}
            editableProps={null}
          />
        </div>
      )}
    </>
  );
};

const DeviceRequestDetails = ({
  deviceRequests,
}: {
  deviceRequests: ContainerDetailsFragment$data["deviceRequests"];
}) => {
  const edges = deviceRequests?.edges ?? [];

  const [selectedRequest, setSelectedRequest] = useState(0);

  if (!edges.length) {
    return (
      <p className="fst-italic mb-0">
        <FormattedMessage {...messages.noDeviceRequests} />
      </p>
    );
  }

  const request = edges[selectedRequest]?.node;

  return (
    <div className="d-flex align-items-stretch gap-4 mt-2">
      <div className="border-end pe-5">
        <Stack gap={1}>
          {edges.map((edge, index) => (
            <Button
              key={edge.node.id}
              variant="light"
              className={`pe-5 containerListItem ${selectedRequest === index ? "active" : ""}`}
              onClick={() => setSelectedRequest(index)}
            >
              <FormattedMessage
                id="components.apps.containers.container-details.ContainerDetails.deviceRequestIndex"
                defaultMessage="Request {index}"
                values={{ index: index + 1 }}
              />
            </Button>
          ))}
        </Stack>
      </div>

      <div className="flex-grow-1 ps-2 w-75">
        <Stack gap={2}>
          <PrimitiveField
            id="driver"
            label={messages.driver}
            value={request.driver}
          />

          <PrimitiveField
            id="count"
            label={messages.count}
            value={request.count}
          />

          <StringArrayField
            id="deviceIds"
            label={messages.deviceIDs}
            value={request.deviceIds}
          />

          <PrimitiveField
            id="capabilities"
            label={messages.capabilities}
            value={request.capabilities
              ?.map((group) => group.join(", "))
              .join(" OR ")}
          />

          <JsonEditorField
            id="options"
            label={messages.driverOptions}
            value={request.options}
          />
        </Stack>
      </div>
    </div>
  );
};

type SectionComponentProps = {
  data: ContainerDetailsFragment$data;
  open: boolean;
  onToggle: () => void;
};

const ImageSection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section label={messages.imageConfigSection} open={open} onToggle={onToggle}>
    <PrimitiveField
      id={`image-reference`}
      label={messages.imageReference}
      value={data.image?.reference}
    />

    <PrimitiveField
      id={`image-credentials`}
      label={messages.imageCredentials}
      value={
        data.image?.credentials
          ? `${data.image.credentials.label} (${data.image.credentials.username})`
          : ""
      }
    />
  </Section>
);

const ProcessSection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section label={messages.processSection} open={open} onToggle={onToggle}>
    <PrimitiveField id={`user`} label={messages.user} value={data.user} />
    <PrimitiveField
      id={`workingDirectory`}
      label={messages.workingDirectory}
      value={data.workingDirectory}
    />
    <PrimitiveField
      id={`command`}
      label={messages.command}
      value={data.command?.join(" ")}
    />
    <PrimitiveField
      id={`entrypoint`}
      label={messages.entrypoint}
      value={data.entrypoint?.join(" ")}
    />
  </Section>
);

const HealthcheckSection = ({
  data,
  open,
  onToggle,
}: SectionComponentProps) => (
  <Section label={messages.healthcheckSection} open={open} onToggle={onToggle}>
    <PrimitiveField
      id={`healthcheckTest`}
      label={messages.healthcheckTest}
      value={data.healthcheckTest?.join(" ")}
    />
    <PrimitiveField
      id={`healthcheckInterval`}
      label={messages.healthcheckInterval}
      value={data.healthcheckInterval}
    />
    <PrimitiveField
      id={`healthcheckTimeout`}
      label={messages.healthcheckTimeout}
      value={data.healthcheckTimeout}
    />
    <PrimitiveField
      id={`healthcheckRetries`}
      label={messages.healthcheckRetries}
      value={data.healthcheckRetries}
    />
    <PrimitiveField
      id={`healthcheckStartPeriod`}
      label={messages.healthcheckStartPeriod}
      value={data.healthcheckStartPeriod}
    />
    <PrimitiveField
      id={`healthcheckStartInterval`}
      label={messages.healthcheckStartInterval}
      value={data.healthcheckStartInterval}
    />
  </Section>
);

const NetworkSection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section
    label={messages.networkConfigSection}
    open={open}
    onToggle={onToggle}
  >
    <PrimitiveField
      id={`hostname`}
      label={messages.hostname}
      value={data.hostname}
    />

    <PrimitiveField
      id={`domainname`}
      label={messages.domainname}
      value={data.domainname}
    />

    <CheckboxField
      id={`networkDisabled`}
      label={messages.networkDisabled}
      checked={data.networkDisabled ?? false}
    />

    <PrimitiveField
      id={`networkMode`}
      label={messages.networkMode}
      value={data.networkMode}
    />

    <StringArrayField id={`dns`} label={messages.dns} value={data.dns} />

    <StringArrayField
      id={`dnsOptions`}
      label={messages.dnsOptions}
      value={data.dnsOptions}
    />

    <StringArrayField
      id={`dnsSearch`}
      label={messages.dnsSearch}
      value={data.dnsSearch}
    />

    <StringArrayField
      id={`extraHosts`}
      label={messages.extraHosts}
      value={data.extraHosts}
    />

    <StringArrayField
      id={`portBindings`}
      label={messages.portBindings}
      value={data.portBindings}
    />

    <StringArrayField
      id={`exposedPorts`}
      label={messages.exposedPorts}
      value={data.exposedPorts}
    />
    <NetworkDetails networks={data.networks} />
  </Section>
);

const StorageSection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section
    label={messages.storageConfigSection}
    open={open}
    onToggle={onToggle}
  >
    <StringArrayField id={`binds`} label={messages.binds} value={data.binds} />

    <PrimitiveField
      id={`volumeDriver`}
      label={messages.volumeDriver}
      value={data.volumeDriver}
    />

    <KeyValuePairsField
      id={`storageOpt`}
      label={messages.storageOpt}
      keys={data.storageOptKeys}
      values={data.storageOptValues}
    />

    <PathOptionField
      id={`tmpfs`}
      label={messages.tmpfs}
      paths={data.tmpfsPaths}
      options={data.tmpfsOptions}
    />

    <CheckboxField
      id={`readOnlyRootfs`}
      label={messages.readOnlyRootfs}
      checked={data.readOnlyRootfs}
    />

    <CheckboxField
      id={`autoRemove`}
      label={messages.autoRemove}
      checked={data.autoRemove ?? false}
    />

    <VolumeDetails containerVolumes={data.containerVolumes} />
  </Section>
);

const ResourceLimitsSection = ({
  data,
  open,
  onToggle,
}: SectionComponentProps) => (
  <Section
    label={messages.resourceLimitsSection}
    open={open}
    onToggle={onToggle}
  >
    <PrimitiveField id={`memory`} label={messages.memory} value={data.memory} />

    <PrimitiveField
      id={`memoryReservation`}
      label={messages.memoryReservation}
      value={data.memoryReservation}
    />

    <PrimitiveField
      id={`memorySwap`}
      label={messages.memorySwap}
      value={data.memorySwap}
    />

    <PrimitiveField
      id={`memorySwappiness`}
      label={messages.memorySwappiness}
      value={data.memorySwappiness}
    />

    <PrimitiveField
      id={`cpuShares`}
      label={messages.cpuShares}
      value={data.cpuShares}
    />
    <PrimitiveField
      id={`cpusetCpus`}
      label={messages.cpusetCpus}
      value={data.cpusetCpus}
    />

    <PrimitiveField
      id={`cpuPeriod`}
      label={messages.cpuPeriod}
      value={data.cpuPeriod}
    />

    <PrimitiveField
      id={`cpuQuota`}
      label={messages.cpuQuota}
      value={data.cpuQuota}
    />

    <PrimitiveField
      id={`cpuRealtimePeriod`}
      label={messages.cpuRealtimePeriod}
      value={data.cpuRealtimePeriod}
    />

    <PrimitiveField
      id={`cpuRealtimeRuntime`}
      label={messages.cpuRealtimeRuntime}
      value={data.cpuRealtimeRuntime}
    />

    <PrimitiveField
      id={`shmSize`}
      label={messages.shmSize}
      value={data.shmSize}
    />
    <PrimitiveField
      id={`oomScoreAdjustment`}
      label={messages.oomScoreAdjustment}
      value={data.oomScoreAdjustment}
    />
    <UlimitsField
      ulimitsName={data.ulimitsName}
      ulimitsSoft={data.ulimitsSoft}
      ulimitsHard={data.ulimitsHard}
    />
  </Section>
);

const BlkioSection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section label={messages.blkioSection} open={open} onToggle={onToggle}>
    <PrimitiveField
      id={`blkioWeight`}
      label={messages.blkioWeight}
      value={data.blkioWeight}
    />
    <BlkioWeightDeviceField
      paths={data.blkioWeightDevicePath}
      weights={data.blkioWeightDeviceWeight}
    />
    <BlkioPathRateField
      id={`blkioDeviceReadBps`}
      label={messages.blkioDeviceReadBps}
      paths={data.blkioDeviceReadBpsPath}
      rates={data.blkioDeviceReadBpsRate}
    />
    <BlkioPathRateField
      id={`blkioDeviceWriteBps`}
      label={messages.blkioDeviceWriteBps}
      paths={data.blkioDeviceWriteBpsPath}
      rates={data.blkioDeviceWriteBpsRate}
    />
    <BlkioPathRateField
      id={`blkioDeviceReadIops`}
      label={messages.blkioDeviceReadIops}
      paths={data.blkioDeviceReadIopsPath}
      rates={data.blkioDeviceReadIopsRate}
    />
    <BlkioPathRateField
      id={`blkioDeviceWriteIops`}
      label={messages.blkioDeviceWriteIops}
      paths={data.blkioDeviceWriteIopsPath}
      rates={data.blkioDeviceWriteIopsRate}
    />
  </Section>
);

const SecuritySection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section label={messages.securitySection} open={open} onToggle={onToggle}>
    <CheckboxField
      id={`privileged`}
      label={messages.privileged}
      checked={data.privileged ?? false}
    />

    <CapabilityField
      id={`capAdd`}
      label={messages.capAdd}
      value={data.capAdd}
    />

    <CapabilityField
      id={`capDrop`}
      label={messages.capDrop}
      value={data.capDrop}
    />

    <PrimitiveField
      id={`cgroupsMode`}
      label={messages.cgroupsMode}
      value={data.cgroupsMode}
    />
    <PrimitiveField
      id={`ipcMode`}
      label={messages.ipcMode}
      value={data.ipcMode}
    />
    <PrimitiveField
      id={`usernsMode`}
      label={messages.usernsMode}
      value={data.usernsMode}
    />
    <PrimitiveField
      id={`pidMode`}
      label={messages.pidMode}
      value={data.pidMode}
    />
    <StringArrayField
      id={`securityopt`}
      label={messages.securityopt}
      value={data.securityopt}
    />
    <StringArrayField
      id={`maskedPaths`}
      label={messages.maskedPaths}
      value={data.maskedPaths}
    />
    <StringArrayField
      id={`readonlyPaths`}
      label={messages.readonlyPaths}
      value={data.readonlyPaths}
    />
    <StringArrayField
      id={`groupAdd`}
      label={messages.groupAdd}
      value={data.groupAdd}
    />
    <StringArrayField
      id={`deviceCgroupRules`}
      label={messages.deviceCgroupRules}
      value={data.deviceCgroupRules}
    />
  </Section>
);

const RuntimeSection = ({ data, open, onToggle }: SectionComponentProps) => {
  const env = data.env?.reduce<Record<string, string | null>>((acc, item) => {
    acc[item.key] = item.value;
    return acc;
  }, {});

  return (
    <Section label={messages.runtimeSection} open={open} onToggle={onToggle}>
      <PrimitiveField
        id={`runtime`}
        label={messages.runtime}
        value={data.runtime}
      />
      <PrimitiveField
        id={`restartPolicy`}
        label={messages.restartPolicy}
        value={
          restartPolicyOptions.find((opt) => opt.value === data.restartPolicy)
            ?.label
        }
      />
      <PrimitiveField
        id={`restartPolicyMaximumRetryCount`}
        label={messages.restartPolicyMaximumRetryCount}
        value={data.restartPolicyMaximumRetryCount}
      />
      <PrimitiveField
        id={`stopSignal`}
        label={messages.stopSignal}
        value={data.stopSignal}
      />
      <PrimitiveField
        id={`stopTimeout`}
        label={messages.stopTimeout}
        value={data.stopTimeout}
      />
      <KeyValuePairsField
        id={`labels`}
        label={messages.labels}
        keys={data.labelKeys}
        values={data.labelValues}
      />
      <KeyValuePairsField
        id={`sysctls`}
        label={messages.sysctls}
        keys={data.sysctlsKeys}
        values={data.sysctlsValues}
      />
      <JsonEditorField id={`env`} label={messages.env} value={env} />
    </Section>
  );
};

const LoggingSection = ({ data, open, onToggle }: SectionComponentProps) => (
  <Section label={messages.loggingSection} open={open} onToggle={onToggle}>
    <PrimitiveField
      id={`logType`}
      label={messages.logType}
      value={data.logType}
    />
    <KeyValuePairsField
      id={`logConfig`}
      label={messages.logConfig}
      keys={data.logConfigKeys}
      values={data.logConfigValues}
    />
  </Section>
);

const DeviceMappingsSection = ({
  data,
  open,
  onToggle,
}: SectionComponentProps) => {
  return (
    <Section
      label={messages.deviceMappingsLabel}
      open={open}
      onToggle={onToggle}
    >
      <DeviceMappingDetails deviceMappings={data.deviceMappings} />
    </Section>
  );
};

const DeviceRequestsSection = ({
  data,
  open,
  onToggle,
}: SectionComponentProps) => (
  <Section label={messages.deviceRequestsLabel} open={open} onToggle={onToggle}>
    <DeviceRequestDetails deviceRequests={data.deviceRequests} />
  </Section>
);

type ContainerDetailsProps = {
  container: ContainerDetailsFragment$key;
};

const ContainerDetails = ({ container }: ContainerDetailsProps) => {
  const data = useFragment(CONTAINER_DETAILS_FRAGMENT, container);

  const { toggleSection, isSectionOpen } =
    useCollapsibleSections<SectionKey>(sectionsList);

  return (
    <div className="containerFormLayout">
      <ImageSection
        data={data}
        open={isSectionOpen("image")}
        onToggle={() => toggleSection("image")}
      />

      <NetworkSection
        data={data}
        open={isSectionOpen("network")}
        onToggle={() => toggleSection("network")}
      />

      <StorageSection
        data={data}
        open={isSectionOpen("storage")}
        onToggle={() => toggleSection("storage")}
      />

      <ResourceLimitsSection
        data={data}
        open={isSectionOpen("resourceLimits")}
        onToggle={() => toggleSection("resourceLimits")}
      />

      <SecuritySection
        data={data}
        open={isSectionOpen("securityCapabilities")}
        onToggle={() => toggleSection("securityCapabilities")}
      />

      <RuntimeSection
        data={data}
        open={isSectionOpen("runtimeEnvironment")}
        onToggle={() => toggleSection("runtimeEnvironment")}
      />

      <DeviceMappingsSection
        data={data}
        open={isSectionOpen("deviceMappings")}
        onToggle={() => toggleSection("deviceMappings")}
      />

      <DeviceRequestsSection
        data={data}
        open={isSectionOpen("deviceRequests")}
        onToggle={() => toggleSection("deviceRequests")}
      />

      <ProcessSection
        data={data}
        open={isSectionOpen("process")}
        onToggle={() => toggleSection("process")}
      />

      <HealthcheckSection
        data={data}
        open={isSectionOpen("healthcheck")}
        onToggle={() => toggleSection("healthcheck")}
      />

      <BlkioSection
        data={data}
        open={isSectionOpen("blkio")}
        onToggle={() => toggleSection("blkio")}
      />

      <LoggingSection
        data={data}
        open={isSectionOpen("logging")}
        onToggle={() => toggleSection("logging")}
      />
    </div>
  );
};

export { Section, messages, sectionsList };
export type { SectionKey };

export default ContainerDetails;
