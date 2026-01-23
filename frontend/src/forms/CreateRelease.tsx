/*
 * This file is part of Edgehog.
 *
 * Copyright 2024 - 2025 SECO Mind Srl
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

import { useState, useRef } from "react";
import { useForm, useFieldArray, Controller, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment, useLazyLoadQuery } from "react-relay/hooks";
import { zodResolver } from "@hookform/resolvers/zod";

import type { CreateRelease_ImageCredentialsOptionsFragment$key } from "@/api/__generated__/CreateRelease_ImageCredentialsOptionsFragment.graphql";
import type { CreateRelease_NetworksOptionsFragment$key } from "@/api/__generated__/CreateRelease_NetworksOptionsFragment.graphql";
import type { CreateRelease_VolumesOptionsFragment$key } from "@/api/__generated__/CreateRelease_VolumesOptionsFragment.graphql";
import type { CreateRelease_SystemModelsOptionsFragment$key } from "@/api/__generated__/CreateRelease_SystemModelsOptionsFragment.graphql";
import {
  ContainerCreateWithNestedDeviceMappingsInput,
  ContainerCreateWithNestedImageInput,
  ContainerCreateWithNestedNetworksInput,
  ContainerCreateWithNestedVolumesInput,
  ReleaseCreateRequiredSystemModelsInput,
} from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import type {
  CreateRelease_getApplicationsWithReleases_Query,
  CreateRelease_getApplicationsWithReleases_Query$data,
} from "@/api/__generated__/CreateRelease_getApplicationsWithReleases_Query.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import Alert from "@/components/Alert";
import MultiSelect from "@/components/MultiSelect";
import Select, { SingleValue } from "react-select";
import ConfirmModal from "@/components/ConfirmModal";
import { FormRow } from "@/components/FormRow";
import ContainerForm from "@/forms/ContainerForm";
import Tag from "@/components/Tag";
import type { KeyValue } from "@/forms/validation";
import CollapseItem, {
  useCollapsibleSections,
} from "@/components/CollapseItem";
import {
  CapAddList,
  CapDropList,
  ContainerInputData,
  ReleaseFormData,
  releaseSchema,
} from "@/forms/validation";

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
                systemModels {
                  id
                  name
                }
                containers {
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
                      restartPolicy
                      privileged
                      portBindings
                      binds
                      cpuPeriod
                      cpuQuota
                      cpuRealtimePeriod
                      cpuRealtimeRuntime
                      memory
                      memorySwap
                      memorySwappiness
                      capAdd
                      capDrop
                      storageOpt
                      tmpfs
                      memoryReservation
                      readOnlyRootfs
                      volumeDriver
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

type ReleaseContainerNode = NonNullable<
  ReleaseNode["containers"]["edges"]
>[number]["node"];
export type EnvironmentVariable = NonNullable<
  ReleaseContainerNode["env"]
>[number] &
  KeyValue<string>;

type ContainerOutput = {
  // Image Configuration
  image: ContainerCreateWithNestedImageInput;
  // Network Configuration
  hostname?: string;
  networkMode?: string;
  networks?: ContainerCreateWithNestedNetworksInput[];
  extraHosts?: string[];
  portBindings?: string[];
  // Storage Configuration
  binds?: string[];
  volumes?: ContainerCreateWithNestedVolumesInput[];
  volumeDriver?: string;
  storageOpt?: string[];
  tmpfs?: string[];
  readOnlyRootfs?: boolean;
  // Resource Limits
  memory?: number;
  memoryReservation?: number;
  memorySwap?: number;
  memorySwappiness?: number;
  cpuPeriod?: number;
  cpuQuota?: number;
  cpuRealtimePeriod?: number;
  cpuRealtimeRuntime?: number;
  // Security & Capabilities
  privileged?: boolean;
  capAdd?: string[];
  capDrop?: string[];
  // Runtime & Environment
  restartPolicy?: string;
  env?: EnvironmentVariable[];
  // Device Mappings
  deviceMappings?: ContainerCreateWithNestedDeviceMappingsInput[];
};

type ReleaseSubmitData = {
  version: string;
  containers?: ContainerOutput[];
  requiredSystemModels?: ReleaseCreateRequiredSystemModelsInput[];
};

const initialData: ReleaseFormData = {
  version: "",
};

export const restartPolicyOptions = [
  { value: "no", label: "No" },
  { value: "always", label: "Always" },
  { value: "on_failure", label: "On Failure" },
  { value: "unless_stopped", label: "Unless Stopped" },
];

type Option = {
  value: string;
  label: string;
};

type CreateReleaseProps = {
  imageCredentialsOptionsRef: CreateRelease_ImageCredentialsOptionsFragment$key;
  networksOptionsRef: CreateRelease_NetworksOptionsFragment$key;
  volumesOptionsRef: CreateRelease_VolumesOptionsFragment$key;
  requiredSystemModelsOptionsRef: CreateRelease_SystemModelsOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ReleaseSubmitData) => void;
  showModal?: boolean;
  onToggleModal?: (show: boolean) => void;
};

const CreateRelease = ({
  imageCredentialsOptionsRef,
  networksOptionsRef,
  volumesOptionsRef,
  requiredSystemModelsOptionsRef,
  isLoading = false,
  onSubmit,
  showModal = false,
  onToggleModal,
}: CreateReleaseProps) => {
  const intl = useIntl();

  const { listImageCredentials } = useFragment(
    IMAGE_CREDENTIALS_OPTIONS_FRAGMENT,
    imageCredentialsOptionsRef,
  );

  const imageCredentialsOptions: Option[] =
    listImageCredentials?.edges?.map(({ node: imageCredentials }) => ({
      value: imageCredentials.id,
      label: `${imageCredentials.label} (${imageCredentials.username})`,
    })) ?? [];

  const { networks } = useFragment(
    NETWORKS_OPTIONS_FRAGMENT,
    networksOptionsRef,
  );

  const networkOptions: Option[] =
    networks?.edges?.map(({ node: network }) => ({
      value: network.id,
      label: network.label ?? "",
    })) ?? [];

  const { volumes } = useFragment(VOLUMES_OPTIONS_FRAGMENT, volumesOptionsRef);

  const volumeOptions: Option[] =
    volumes?.edges?.map(({ node: volume }) => ({
      value: volume.id,
      label: volume.label ?? "",
    })) ?? [];

  const { systemModels: requiredSystemModels } = useFragment(
    SYSTEM_MODELS_OPTIONS_FRAGMENT,
    requiredSystemModelsOptionsRef,
  );

  const systemModelsOptions: Option[] =
    requiredSystemModels?.edges?.map(({ node: systemModel }) => ({
      value: systemModel.id,
      label: systemModel.name,
    })) ?? [];

  const {
    register,
    handleSubmit,
    control,
    reset,
    setFocus,
    formState: { errors },
  } = useForm<ReleaseFormData>({
    mode: "all",
    defaultValues: initialData,
    resolver: zodResolver(releaseSchema),
  });

  const { fields: containersFields, append } = useFieldArray({
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

  const [
    selectedContainersTemplateRelease,
    setSelectedContainersTemplateRelease,
  ] = useState<SingleValue<{ value: string; label: string }>>(null);

  const [selectedContainersTemplateApp, setSelectedContainersTemplateApp] =
    useState<
      SingleValue<{ value: string; label: string; releases: ReleaseNode[] }>
    >(null);

  const [showImportSuccess, setShowImportSuccess] = useState(false);
  const [justImported, setJustImported] = useState(false);
  const isImportingRef = useRef(false);
  const importedContainersSnapshotRef = useRef<ContainerInputData[]>([]);

  // Watch all form values to detect changes
  const formValues = useWatch({ control });

  // Helper function to check if a specific container is imported
  const isContainerImported = (containerIndex: number): boolean => {
    return containerIndex < importedContainersSnapshotRef.current.length;
  };

  // Helper function to check if a specific container is modified
  const isContainerModified = (containerIndex: number): boolean => {
    // If we just imported or are currently importing, don't show modified tags yet
    if (justImported || isImportingRef.current) {
      return false;
    }

    if (!isContainerImported(containerIndex)) {
      return false;
    }

    const importedContainer =
      importedContainersSnapshotRef.current[containerIndex];
    const currentContainer = formValues?.containers?.[containerIndex];

    if (!importedContainer || !currentContainer) {
      return false;
    }

    // Simple JSON comparison - check if this specific container has changed
    return (
      JSON.stringify(importedContainer) !== JSON.stringify(currentContainer)
    );
  };

  // Wrapper for remove that also updates imported containers tracking
  const handleRemoveContainer = (index: number) => {
    // Get current containers
    const currentContainers = formValues.containers || [];

    // Create new array without the removed container
    const newContainers = currentContainers.filter((_, i) => i !== index);

    // Update imported containers data if needed
    if (index < importedContainersSnapshotRef.current.length) {
      const newSnapshot = [...importedContainersSnapshotRef.current];
      newSnapshot.splice(index, 1);
      importedContainersSnapshotRef.current = newSnapshot;
    }

    // Update open container forms
    setOpenIndexes((current) =>
      current
        .sort()
        .filter((v) => v !== index)
        .map((value) => (value > index ? value - 1 : value)),
    );

    // Reset the containers field with the new array to clear any cached state
    reset(
      {
        version: formValues.version || "",
        requiredSystemModels: formValues.requiredSystemModels || [],
        containers: newContainers,
      },
      {
        keepErrors: false,
        keepDirty: true,
        keepTouched: false,
      },
    );
  };

  const [removeIndex, setRemoveIndex] = useState<number | null>(null);

  const handleRequestRemove = (index: number) => {
    setRemoveIndex(index);
  };

  const {
    toggleSection: toggleIndex,
    isSectionOpen,
    setOpenSections: setOpenIndexes,
  } = useCollapsibleSections<number>(containersFields.map((_, index) => index));

  const transformOutputData = (data: ReleaseFormData): ReleaseSubmitData => ({
    ...data,
    containers: data.containers?.map((container) => ({
      ...container,
      env: Array.isArray(container.env)
        ? container.env.map((pair) => ({ key: pair.key, value: pair.value }))
        : undefined,
      volumes: container.volumes?.length ? container.volumes : undefined,
      deviceMappings: container.deviceMappings?.length
        ? container.deviceMappings
        : undefined,
      image: {
        reference: container.image?.reference,
        imageCredentialsId: container.image?.imageCredentialsId,
      },
    })),
  });

  const onFormSubmit = (data: ReleaseFormData) =>
    onSubmit(transformOutputData(data));

  return (
    <>
      <form onSubmit={handleSubmit(onFormSubmit)}>
        <Stack gap={2}>
          {showImportSuccess && (
            <Alert
              variant="success"
              dismissible
              onClose={() => setShowImportSuccess(false)}
            >
              <FormattedMessage
                id="forms.CreateRelease.importSuccessMessage"
                defaultMessage="Release configuration has been successfully imported!"
              />
            </Alert>
          )}

          <FormRow
            id="application-form-version"
            label={
              <FormattedMessage
                id="forms.CreateRelease.versionLabel"
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
                id="forms.CreateRelease.supportedSystemModelsLabels"
                defaultMessage="Supported System Models"
              />
            }
          >
            <Controller
              control={control}
              name="requiredSystemModels"
              render={({ field: { value, onChange, onBlur } }) => {
                const mappedValue = (value || []).map((v) => {
                  const option = systemModelsOptions.find(
                    (sm) => sm.value === v.id,
                  );
                  return {
                    value: v.id ?? "",
                    label: option?.label ?? v.id ?? "",
                  };
                });

                return (
                  <MultiSelect
                    value={mappedValue}
                    onChange={(selected) => {
                      onChange(selected.map(({ value }) => ({ id: value })));
                    }}
                    onBlur={onBlur}
                    options={systemModelsOptions}
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
                id="forms.CreateRelease.containersTitle"
                defaultMessage="Containers"
              />
            </h5>
            {containersFields.length === 0 && (
              <p>
                <FormattedMessage
                  id="forms.CreateRelease.noContainersFeedback"
                  defaultMessage="The release does not include any container."
                />
              </p>
            )}
          </Stack>
          {containersFields.map((field, index) => {
            return (
              <CollapseItem
                key={field.id ?? index}
                type="card-parent"
                open={isSectionOpen(index)}
                onToggle={() => toggleIndex(index)}
                title={
                  <span className="d-flex align-items-center gap-2">
                    <FormattedMessage
                      id="forms.ContainerForm.containerTitle"
                      defaultMessage="Container {containerNumber}"
                      values={{
                        containerNumber: index + 1,
                      }}
                    />
                    {isContainerImported(index) && (
                      <Tag className="bg-secondary">
                        <FormattedMessage
                          id="forms.ContainerForm.importedLabel"
                          defaultMessage="Imported"
                        />
                      </Tag>
                    )}
                    {isContainerModified(index) && (
                      <Tag className="bg-secondary">
                        <FormattedMessage
                          id="forms.ContainerForm.modifiedLabel"
                          defaultMessage="Modified"
                        />
                      </Tag>
                    )}
                  </span>
                }
              >
                <div className="p-3">
                  <ContainerForm
                    key={field.id}
                    index={index}
                    register={register}
                    errors={errors}
                    remove={handleRemoveContainer}
                    imageCredentials={imageCredentialsOptions}
                    networks={networkOptions}
                    volumes={volumeOptions}
                    control={control}
                    onRequestRemove={handleRequestRemove}
                  />
                </div>
              </CollapseItem>
            );
          })}

          <div className="d-flex justify-content-start align-items-center gap-2">
            <Button
              variant="secondary"
              onClick={() => {
                append({ image: { reference: "" } });
                const newIndex = containersFields.length;
                setTimeout(() => {
                  toggleIndex(containersFields.length);
                }, 0);
                // Separate timeout waits for the end of the collapse transition
                setTimeout(() => {
                  setFocus(`containers.${newIndex}.image.reference`);
                }, 100);
              }}
            >
              <FormattedMessage
                id="forms.CreateRelease.addContainerButton"
                defaultMessage="Add Container"
              />
            </Button>
            {removeIndex !== null && (
              <ConfirmModal
                confirmLabel={
                  <FormattedMessage
                    id="forms.CreateRelease.confirmRemoveLabel"
                    defaultMessage="Remove"
                  />
                }
                onCancel={() => setRemoveIndex(null)}
                onConfirm={() => {
                  handleRemoveContainer(removeIndex);
                  setRemoveIndex(null);
                }}
                title={
                  <FormattedMessage
                    id="forms.CreateRelease.confirmRemoveTitle"
                    defaultMessage="Remove Container"
                  />
                }
                confirmVariant="danger"
              >
                <p>
                  <FormattedMessage
                    id="forms.CreateRelease.confirmRemoveDescription"
                    defaultMessage="Are you sure you want to remove <bold>Container {number}</bold>?"
                    values={{
                      number: removeIndex + 1,
                      bold: (chunks: React.ReactNode) => (
                        <strong>{chunks}</strong>
                      ),
                    }}
                  />
                </p>
              </ConfirmModal>
            )}
          </div>

          <div className="d-flex justify-content-end align-items-center">
            <Button variant="primary" type="submit" disabled={isLoading}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="forms.CreateRelease.submitButton"
                defaultMessage="Create"
              />
            </Button>
          </div>
        </Stack>
      </form>

      {showModal && (
        <ConfirmModal
          title={intl.formatMessage({
            id: "forms.CreateRelease.reuseResourcesTitle",
            defaultMessage: "Reuse Resources",
          })}
          confirmLabel={
            <FormattedMessage
              id="forms.CreateRelease.confirmButton"
              defaultMessage="Confirm"
            />
          }
          onCancel={() => onToggleModal?.(false)}
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

            const mappedContainers =
              release.containers?.edges?.map((containerEdge) => {
                const c = containerEdge.node;

                return {
                  // Image Configuration
                  image: c.image
                    ? {
                        reference: c.image.reference,
                        imageCredentialsId: c.image?.credentials?.id,
                      }
                    : undefined,
                  // Network Configuration
                  hostname: c.hostname ?? undefined,
                  networkMode: c.networkMode ?? undefined,

                  networks:
                    c.networks?.edges?.map((n: any) => ({ id: n.node.id })) ??
                    undefined,

                  extraHosts: c.extraHosts ? [...c.extraHosts] : undefined,
                  portBindings: c.portBindings
                    ? [...c.portBindings]
                    : undefined,
                  binds: c.binds ? [...c.binds] : undefined,

                  volumes:
                    c.containerVolumes?.edges?.map((v: any) => ({
                      id: v.node.volume.id,
                      target: v.node.target,
                    })) ?? undefined,

                  volumeDriver: c.volumeDriver ?? undefined,
                  storageOpt: c.storageOpt ? [...c.storageOpt] : undefined,
                  tmpfs: c.tmpfs ? [...c.tmpfs] : undefined,

                  readOnlyRootfs: c.readOnlyRootfs ?? undefined,
                  // Resource Limits
                  memory: c.memory ?? undefined,
                  memoryReservation: c.memoryReservation ?? undefined,
                  memorySwap: c.memorySwap ?? undefined,
                  memorySwappiness: c.memorySwappiness ?? undefined,

                  cpuPeriod: c.cpuPeriod ?? undefined,
                  cpuQuota: c.cpuQuota ?? undefined,
                  cpuRealtimePeriod: c.cpuRealtimePeriod ?? undefined,
                  cpuRealtimeRuntime: c.cpuRealtimeRuntime ?? undefined,
                  // Security & Capabilities
                  privileged: c.privileged ?? undefined,
                  capAdd: c.capAdd
                    ? (c.capAdd as (typeof CapAddList)[number][])
                    : undefined,

                  capDrop: c.capDrop
                    ? (c.capDrop as (typeof CapDropList)[number][])
                    : undefined,
                  // Runtime & Environment
                  restartPolicy: c.restartPolicy ?? undefined,

                  env: Array.isArray(c.env) ? c.env : undefined,
                  // Device Mappings
                  deviceMappings:
                    c.deviceMappings?.edges?.map((dm: any) => ({
                      pathInContainer: dm.node.pathInContainer,
                      pathOnHost: dm.node.pathOnHost,
                      cgroupPermissions: dm.node.cgroupPermissions,
                    })) ?? undefined,
                };
              }) ?? [];

            const newFormData: ReleaseFormData = {
              version: formValues.version ?? "",
              requiredSystemModels: release.systemModels?.map(({ id }) => ({
                id,
              })),
              containers: mappedContainers,
            };

            // Reset the form and wait for it to complete
            reset(newFormData, {
              keepErrors: false,
              keepDirty: false,
              keepIsSubmitted: false,
              keepTouched: false,
              keepIsValid: false,
              keepSubmitCount: false,
            });

            // Set importing flags to prevent premature modification detection
            isImportingRef.current = true;
            setJustImported(true);
            setShowImportSuccess(true);

            // Store the imported containers snapshot
            importedContainersSnapshotRef.current = mappedContainers;

            // Use requestAnimationFrame to wait for the reset to complete
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                // After form has settled, take a snapshot of the actual form values
                // This ensures we compare against what the form actually contains
                const settledContainers = control._formValues.containers || [];
                importedContainersSnapshotRef.current = JSON.parse(
                  JSON.stringify(settledContainers),
                );

                // Clear flags after form reset is complete
                isImportingRef.current = false;
                setJustImported(false);

                // Set all containers to be opened once the import is completed
                setOpenIndexes(
                  importedContainersSnapshotRef.current.map((_v, i) => i),
                );
              });
            });

            // Auto-hide success message after 5 seconds
            setTimeout(() => setShowImportSuccess(false), 5000);

            onToggleModal?.(false);
          }}
        >
          <p>
            <FormattedMessage
              id="forms.CreateRelease.confirmPrompt"
              defaultMessage="Choose a release from which you want to copy containers and their configurations."
            />
          </p>
          <div className="mt-3 mb-2 p-3 border rounded">
            <div className="mb-2 d-flex flex-column gap-2">
              <FormRow
                id="containers-reuseResources-application"
                label={intl.formatMessage({
                  id: "forms.CreateRelease.selectApplication",
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
                  id: "forms.CreateRelease.selectRelease",
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
