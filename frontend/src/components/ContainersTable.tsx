// This file is part of Edgehog.
//
// Copyright 2024-2026 SECO Mind Srl
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

import _ from "lodash";
import { useMemo, useState } from "react";
import { Stack } from "react-bootstrap";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ContainersTable_ContainerEdgeFragment$data,
  ContainersTable_ContainerEdgeFragment$key,
} from "@/api/__generated__/ContainersTable_ContainerEdgeFragment.graphql";

import CollapseItem, {
  useCollapsibleSections,
} from "@/components/CollapseItem";
import DeviceMappingsFormInput from "@/components/DeviceMappingsFormInput";
import Form from "@/components/Form";
import { FormRow as BaseFormRow, FormRowProps } from "@/components/FormRow";
import MonacoJsonEditor from "@/components/MonacoJsonEditor";
import StringArrayFormInput from "@/components/StringArrayFormInput";
import { restartPolicyOptions } from "@/forms/CreateRelease";
import InfiniteScroll from "./InfiniteScroll";
import MultiSelect from "./MultiSelect";

const FormRow = (props: FormRowProps) => (
  <BaseFormRow {...props} className="mb-2" />
);

/* eslint-disable relay/unused-fields */
const CONTAINERS_TABLE_FRAGMENT = graphql`
  fragment ContainersTable_ContainerEdgeFragment on ContainerConnection {
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
      }
    }
  }
`;

const styles = {
  containerWrapper: {
    border: "1px solid #ccc",
    marginBottom: 16,
    borderRadius: 4,
  },
  toggleButton: (isOpen: boolean) => ({
    width: "100%",
    padding: 10,
    textAlign: "left",
    background: isOpen ? "#eee" : "#f9f9f9",
    border: "none",
    cursor: "pointer",
    fontWeight: "bold",
  }),
  detailsWrapper: {
    padding: 12,
  },
};

const formatJson = (jsonString: unknown) => {
  try {
    if (!jsonString) return "";
    if (typeof jsonString === "string") {
      return JSON.stringify(JSON.parse(jsonString), null, 2);
    }
    return JSON.stringify(jsonString, null, 2);
  } catch (err) {
    return "";
  }
};

type VolumeDetailsProps = {
  containerVolumes: NonNullable<
    ContainersTable_ContainerEdgeFragment$data["edges"]
  >[number]["node"]["containerVolumes"];
  containerIndex: number;
};

const VolumeDetails = ({
  containerVolumes,
  containerIndex,
}: VolumeDetailsProps) => {
  const { toggleSection: toggleVolume, isSectionOpen } =
    useCollapsibleSections<number>(
      containerVolumes.edges?.map((_, index) => index) ?? [],
    );

  return (
    <div className="mt-1">
      <div className="mb-2">
        <FormattedMessage
          id="components.ContainersTable.volumesLabel"
          defaultMessage="Volumes"
        />
      </div>

      {!containerVolumes?.edges?.length ? (
        <p className="fst-italic">
          <FormattedMessage
            id="components.ContainersTable.noVolumes"
            defaultMessage="No volumes assigned."
          />
        </p>
      ) : (
        containerVolumes.edges.map((volEdge, volIndex) => {
          const mount = volEdge.node;

          return (
            <div key={mount?.volume.id ?? volIndex}>
              <CollapseItem
                title={mount?.volume.label ?? `Volume ${volIndex}`}
                open={isSectionOpen(volIndex)}
                onToggle={() => toggleVolume(volIndex)}
              >
                <FormRow
                  id={`containers-${containerIndex}-volume-${volIndex}-target`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.targetLabel"
                      defaultMessage="Target"
                    />
                  }
                >
                  <Form.Control value={mount?.target ?? ""} readOnly />
                </FormRow>

                <FormRow
                  id={`containers-${containerIndex}-volume-${volIndex}-label`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.volumeLabelLabel"
                      defaultMessage="Label"
                    />
                  }
                >
                  <Form.Control value={mount?.volume.label ?? ""} readOnly />
                </FormRow>

                <FormRow
                  id={`containers-${containerIndex}-volume-${volIndex}-driver`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.volumeDriverLabel"
                      defaultMessage="Driver"
                    />
                  }
                >
                  <Form.Control value={mount?.volume.driver ?? ""} readOnly />
                </FormRow>
                <FormRow
                  id="volumeOptions"
                  label={
                    <FormattedMessage
                      id="pages.volume.options"
                      defaultMessage="Options"
                    />
                  }
                >
                  <MonacoJsonEditor
                    value={formatJson(mount?.volume.options)}
                    onChange={() => {}}
                    defaultValue={formatJson(mount?.volume.options)}
                    readonly={true}
                    initialLines={1}
                  />
                </FormRow>
              </CollapseItem>
            </div>
          );
        })
      )}
    </div>
  );
};

type NetworkDetailsProps = {
  networks: NonNullable<
    ContainersTable_ContainerEdgeFragment$data["edges"]
  >[number]["node"]["networks"];
  containerIndex: number;
};

const NetworkDetails = ({ networks, containerIndex }: NetworkDetailsProps) => {
  const { toggleSection: toggleNetwork, isSectionOpen } =
    useCollapsibleSections<number>(
      networks.edges?.map((_, index) => index) ?? [],
    );

  return (
    <div className="mt-1">
      <div className="mb-2">
        <FormattedMessage
          id="components.ContainersTable.networksLabel"
          defaultMessage="Networks"
        />
      </div>

      {!networks?.edges?.length ? (
        <p className="fst-italic">
          <FormattedMessage
            id="components.ContainersTable.noNetworks"
            defaultMessage="No networks assigned."
          />
        </p>
      ) : (
        networks.edges.map((netEdge, netIndex) => {
          const net = netEdge.node;

          return (
            <div key={net?.id ?? netIndex}>
              <CollapseItem
                title={net.label ?? `Network ${netIndex}`}
                open={isSectionOpen(netIndex)}
                onToggle={() => toggleNetwork(netIndex)}
              >
                <FormRow
                  id={`containers-${containerIndex}-network-${netIndex}-label`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.networkLabelLabel"
                      defaultMessage="Label"
                    />
                  }
                >
                  <Form.Control value={net?.label ?? ""} readOnly />
                </FormRow>

                <FormRow
                  id={`containers-${containerIndex}-network-${netIndex}-driver`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.networkDriverLabel"
                      defaultMessage="Driver"
                    />
                  }
                >
                  <Form.Control value={net?.driver ?? ""} readOnly />
                </FormRow>

                <FormRow
                  id={`containers-${containerIndex}-network-${netIndex}-internal`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.networkInternalLabel"
                      defaultMessage="Internal"
                    />
                  }
                >
                  <Form.Check
                    type="checkbox"
                    checked={net?.internal === true}
                    readOnly
                  />
                </FormRow>

                <FormRow
                  id={`containers-${containerIndex}-network-${netIndex}-enableipv6`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.networkEnableIPv6Label"
                      defaultMessage="Enable IPv6"
                    />
                  }
                >
                  <Form.Check
                    type="checkbox"
                    checked={net?.enableIpv6 === true}
                    readOnly
                  />
                </FormRow>

                <FormRow
                  id={`containers-${containerIndex}-network-${netIndex}-options`}
                  label={
                    <FormattedMessage
                      id="components.ContainersTable.networkOptionsLabel"
                      defaultMessage="Options (JSON)"
                    />
                  }
                >
                  <MonacoJsonEditor
                    value={formatJson(net?.options)}
                    onChange={() => {}}
                    defaultValue={formatJson(net?.options)}
                    readonly={true}
                    initialLines={1}
                  />
                </FormRow>
              </CollapseItem>
            </div>
          );
        })
      )}
    </div>
  );
};

type DeviceMappingDetailsProps = {
  deviceMappings: NonNullable<
    ContainersTable_ContainerEdgeFragment$data["edges"]
  >[number]["node"]["deviceMappings"];
  containerIndex?: number;
};

const DeviceMappingDetails = ({
  deviceMappings,
}: DeviceMappingDetailsProps) => {
  const dmFormInputProps = { deviceMappings };
  const [open, setOpen] = useState(true);

  return (
    <CollapseItem
      type="flat"
      title={
        <FormattedMessage
          id="components.ContainersTable.deviceMappingsLabel"
          defaultMessage="Device Mappings"
        />
      }
      open={open}
      onToggle={() => setOpen((o) => !o)}
    >
      {!deviceMappings?.edges?.length ? (
        <p className="fst-italic mb-0">
          <FormattedMessage
            id="components.ContainersTable.noDeviceMappings"
            defaultMessage="No device mappings assigned."
          />
        </p>
      ) : (
        <div className="p-2 mb-2 border rounded bg-light">
          <DeviceMappingsFormInput
            readOnly={true}
            readOnlyProps={dmFormInputProps}
            editableProps={null}
          />
        </div>
      )}
    </CollapseItem>
  );
};

type ContainerRecord = NonNullable<
  ContainersTable_ContainerEdgeFragment$data["edges"]
>[number]["node"];
type ContainerEnv = ContainerRecord["env"];

const formatEnvJson = (env: ContainerEnv) => {
  const reducedEnv = env
    ? env.reduce((acc: any, envVar) => {
        acc[envVar.key] = envVar.value;
        return acc;
      }, {})
    : env;
  return formatJson(reducedEnv);
};

type ContainerDetailsProps = {
  container: ContainerRecord;
  index: number;
};

type ContainerSection =
  | "image"
  | "network"
  | "storage"
  | "resourceLimits"
  | "security"
  | "runtime";

const ContainerDetails = ({ container, index }: ContainerDetailsProps) => {
  const { toggleSection, isSectionOpen } =
    useCollapsibleSections<ContainerSection>([
      "image",
      "network",
      "storage",
      "resourceLimits",
      "security",
      "runtime",
    ]);

  return (
    <div style={styles.detailsWrapper}>
      {/* Image Configuration Section */}
      <CollapseItem
        type="flat"
        open={isSectionOpen("image")}
        onToggle={() => toggleSection("image")}
        title={
          <FormattedMessage
            id="forms.ContainersTable.imageConfigSection"
            defaultMessage="Image Configuration"
          />
        }
      >
        <Stack gap={2}>
          <FormRow
            id={`containers-${index}-image-reference`}
            label={
              <FormattedMessage
                id="components.ContainersTable.imageReferenceLabel"
                defaultMessage="Image Reference"
              />
            }
          >
            <Form.Control value={container.image?.reference ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-image-credentials`}
            label={
              <FormattedMessage
                id="components.ContainersTable.imageCredentialsLabel"
                defaultMessage="Image Credentials"
              />
            }
          >
            <Form.Control
              value={
                container.image?.credentials
                  ? `${container.image.credentials.label} (${container.image.credentials.username})`
                  : ""
              }
              readOnly
            />
          </FormRow>
        </Stack>
      </CollapseItem>

      {/* Network Configuration Section */}
      <CollapseItem
        type="flat"
        open={isSectionOpen("network")}
        onToggle={() => toggleSection("network")}
        title={
          <FormattedMessage
            id="forms.ContainersTable.networkConfigSection"
            defaultMessage="Network Configuration"
          />
        }
      >
        <Stack gap={2}>
          <FormRow
            id={`containers-${index}-hostname`}
            label={
              <FormattedMessage
                id="components.ContainersTable.hostnameLabel"
                defaultMessage="Hostname"
              />
            }
          >
            <Form.Control value={container.hostname ?? ""} readOnly />
          </FormRow>
          <FormRow
            id={`containers-${index}-networkMode`}
            label={
              <FormattedMessage
                id="components.ContainersTable.networkModeLabel"
                defaultMessage="Network Mode"
              />
            }
          >
            <Form.Control value={container.networkMode ?? ""} readOnly />
          </FormRow>
          <FormRow
            id={`containers-${index}-extraHosts`}
            label={
              <FormattedMessage
                id="components.ContainersTable.extraHostsLabel"
                defaultMessage="Extra Hosts"
              />
            }
          >
            <StringArrayFormInput
              value={Array.from(container.extraHosts ?? [])}
              mode="details"
            />
          </FormRow>
          <FormRow
            id={`containers-${index}-portBindings`}
            label={
              <FormattedMessage
                id="components.ContainersTable.portBindingsLabel"
                defaultMessage="Port Bindings"
              />
            }
          >
            <StringArrayFormInput
              value={Array.from(container.portBindings ?? [])}
              mode="details"
            />
          </FormRow>
          <NetworkDetails
            networks={container.networks}
            containerIndex={index}
          />
        </Stack>
      </CollapseItem>

      {/* Storage Configuration Section */}
      <CollapseItem
        type="flat"
        open={isSectionOpen("storage")}
        onToggle={() => toggleSection("storage")}
        title={
          <FormattedMessage
            id="forms.ContainersTable.storageConfigSection"
            defaultMessage="Storage Configuration"
          />
        }
      >
        <Stack gap={2}>
          <FormRow
            id={`containers-${index}-binds`}
            label={
              <FormattedMessage
                id="components.ContainersTable.bindsLabel"
                defaultMessage="Binds"
              />
            }
          >
            <StringArrayFormInput
              value={Array.from(container.binds ?? [])}
              mode="details"
            />
          </FormRow>
          <FormRow
            id={`containers-${index}-volumeDriver`}
            label={
              <FormattedMessage
                id="components.ContainersTable.volumeDriver"
                defaultMessage="Volume Driver"
              />
            }
          >
            <Form.Control value={container.volumeDriver ?? ""} readOnly />
          </FormRow>
          <FormRow
            id={`containers-${index}-storageOpt`}
            label={
              <FormattedMessage
                id="components.ContainersTable.storageOptLabel"
                defaultMessage="Storage Options"
              />
            }
          >
            <StringArrayFormInput
              value={Array.from(container.storageOpt ?? [])}
              mode="details"
            />
          </FormRow>
          <FormRow
            id={`containers-${index}-tmpfs`}
            label={
              <FormattedMessage
                id="components.ContainersTable.tmpfsLabel"
                defaultMessage="Tmpfs"
              />
            }
          >
            <StringArrayFormInput
              value={Array.from(container.tmpfs ?? [])}
              mode="details"
            />
          </FormRow>
          <FormRow
            id={`containers-${index}-readOnlyRootfs`}
            label={
              <FormattedMessage
                id="components.ContainersTable.readOnlyRootfsLabel"
                defaultMessage="Read-Only Root Filesystem"
              />
            }
          >
            <Form.Check
              type="checkbox"
              checked={container.readOnlyRootfs === true}
              readOnly
            />
          </FormRow>
          <VolumeDetails
            containerVolumes={container.containerVolumes}
            containerIndex={index}
          />
        </Stack>
      </CollapseItem>

      {/* Resource Limits Section */}
      <CollapseItem
        type="flat"
        open={isSectionOpen("resourceLimits")}
        onToggle={() => toggleSection("resourceLimits")}
        title={
          <FormattedMessage
            id="forms.ContainersTable.resourceLimitsSection"
            defaultMessage="Resource Limits"
          />
        }
      >
        <Stack gap={2}>
          <FormRow
            id={`containers-${index}-memory`}
            label={
              <FormattedMessage
                id="components.ContainersTable.memoryLabel"
                defaultMessage="Memory (bytes)"
              />
            }
          >
            <Form.Control value={container.memory ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-memoryReservation`}
            label={
              <FormattedMessage
                id="components.ContainersTable.memoryReservationLabel"
                defaultMessage="Memory Reservation (bytes)"
              />
            }
          >
            <Form.Control value={container.memoryReservation ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-memorySwap`}
            label={
              <FormattedMessage
                id="components.ContainersTable.memorySwapLabel"
                defaultMessage="Memory + Swap (bytes)"
              />
            }
          >
            <Form.Control value={container.memorySwap ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-memorySwappiness`}
            label={
              <FormattedMessage
                id="components.ContainersTable.memorySwappinessLabel"
                defaultMessage="Memory Swappiness (0-100)"
              />
            }
          >
            <Form.Control value={container.memorySwappiness ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-cpuPeriod`}
            label={
              <FormattedMessage
                id="components.ContainersTable.cpuPeriodLabel"
                defaultMessage="CPU Period (microseconds)"
              />
            }
          >
            <Form.Control value={container.cpuPeriod ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-cpuQuota`}
            label={
              <FormattedMessage
                id="components.ContainersTable.cpuQuotaLabel"
                defaultMessage="CPU Quota (microseconds)"
              />
            }
          >
            <Form.Control value={container.cpuQuota ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-cpuRealtimePeriod`}
            label={
              <FormattedMessage
                id="components.ContainersTable.cpuRealtimePeriodLabel"
                defaultMessage="CPU Real Time Period (microseconds)"
              />
            }
          >
            <Form.Control value={container.cpuRealtimePeriod ?? ""} readOnly />
          </FormRow>

          <FormRow
            id={`containers-${index}-cpuRealtimeRuntime`}
            label={
              <FormattedMessage
                id="components.ContainersTable.cpuRealtimeRuntimeLabel"
                defaultMessage="CPU Realtime Runtime (microseconds)"
              />
            }
          >
            <Form.Control value={container.cpuRealtimeRuntime ?? ""} readOnly />
          </FormRow>
        </Stack>
      </CollapseItem>

      {/* Security & Capabilities Section */}
      <CollapseItem
        type="flat"
        open={isSectionOpen("security")}
        onToggle={() => toggleSection("security")}
        title={
          <FormattedMessage
            id="forms.ContainersTable.securitySection"
            defaultMessage="Security & Capabilities"
          />
        }
      >
        <Stack gap={2}>
          <FormRow
            id={`containers-${index}-privileged`}
            label={
              <FormattedMessage
                id="components.ContainersTable.privilegedLabel"
                defaultMessage="Privileged"
              />
            }
          >
            <Form.Check
              type="checkbox"
              checked={container.privileged === true}
              readOnly
            />
          </FormRow>
          <FormRow
            id={`containers-${index}-capAdd`}
            label={
              <FormattedMessage
                id="components.ContainersTable.capAdd"
                defaultMessage="Cap Add"
              />
            }
          >
            {(container.capAdd || []).length > 0 ? (
              <MultiSelect
                value={(container.capAdd || []).map((cap) => ({
                  id: cap,
                  name: cap,
                }))}
                getOptionValue={(option) => option.id}
                getOptionLabel={(option) => option.name}
                disabled={true}
              />
            ) : (
              <Form.Control
                value={(container.capAdd ?? []).join(", ")}
                readOnly
              />
            )}
          </FormRow>

          <FormRow
            id={`containers-${index}-capDrop`}
            label={
              <FormattedMessage
                id="components.ContainersTable.capDrop"
                defaultMessage="Cap Drop"
              />
            }
          >
            {(container.capDrop || []).length > 0 ? (
              <MultiSelect
                value={(container.capDrop || []).map((cap) => ({
                  id: cap,
                  name: cap,
                }))}
                getOptionValue={(option) => option.id}
                getOptionLabel={(option) => option.name}
                disabled={true}
              />
            ) : (
              <Form.Control
                value={(container.capDrop ?? []).join(", ")}
                readOnly
              />
            )}
          </FormRow>
        </Stack>
      </CollapseItem>

      {/* Runtime & Environment Section */}
      <CollapseItem
        type="flat"
        open={isSectionOpen("runtime")}
        onToggle={() => toggleSection("runtime")}
        title={
          <FormattedMessage
            id="forms.ContainersTable.runtimeSection"
            defaultMessage="Runtime & Environment"
          />
        }
      >
        <Stack gap={2}>
          <FormRow
            id={`containers-${index}-restartPolicy`}
            label={
              <FormattedMessage
                id="components.ContainersTable.restartPolicyLabel"
                defaultMessage="Restart Policy"
              />
            }
          >
            <Form.Control
              value={
                restartPolicyOptions.find(
                  (opt) => opt.value === container.restartPolicy,
                )?.label ?? ""
              }
              readOnly
            />
          </FormRow>
          <FormRow
            id={`containers-${index}-env`}
            label={
              <FormattedMessage
                id="components.ContainersTable.envLabel"
                defaultMessage="Environment (JSON String)"
              />
            }
          >
            <MonacoJsonEditor
              value={formatEnvJson(container.env)}
              onChange={() => {}}
              defaultValue={formatEnvJson(container.env)}
              readonly={true}
              initialLines={1}
            />
          </FormRow>
        </Stack>
      </CollapseItem>
      <DeviceMappingDetails deviceMappings={container.deviceMappings} />
    </div>
  );
};

type ContainersTableProps = {
  className?: string;
  containersRef: ContainersTable_ContainerEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const ContainersTable = ({
  className,
  containersRef,
  loading = false,
  onLoadMore,
}: ContainersTableProps) => {
  const containersFragment = useFragment(
    CONTAINERS_TABLE_FRAGMENT,
    containersRef || null,
  );
  const containers = useMemo<ContainerRecord[]>(() => {
    return _.compact(containersFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [containersFragment]);

  const { toggleSection: toggleIndex, isSectionOpen } =
    useCollapsibleSections<number>(containers.map((_, index) => index));

  if (containers.length === 0) {
    return (
      <div className={className}>
        <p>
          <FormattedMessage
            id="components.ContainersTable.noContainers"
            defaultMessage="No containers available."
          />
        </p>
      </div>
    );
  }

  return (
    <div className={className}>
      {containers.map((container, index) => (
        <InfiniteScroll
          key={container.id}
          className={className}
          loading={loading}
          onLoadMore={onLoadMore}
        >
          <CollapseItem
            type="card-parent"
            title={container.image.reference}
            open={isSectionOpen(index)}
            onToggle={() => toggleIndex(index)}
          >
            <ContainerDetails container={container} index={index} />
          </CollapseItem>
        </InfiniteScroll>
      ))}
    </div>
  );
};

export default ContainersTable;
