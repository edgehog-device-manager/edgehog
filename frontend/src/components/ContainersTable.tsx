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

import React, { useCallback, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import Collapse from "react-bootstrap/Collapse";
import Button from "react-bootstrap/Button";
import { Stack } from "react-bootstrap";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronDown, faChevronUp } from "@fortawesome/free-solid-svg-icons";

import type { ContainersTable_PaginationQuery } from "api/__generated__/ContainersTable_PaginationQuery.graphql";
import type {
  ContainersTable_ContainerFragment$data,
  ContainersTable_ContainerFragment$key,
} from "api/__generated__/ContainersTable_ContainerFragment.graphql";

import Form from "components/Form";
import StringArrayFormInput from "components/StringArrayFormInput";
import MonacoJsonEditor from "components/MonacoJsonEditor";
import MultiSelect from "./MultiSelect";
import InfiniteScroll from "./InfiniteScroll";
import DeviceMappingsFormInput from "components/DeviceMappingsFormInput";
import { FormRow as BaseFormRow, FormRowProps } from "components/FormRow";
import { restartPolicyOptions } from "forms/CreateRelease";
import { RECORDS_TO_LOAD_NEXT } from "constants";

const FormRow = (props: FormRowProps) => (
  <BaseFormRow {...props} className="mb-2" />
);

/* eslint-disable relay/unused-fields */
const CONTAINERS_TABLE_FRAGMENT = graphql`
  fragment ContainersTable_ContainerFragment on Release
  @refetchable(queryName: "ContainersTable_PaginationQuery") {
    containers(first: $first, after: $after)
      @connection(key: "ContainersTable_containers") {
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

type volumeDetailsProps = {
  containerVolumes: NonNullable<
    ContainersTable_ContainerFragment$data["containers"]["edges"]
  >[number]["node"]["containerVolumes"];
  containerIndex: number;
};

const VolumeDetails = ({
  containerVolumes,
  containerIndex,
}: volumeDetailsProps) => {
  const [openVolumeIndexes, setOpenVolumeIndexes] = useState<number[]>(
    containerVolumes.edges?.map((_, index) => index) ?? [],
  );

  const toggleVolume = (index: number) => {
    setOpenVolumeIndexes((current) =>
      current.includes(index)
        ? current.filter((i) => i !== index)
        : [...current, index],
    );
  };

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
          const isOpen = openVolumeIndexes.includes(volIndex);

          return (
            <div
              key={mount?.volume.id ?? volIndex}
              className="mb-2 border rounded bg-light"
            >
              <Button
                variant="light"
                className="w-100 d-flex align-items-center"
                onClick={() => toggleVolume(volIndex)}
                aria-expanded={isOpen}
              >
                {mount?.volume.label}
                <span className="ms-auto">
                  {isOpen ? (
                    <FontAwesomeIcon icon={faChevronUp} />
                  ) : (
                    <FontAwesomeIcon icon={faChevronDown} />
                  )}
                </span>
              </Button>

              <Collapse in={isOpen}>
                <div className="p-2 border-top">
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
                </div>
              </Collapse>
            </div>
          );
        })
      )}
    </div>
  );
};

type networkDetailsProps = {
  networks: NonNullable<
    ContainersTable_ContainerFragment$data["containers"]["edges"]
  >[number]["node"]["networks"];
  containerIndex: number;
};

const NetworkDetails = ({ networks, containerIndex }: networkDetailsProps) => {
  const [openNetworkIndexes, setOpenNetworkIndexes] = useState<number[]>(
    networks.edges?.map((_, index) => index) ?? [],
  );

  const toggleNetwork = (index: number) => {
    setOpenNetworkIndexes((current) =>
      current.includes(index)
        ? current.filter((i) => i !== index)
        : [...current, index],
    );
  };

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
          const isOpen = openNetworkIndexes.includes(netIndex);

          return (
            <div
              key={net?.id ?? netIndex}
              className="mb-2 border rounded bg-light"
            >
              <Button
                variant="light"
                className="w-100 d-flex align-items-center"
                onClick={() => toggleNetwork(netIndex)}
                aria-expanded={isOpen}
              >
                {net?.label}
                <span className="ms-auto">
                  {isOpen ? (
                    <FontAwesomeIcon icon={faChevronUp} />
                  ) : (
                    <FontAwesomeIcon icon={faChevronDown} />
                  )}
                </span>
              </Button>

              <Collapse in={isOpen}>
                <div className="p-2 border-top">
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
                </div>
              </Collapse>
            </div>
          );
        })
      )}
    </div>
  );
};

type DeviceMappingDetailsProps = {
  deviceMappings: NonNullable<
    ContainersTable_ContainerFragment$data["containers"]["edges"]
  >[number]["node"]["deviceMappings"];
  containerIndex?: number;
};

const DeviceMappingDetails = ({
  deviceMappings,
}: DeviceMappingDetailsProps) => {
  const dmFormInputProps = { deviceMappings: deviceMappings };
  return (
    <div className="mt-3">
      <h6>
        <FormattedMessage
          id="components.ContainersTable.deviceMappingsLabel"
          defaultMessage="Device Mappings"
        />
      </h6>

      {!deviceMappings?.edges?.length ? (
        <p className="fst-italic">
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
    </div>
  );
};

type ContainerRecord = NonNullable<
  ContainersTable_ContainerFragment$data["containers"]["edges"]
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
const ContainerDetails = ({ container, index }: ContainerDetailsProps) => {
  return (
    <div style={styles.detailsWrapper}>
      {/* Image Configuration Section */}
      <div className="border-bottom pb-3 mt-2">
        <h6 className="mb-3">
          <FormattedMessage
            id="forms.ContainersTable.imageConfigSection"
            defaultMessage="Image Configuration"
          />
        </h6>
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
      </div>
      {/* Network Configuration Section */}
      <div className="border-bottom pb-3">
        <h6 className="mt-3 mb-3">
          <FormattedMessage
            id="forms.ContainersTable.networkConfigSection"
            defaultMessage="Network Configuration"
          />
        </h6>
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
      </div>
      {/* Storage Configuration Section */}
      <div className="border-bottom pb-3">
        <h6 className="mt-3 mb-3">
          <FormattedMessage
            id="forms.ContainersTable.storageConfigSection"
            defaultMessage="Storage Configuration"
          />
        </h6>
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
      </div>
      {/* Resource Limits Section */}
      <div className="border-bottom pb-3">
        <h6 className="mt-3 mb-3">
          <FormattedMessage
            id="forms.ContainersTable.resourceLimitsSection"
            defaultMessage="Resource Limits"
          />
        </h6>
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
      </div>
      {/* Security & Capabilities Section */}
      <div className="border-bottom pb-3">
        <h6 className="mt-3 mb-3">
          <FormattedMessage
            id="forms.ContainersTable.securitySection"
            defaultMessage="Security & Capabilities"
          />
        </h6>
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
      </div>
      {/* Runtime & Environment Section */}
      <div className="border-bottom pb-3">
        <h6 className="mt-3 mb-3">
          <FormattedMessage
            id="forms.ContainersTable.runtimeSection"
            defaultMessage="Runtime & Environment"
          />
        </h6>
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
      </div>
      <DeviceMappingDetails deviceMappings={container.deviceMappings} />
    </div>
  );
};

type ContainersTableProps = {
  className?: string;
  containersRef: ContainersTable_ContainerFragment$key;
};

const ContainersTable = ({
  className,
  containersRef,
}: ContainersTableProps) => {
  const { data, loadNext, hasNext, isLoadingNext } = usePaginationFragment<
    ContainersTable_PaginationQuery,
    ContainersTable_ContainerFragment$key
  >(CONTAINERS_TABLE_FRAGMENT, containersRef);

  const loadNextContainers = useCallback(() => {
    if (hasNext && !isLoadingNext) loadNext(RECORDS_TO_LOAD_NEXT);
  }, [hasNext, isLoadingNext, loadNext]);

  const containers: ContainerRecord[] = useMemo(() => {
    return data.containers?.edges?.map((edge) => edge?.node) ?? [];
  }, [data]);

  const [openIndexes, setOpenIndexes] = useState<number[]>(
    containers.map((_, index) => index),
  );
  const toggleIndex = (index: number) => {
    setOpenIndexes((current) =>
      current.includes(index)
        ? current.filter((i) => i !== index)
        : [...current, index],
    );
  };

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
        <div key={container.id ?? index} className="mb-3 border rounded">
          <Button
            variant="light"
            className="w-100 d-flex align-items-center fw-bold"
            onClick={() => toggleIndex(index)}
          >
            {container.image.reference}
            <span className="ms-auto">
              {openIndexes.includes(index) ? (
                <FontAwesomeIcon icon={faChevronUp} />
              ) : (
                <FontAwesomeIcon icon={faChevronDown} />
              )}
            </span>
          </Button>
          <InfiniteScroll
            className={className}
            loading={isLoadingNext}
            onLoadMore={hasNext ? loadNextContainers : undefined}
          >
            <Collapse in={openIndexes.includes(index)}>
              <div className="p-3 border-top">
                <ContainerDetails container={container} index={index} />
              </div>
            </Collapse>
          </InfiniteScroll>
        </div>
      ))}
    </div>
  );
};

export default ContainersTable;
