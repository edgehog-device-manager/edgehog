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
  networkConfigSection: {
    id: "components.apps.containers.container-details.ContainerDetails.networkConfigSection",
    defaultMessage: "Network Configuration",
  },
  hostname: {
    id: "components.apps.containers.container-details.ContainerDetails.hostnameLabel",
    defaultMessage: "Hostname",
  },
  networkMode: {
    id: "components.apps.containers.container-details.ContainerDetails.networkModeLabel",
    defaultMessage: "Network Mode",
  },
  extraHosts: {
    id: "components.apps.containers.container-details.ContainerDetails.extraHostsLabel",
    defaultMessage: "Extra Hosts",
  },
  portBindings: {
    id: "components.apps.containers.container-details.ContainerDetails.portBindingsLabel",
    defaultMessage: "Port Bindings",
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
    defaultMessage: "Cap Add",
  },
  capDrop: {
    id: "components.apps.containers.container-details.ContainerDetails.capDrop",
    defaultMessage: "Cap Drop",
  },
  runtimeSection: {
    id: "components.apps.containers.container-details.ContainerDetails.runtimeSection",
    defaultMessage: "Runtime & Environment",
  },
  restartPolicy: {
    id: "components.apps.containers.container-details.ContainerDetails.restartPolicyLabel",
    defaultMessage: "Restart Policy",
  },
  env: {
    id: "components.apps.containers.container-details.ContainerDetails.envLabel",
    defaultMessage: "Environment (JSON String)",
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
    env {
      key
      value
    }
    extraHosts
    hostname
    networkMode
    portBindings
    binds
    restartPolicy
    privileged
    memory
    memorySwap
    memoryReservation
    memorySwappiness
    cpuPeriod
    cpuQuota
    cpuRealtimePeriod
    cpuRealtimeRuntime
    tmpfs
    storageOpt
    readOnlyRootfs
    capAdd
    capDrop
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
  | "network"
  | "storage"
  | "resourceLimits"
  | "securityCapabilities"
  | "runtimeEnvironment"
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
      id={`networkMode`}
      label={messages.networkMode}
      value={data.networkMode}
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

    <StringArrayField
      id={`storageOpt`}
      label={messages.storageOpt}
      value={data.storageOpt}
    />

    <StringArrayField id={`tmpfs`} label={messages.tmpfs} value={data.tmpfs} />

    <CheckboxField
      id={`readOnlyRootfs`}
      label={messages.readOnlyRootfs}
      checked={data.readOnlyRootfs}
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
        id={`restartPolicy`}
        label={messages.restartPolicy}
        value={
          restartPolicyOptions.find((opt) => opt.value === data.restartPolicy)
            ?.label
        }
      />
      <JsonEditorField id={`env`} label={messages.env} value={env} />
    </Section>
  );
};

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
    </div>
  );
};

export { Section, messages, sectionsList };
export type { SectionKey };

export default ContainerDetails;
