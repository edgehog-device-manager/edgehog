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

import { useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { useRelayEnvironment } from "react-relay";
import { fetchQuery, graphql, useLazyLoadQuery } from "react-relay/hooks";
import Select from "react-select";

import { ReuseContainerModal_getContainerDetails_Query } from "@/api/__generated__/ReuseContainerModal_getContainerDetails_Query.graphql";
import { ReuseContainerModal_getContainers_Query } from "@/api/__generated__/ReuseContainerModal_getContainers_Query.graphql";

import ConfirmModal from "@/components/ConfirmModal";
import { FormRow } from "@/components/FormRow";
import {
  CapAddList,
  CapDropList,
  ContainerInputData,
} from "@/forms/validation";

const GET_CONTAINERS_QUERY = graphql`
  query ReuseContainerModal_getContainers_Query {
    containers {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

const GET_CONTAINER_DETAILS_QUERY = graphql`
  query ReuseContainerModal_getContainerDetails_Query($id: ID!) {
    container(id: $id) {
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
          }
        }
      }
      containerVolumes {
        edges {
          node {
            target
            volume {
              id
            }
          }
        }
      }
      deviceMappings {
        edges {
          node {
            pathInContainer
            pathOnHost
            cgroupPermissions
          }
        }
      }
    }
  }
`;

type ContainersData = ReuseContainerModal_getContainers_Query["response"];

type ContainerEdge = NonNullable<
  NonNullable<ContainersData["containers"]>["edges"]
>[number];

type Container = NonNullable<ContainerEdge>["node"];

type ReuseContainerModalProps = {
  open: boolean;
  setInitialData: (container: Partial<ContainerInputData>) => void;
  onToggleModal: (show: boolean) => void;
};

const ReuseContainerModal = ({
  open,
  setInitialData,
  onToggleModal,
}: ReuseContainerModalProps) => {
  const intl = useIntl();

  const environment = useRelayEnvironment();

  const [isLoadingContainer, setIsLoadingContainer] = useState(false);
  const [selectedContainer, setSelectedContainer] = useState<Container | null>(
    null,
  );

  const data = useLazyLoadQuery<ReuseContainerModal_getContainers_Query>(
    GET_CONTAINERS_QUERY,
    {},
    {
      fetchPolicy: "store-and-network",
    },
  );

  const containers: Container[] =
    data.containers?.edges
      ?.map((edge) => edge?.node)
      .filter((node): node is Container => node != null) ?? [];

  return (
    <ConfirmModal
      title={intl.formatMessage({
        id: "components.ReuseContainerModal.reuseResourcesTitle",
        defaultMessage: "Reuse Resources",
      })}
      confirmLabel={
        <FormattedMessage
          id="components.ReuseContainerModal.confirmButton"
          defaultMessage="Confirm"
        />
      }
      show={open}
      onCancel={() => onToggleModal(false)}
      onConfirm={() => {
        if (!selectedContainer) {
          return;
        }

        setIsLoadingContainer(true);

        fetchQuery<ReuseContainerModal_getContainerDetails_Query>(
          environment,
          GET_CONTAINER_DETAILS_QUERY,
          {
            id: selectedContainer.id,
          },
        )
          .toPromise()
          .then((data) => {
            const c = data?.container;

            if (!c) {
              return;
            }

            const initialData: Partial<ContainerInputData> = {
              image: c.image
                ? {
                    reference: c.image.reference,
                    imageCredentialsId: c.image.credentials?.id,
                  }
                : undefined,
              hostname: c.hostname ?? undefined,
              networkMode: c.networkMode ?? undefined,
              networks: c.networks?.edges
                ? c.networks.edges.reduce<{ id: string }[]>(
                    (networks, edge) => {
                      const node = edge?.node;

                      if (node) {
                        networks.push({
                          id: node.id,
                        });
                      }

                      return networks;
                    },
                    [],
                  )
                : undefined,
              extraHosts: c.extraHosts ? [...c.extraHosts] : undefined,
              portBindings: c.portBindings ? [...c.portBindings] : undefined,
              binds: c.binds ? [...c.binds] : undefined,
              volumes: c.containerVolumes?.edges
                ? c.containerVolumes.edges.reduce<
                    { id: string; target: string }[]
                  >((volumes, edge) => {
                    const node = edge?.node;

                    if (node) {
                      volumes.push({
                        id: node.volume.id,
                        target: node.target,
                      });
                    }

                    return volumes;
                  }, [])
                : undefined,
              volumeDriver: c.volumeDriver ?? undefined,
              storageOpt: c.storageOpt ? [...c.storageOpt] : undefined,
              tmpfs: c.tmpfs ? [...c.tmpfs] : undefined,
              readOnlyRootfs: c.readOnlyRootfs ?? undefined,
              memory: c.memory ?? undefined,
              memoryReservation: c.memoryReservation ?? undefined,
              memorySwap: c.memorySwap ?? undefined,
              memorySwappiness: c.memorySwappiness ?? undefined,
              cpuPeriod: c.cpuPeriod ?? undefined,
              cpuQuota: c.cpuQuota ?? undefined,
              cpuRealtimePeriod: c.cpuRealtimePeriod ?? undefined,
              cpuRealtimeRuntime: c.cpuRealtimeRuntime ?? undefined,
              privileged: c.privileged ?? undefined,
              capAdd: c.capAdd
                ? (c.capAdd as (typeof CapAddList)[number][])
                : undefined,
              capDrop: c.capDrop
                ? (c.capDrop as (typeof CapDropList)[number][])
                : undefined,
              restartPolicy: c.restartPolicy ?? undefined,
              env: Array.isArray(c.env)
                ? c.env.map((item) => ({
                    key: item?.key ?? "",
                    value: item?.value ?? "",
                  }))
                : undefined,
              deviceMappings: c.deviceMappings?.edges
                ? c.deviceMappings.edges.reduce<
                    {
                      pathInContainer: string;
                      pathOnHost: string;
                      cgroupPermissions: string;
                    }[]
                  >((deviceMappings, edge) => {
                    const node = edge?.node;

                    if (node) {
                      deviceMappings.push({
                        pathInContainer: node.pathInContainer,
                        pathOnHost: node.pathOnHost,
                        cgroupPermissions: node.cgroupPermissions,
                      });
                    }

                    return deviceMappings;
                  }, [])
                : undefined,
            };

            setInitialData(initialData);
            onToggleModal(false);
          })
          .finally(() => {
            setIsLoadingContainer(false);
          });
      }}
    >
      <p>
        <FormattedMessage
          id="components.ReuseContainerModal.confirmPrompt"
          defaultMessage="Choose a container from which you want to copy configuration."
        />
      </p>

      <div className="mb-2 d-flex flex-column gap-2">
        <FormRow
          id="containers-reuseResources-container"
          label={intl.formatMessage({
            id: "components.ReuseContainerModal.selectContainer",
            defaultMessage: "Select Container",
          })}
        >
          <Select<Container>
            value={selectedContainer}
            onChange={(val) => setSelectedContainer(val)}
            classNamePrefix="select"
            isSearchable
            getOptionLabel={(option) => option.name}
            getOptionValue={(option) => option.id}
            options={containers}
            isLoading={isLoadingContainer}
          />
        </FormRow>
      </div>
    </ConfirmModal>
  );
};

export default ReuseContainerModal;
