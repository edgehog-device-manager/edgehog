/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import React, { useCallback, useMemo, useRef, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery, useMutation } from "react-relay/hooks";
import { SingleValue } from "react-select";

import type { InstallApplicationModal_GetApplicationsWithReleases_Query } from "@/api/__generated__/InstallApplicationModal_GetApplicationsWithReleases_Query.graphql";
import type {
  ContainerEnvVarInput,
  DeploymentConfigSpecInput,
  EnvFileSpecInput,
  FileBindSpecInput,
  InstallApplicationModal_DeployRelease_Mutation,
} from "@/api/__generated__/InstallApplicationModal_DeployRelease_Mutation.graphql";
import type { InstallApplicationModal_markFileBindAsUploaded_Mutation } from "@/api/__generated__/InstallApplicationModal_markFileBindAsUploaded_Mutation.graphql";
import type { InstallApplicationModal_markEnvFileAsUploaded_Mutation } from "@/api/__generated__/InstallApplicationModal_markEnvFileAsUploaded_Mutation.graphql";
import { useNavigate, Route } from "@/Navigation";
import { ToggleButton, ToggleButtonGroup } from "react-bootstrap";
import Select from "@/components/ui/select/Select";
import { FormRow } from "@/components/ui/form-row/FormRow";
import ConfirmModal from "@/components/ui/confirm-modal/ConfirmModal";
import Alert from "@/components/ui/alert/Alert";
import CollapseItem from "@/components/ui/collapse-item/CollapseItem";
import EnvFileInput, {
  EnvFileInputRef,
  EnvFilePendingUpload,
} from "@/components/apps/containers/env-file-input/EnvFileInput";
import FileMountInput, {
  FileBindResult,
  FileMountInputRef,
  PendingUploadData,
} from "@/components/apps/containers/file-mount-input/FileMountInput";
import MonacoJsonEditor from "@/components/ui/monaco-json-editor/MonacoJsonEditor";

const GET_APPLICATIONS_WITH_RELEASES_QUERY = graphql`
  query InstallApplicationModal_GetApplicationsWithReleases_Query(
    $deviceId: ID!
    $filter: ApplicationFilterInput = {}
  ) {
    device(id: $deviceId) {
      id
      deviceFiles(first: 1000) {
        edges {
          node {
            id
            pathOnDevice
            deleted
            fileDownloadRequest {
              id
            }
          }
        }
      }
      fileDownloadRequests(first: 1000) {
        edges {
          node {
            id
            fileName
            destination
            status
            deviceFile {
              id
              deleted
            }
          }
        }
      }
    }
    applications(first: 10000, filter: $filter) {
      edges {
        node {
          id
          name
          releases(first: 10000) {
            edges {
              node {
                id
                version
                systemModels {
                  name
                }
                containers(first: 250) {
                  edges {
                    node {
                      id
                      name
                      fileMounts(first: 250) {
                        edges {
                          node {
                            id
                            mountpoint
                            required
                            defaultFileId
                            defaultFile {
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
            }
          }
        }
      }
    }
  }
`;

const DEPLOY_RELEASE_MUTATION = graphql`
  mutation InstallApplicationModal_DeployRelease_Mutation(
    $input: DeployReleaseInput!
  ) {
    deployRelease(input: $input) {
      result {
        id
        state
        containerDeployments(first: 250) {
          edges {
            node {
              id
              container {
                id
              }
              fileBinds {
                id
                fileMountId
                fileMount {
                  id
                }
                uploaded
                uploadUrl
              }
              envFiles {
                id
                uploaded
                uploadUrl
              }
            }
          }
        }
      }
      errors {
        message
      }
    }
  }
`;

const MARK_FILE_BIND_AS_UPLOADED_MUTATION = graphql`
  mutation InstallApplicationModal_markFileBindAsUploaded_Mutation(
    $id: ID!
    $input: MarkFileBindAsUploadedInput!
  ) {
    markFileBindAsUploaded(id: $id, input: $input) {
      result {
        id
        uploaded
        state
      }
      errors {
        message
      }
    }
  }
`;

const MARK_ENV_FILE_AS_UPLOADED_MUTATION = graphql`
  mutation InstallApplicationModal_markEnvFileAsUploaded_Mutation(
    $id: ID!
    $input: MarkEnvFileAsUploadedInput!
  ) {
    markEnvFileAsUploaded(id: $id, input: $input) {
      result {
        id
        uploaded
        state
      }
      errors {
        message
      }
    }
  }
`;

type InstallApplicationModalProps = {
  open: boolean;
  onToggleModal: (show: boolean) => void;
  deviceId: string;
  systemModelName: string | undefined;
  isOnline: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

type SelectOption = {
  value: string;
  label: string;
  disabled: boolean;
};

type EnvMode = "none" | "override" | "file";

const InstallApplicationModal = ({
  open,
  onToggleModal,
  deviceId,
  systemModelName,
  isOnline,
  setErrorFeedback,
}: InstallApplicationModalProps) => {
  const intl = useIntl();
  const navigate = useNavigate();

  const [selectedApp, setSelectedApp] = useState<string | null>(null);
  const [selectedRelease, setSelectedRelease] = useState<string | null>(null);
  // Per-container environment configuration. Missing entries mean "none".
  const [envModes, setEnvModes] = useState<Record<string, EnvMode>>({});
  const [envStrategies, setEnvStrategies] = useState<Record<string, string>>(
    {},
  );
  const [envJsons, setEnvJsons] = useState<Record<string, string>>({});
  const [mountValidity, setMountValidity] = useState<Record<string, boolean>>(
    {},
  );
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const mountInputRefs = useRef<Record<string, FileMountInputRef | null>>({});
  const envFileInputRefs = useRef<Record<string, EnvFileInputRef | null>>({});
  // Both configuration sections start collapsed; selection changes collapse
  // them again.
  const [envSectionOpen, setEnvSectionOpen] = useState<boolean>(false);
  const [mountsSectionOpen, setMountsSectionOpen] = useState<boolean>(false);

  const data =
    useLazyLoadQuery<InstallApplicationModal_GetApplicationsWithReleases_Query>(
      GET_APPLICATIONS_WITH_RELEASES_QUERY,
      {
        deviceId,
        filter: {
          releases: {
            or: [
              {
                systemModels: {
                  name: { eq: systemModelName },
                },
              },
              {
                systemModels: {
                  name: { isNil: true },
                },
              },
            ],
          },
        },
      },
      { fetchPolicy: "store-and-network" },
    );

  const applicationEdges = useMemo(
    () => data.applications?.edges ?? [],
    [data.applications?.edges],
  );

  const applicationOptions: SelectOption[] = useMemo(() => {
    return applicationEdges.map((app) => ({
      value: app.node.id,
      label: app.node.name,
      disabled: false,
    }));
  }, [applicationEdges]);

  const selectedApplicationOption = useMemo(() => {
    return (
      applicationOptions.find((option) => option.value === selectedApp) || null
    );
  }, [applicationOptions, selectedApp]);

  const releaseOptions: SelectOption[] = useMemo(() => {
    if (!selectedApp || !applicationEdges) return [];

    const selectedApplication = applicationEdges.find(
      (app) => app.node.id === selectedApp,
    );

    if (!selectedApplication?.node.releases.edges) return [];

    return selectedApplication.node.releases.edges.map(({ node: release }) => {
      const systemModelNames = release.systemModels?.map((sm) => sm.name) ?? [];

      const hasSystemModel = !!systemModelName;
      const matchesSystemModel =
        hasSystemModel && systemModelNames.includes(systemModelName);
      const appliesToAll = systemModelNames.length === 0;

      const enabled = matchesSystemModel || appliesToAll;

      return {
        value: release.id,
        label: release.version,
        disabled: !enabled,
      };
    });
  }, [selectedApp, applicationEdges, systemModelName]);

  const selectedReleaseOption = useMemo(() => {
    return (
      releaseOptions.find((option) => option.value === selectedRelease) || null
    );
  }, [releaseOptions, selectedRelease]);

  const selectedReleaseNode = useMemo(() => {
    if (!selectedApp || !selectedRelease) return null;
    const selectedApplication = applicationEdges.find(
      (app) => app.node.id === selectedApp,
    );
    return (
      selectedApplication?.node.releases.edges?.find(
        ({ node: r }) => r.id === selectedRelease,
      )?.node ?? null
    );
  }, [selectedApp, selectedRelease, applicationEdges]);

  const envStrategyOptions: SelectOption[] = useMemo(
    () => [
      {
        value: "merge",
        label: intl.formatMessage({
          id: "components.apps.releases.install-application-modal.InstallApplicationModal.envStrategyMerge",
          defaultMessage: "Merge",
        }),
        disabled: false,
      },
      {
        value: "override",
        label: intl.formatMessage({
          id: "components.apps.releases.install-application-modal.InstallApplicationModal.envStrategyOverride",
          defaultMessage: "Override",
        }),
        disabled: false,
      },
    ],
    [intl],
  );

  const selectedEnvStrategyOption = useCallback(
    (containerId: string) => {
      const strategy = envStrategies[containerId] || "merge";
      return (
        envStrategyOptions.find((opt) => opt.value === strategy) ||
        envStrategyOptions[0]
      );
    },
    [envStrategyOptions, envStrategies],
  );

  const parseEnvJson = useCallback(
    (envJson: string): ContainerEnvVarInput[] | undefined => {
      if (!envJson || !envJson.trim()) return undefined;
      try {
        const parsed = JSON.parse(envJson);
        if (
          typeof parsed === "object" &&
          parsed !== null &&
          !Array.isArray(parsed)
        ) {
          const entries = Object.entries(parsed);
          if (entries.length === 0) return undefined;
          return entries.map(([key, value]) => ({
            key,
            value: typeof value === "string" ? value : JSON.stringify(value),
          }));
        }
      } catch {
        return undefined;
      }
      return undefined;
    },
    [],
  );

  const isEnvJsonValid = useCallback((envJson: string) => {
    if (!envJson || !envJson.trim()) return true;
    try {
      const parsed = JSON.parse(envJson);
      return (
        typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
      );
    } catch {
      return false;
    }
  }, []);

  const releaseContainers = useMemo(() => {
    if (!selectedReleaseNode?.containers?.edges) return [];
    return selectedReleaseNode.containers.edges.map(({ node: container }) => ({
      id: container.id,
      name: container.name,
      mounts:
        container.fileMounts?.edges
          ?.map((edge) => edge?.node)
          .filter((node): node is NonNullable<typeof node> => !!node) ?? [],
    }));
  }, [selectedReleaseNode]);

  const containersWithMounts = useMemo(() => {
    return releaseContainers.filter((c) => c.mounts.length > 0);
  }, [releaseContainers]);

  // Deploy is blocked when any override-mode container holds invalid JSON.
  const allEnvJsonValid = useMemo(() => {
    return releaseContainers.every(
      (container) =>
        envModes[container.id] !== "override" ||
        isEnvJsonValid(envJsons[container.id] || "{}"),
    );
  }, [releaseContainers, envModes, envJsons, isEnvJsonValid]);

  const deviceFiles = useMemo(() => {
    return (
      data.device?.deviceFiles?.edges
        ?.map((edge) => edge?.node)
        .filter(
          (node): node is NonNullable<typeof node> =>
            !!node && node.deleted !== true,
        )
        .map((df) => ({
          id: df.id,
          pathOnDevice: df.pathOnDevice,
          deleted: df.deleted,
          fileDownloadRequestId: df.fileDownloadRequest?.id,
        })) ?? []
    );
  }, [data.device?.deviceFiles?.edges]);

  const fileDownloadRequests = useMemo(() => {
    return (
      data.device?.fileDownloadRequests?.edges
        ?.map((edge) => edge?.node)
        .filter(
          (node): node is NonNullable<typeof node> =>
            !!node &&
            node.status !== "FAILED" &&
            node.deviceFile?.deleted !== true,
        )
        .map((fdr) => ({
          id: fdr.id,
          fileName: fdr.fileName,
          destination: fdr.destination,
          status: fdr.status,
          deviceFileId: fdr.deviceFile?.id,
          deviceFileDeleted: fdr.deviceFile?.deleted,
        })) ?? []
    );
  }, [data.device?.fileDownloadRequests?.edges]);

  const allRequiredMountsConfigured = useMemo(() => {
    for (const container of containersWithMounts) {
      for (const mount of container.mounts) {
        if (mount.required) {
          const hasDefault = !!mount.defaultFileId || !!mount.defaultFile?.name;
          if (hasDefault) {
            continue;
          }
          if (!mountValidity[mount.id]) {
            return false;
          }
        }
      }
    }
    return true;
  }, [containersWithMounts, mountValidity]);

  const hasRequiredMounts = useMemo(() => {
    return containersWithMounts.some((c) => c.mounts.some((m) => m.required));
  }, [containersWithMounts]);

  const hasNoFilesOnDevice = useMemo(() => {
    return deviceFiles.length === 0 && fileDownloadRequests.length === 0;
  }, [deviceFiles.length, fileDownloadRequests.length]);

  const handleFileBindChange = useCallback(
    (mountId: string, _result: FileBindResult | null, isValid?: boolean) => {
      if (isValid !== undefined) {
        setMountValidity((prev) => {
          if (prev[mountId] === isValid) return prev;
          return { ...prev, [mountId]: isValid };
        });
      }
    },
    [],
  );

  const [deployRelease, isDeploying] =
    useMutation<InstallApplicationModal_DeployRelease_Mutation>(
      DEPLOY_RELEASE_MUTATION,
    );

  const [markFileBindAsUploaded] =
    useMutation<InstallApplicationModal_markFileBindAsUploaded_Mutation>(
      MARK_FILE_BIND_AS_UPLOADED_MUTATION,
    );

  const [markEnvFileAsUploaded] =
    useMutation<InstallApplicationModal_markEnvFileAsUploaded_Mutation>(
      MARK_ENV_FILE_AS_UPLOADED_MUTATION,
    );

  const commitMarkFileBindAsUploaded = useCallback(
    (
      variables: InstallApplicationModal_markFileBindAsUploaded_Mutation["variables"],
    ) =>
      new Promise<void>((resolve, reject) => {
        markFileBindAsUploaded({
          variables,
          onCompleted: (data, errors) => {
            if (errors?.length) {
              return reject(new Error(errors.map((e) => e.message).join(", ")));
            }
            if (data?.markFileBindAsUploaded?.result) {
              resolve();
            } else {
              reject(new Error("Failed to mark file bind as uploaded."));
            }
          },
          onError: reject,
        });
      }),
    [markFileBindAsUploaded],
  );

  const commitMarkEnvFileAsUploaded = useCallback(
    (
      variables: InstallApplicationModal_markEnvFileAsUploaded_Mutation["variables"],
    ) =>
      new Promise<void>((resolve, reject) => {
        markEnvFileAsUploaded({
          variables,
          onCompleted: (data, errors) => {
            if (errors?.length) {
              return reject(new Error(errors.map((e) => e.message).join(", ")));
            }
            if (data?.markEnvFileAsUploaded?.result) {
              resolve();
            } else {
              reject(new Error("Failed to mark env file as uploaded."));
            }
          },
          onError: reject,
        });
      }),
    [markEnvFileAsUploaded],
  );

  const handleAppChange = (option: SingleValue<SelectOption>) => {
    if (!isOnline) {
      setErrorFeedback(
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.deviceOfflineError"
          defaultMessage="The device is disconnected. You cannot deploy an application while it is offline."
        />,
      );
      return;
    }

    setSelectedApp(option?.value || null);
    setSelectedRelease(null);
    setMountValidity({});
    setEnvModes({});
    setEnvStrategies({});
    setEnvJsons({});
    setEnvSectionOpen(false);
    setMountsSectionOpen(false);
  };

  const handleReleaseChange = (option: SingleValue<SelectOption>) => {
    setSelectedRelease(option?.value || null);
    setMountValidity({});
    setEnvModes({});
    setEnvStrategies({});
    setEnvJsons({});
    setEnvSectionOpen(false);
    setMountsSectionOpen(false);
  };

  const resetSelections = useCallback(() => {
    setSelectedApp(null);
    setSelectedRelease(null);
    setMountValidity({});
    setEnvModes({});
    setEnvStrategies({});
    setEnvJsons({});
    setEnvSectionOpen(false);
    setMountsSectionOpen(false);
  }, []);

  const handleCancel = useCallback(() => {
    resetSelections();
    onToggleModal(false);
  }, [resetSelections, onToggleModal]);

  const handleDeploy = useCallback(async () => {
    if (!selectedRelease) return;

    if (!allRequiredMountsConfigured) {
      setErrorFeedback(
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.missingRequiredBindsFeedback"
          defaultMessage="Please configure a file source for all required file mounts."
        />,
      );
      return;
    }

    setIsSubmitting(true);
    setErrorFeedback(null);

    try {
      const pendingUploads: PendingUploadData[] = [];
      const pendingEnvUploads: EnvFilePendingUpload[] = [];
      const mountSpecs: Record<string, FileBindSpecInput> = {};
      const envFileSpecs: Record<string, EnvFileSpecInput> = {};

      for (const container of containersWithMounts) {
        for (const mount of container.mounts) {
          const ref = mountInputRefs.current[mount.id];
          if (ref) {
            const res = await ref.getFileBindSpec();
            if (res?.spec) {
              mountSpecs[mount.id] = res.spec;
              if (res.pendingUpload) {
                pendingUploads.push(res.pendingUpload);
              }
            } else if (
              mount.required &&
              !mount.defaultFileId &&
              !mount.defaultFile?.name
            ) {
              setIsSubmitting(false);
              setErrorFeedback(
                <FormattedMessage
                  id="components.apps.releases.install-application-modal.InstallApplicationModal.missingRequiredBindsFeedback"
                  defaultMessage="Please configure a file source for all required file mounts."
                />,
              );
              return;
            }
          }
        }
      }

      // Env file specs are only collected for containers in "file" mode.
      // Missing or unconfigured inputs simply yield no spec.
      for (const container of releaseContainers) {
        if (envModes[container.id] !== "file") {
          continue;
        }
        const ref = envFileInputRefs.current[container.id];
        if (ref) {
          const res = await ref.getEnvFileSpec();
          if (res?.spec) {
            envFileSpecs[container.id] = res.spec;
            if (res.pendingUpload) {
              pendingEnvUploads.push(res.pendingUpload);
            }
          }
        }
      }

      const deployConfigs: DeploymentConfigSpecInput[] = releaseContainers
        .map((container) => {
          const binds = container.mounts
            .map((mount) => mountSpecs[mount.id])
            .filter((b): b is FileBindSpecInput => !!b);

          const hasBinds = binds.length > 0;
          const containerEnv =
            envModes[container.id] === "override"
              ? parseEnvJson(envJsons[container.id] || "{}")
              : undefined;
          const hasEnv = !!containerEnv && containerEnv.length > 0;
          const containerStrategy = envStrategies[container.id] || "merge";
          // Single optional env file per container. Upload-sourced specs are
          // target-less; their file content is PUT to the presigned upload
          // URL returned by the deploy below, then marked as uploaded.
          const envFileSpec =
            envModes[container.id] === "file"
              ? envFileSpecs[container.id]
              : undefined;

          if (
            !hasBinds &&
            !hasEnv &&
            !envFileSpec &&
            containerStrategy === "merge"
          ) {
            return null;
          }

          return {
            containerId: container.id,
            envStrategy: containerStrategy,
            ...(hasEnv ? { env: containerEnv } : {}),
            ...(hasBinds ? { fileBinds: binds } : {}),
            ...(envFileSpec ? { envFiles: [envFileSpec] } : {}),
          };
        })
        .filter((c): c is NonNullable<typeof c> => !!c);

      deployRelease({
        variables: {
          input: {
            deviceId,
            releaseId: selectedRelease,
            ...(deployConfigs.length > 0 ? { configs: deployConfigs } : {}),
          },
        },
        onCompleted: (data, errors) => {
          (async () => {
            if (errors) {
              const errorFeedback = errors
                .map(({ fields, message }) =>
                  fields.length ? `${fields.join(" ")} ${message}` : message,
                )
                .join(". \n");
              setIsSubmitting(false);
              return setErrorFeedback(errorFeedback);
            }

            const deploymentResult = data?.deployRelease?.result;
            const deploymentId = deploymentResult?.id;

            if (!deploymentId) {
              setIsSubmitting(false);
              return setErrorFeedback(
                "Deployment failed: no deployment ID returned.",
              );
            }

            if (pendingUploads.length > 0 || pendingEnvUploads.length > 0) {
              try {
                const containerDeployments =
                  deploymentResult.containerDeployments?.edges
                    ?.map((edge) => edge?.node)
                    .filter(
                      (node): node is NonNullable<typeof node> => !!node,
                    ) ?? [];

                const allFileBinds = containerDeployments.flatMap(
                  (cd) => cd.fileBinds ?? [],
                );

                for (const pending of pendingUploads) {
                  const matchingBind = allFileBinds.find(
                    (fb) => fb.fileMount.id === pending.fileMountId,
                  );

                  if (!matchingBind || !matchingBind.uploadUrl) {
                    throw new Error(
                      `No presigned upload URL returned for file mount ${pending.fileMountId}.`,
                    );
                  }

                  const uploadRes = await fetch(matchingBind.uploadUrl, {
                    method: "PUT",
                    body: pending.file,
                    headers: {
                      "Content-Type":
                        pending.file.type || "application/octet-stream",
                    },
                  });

                  if (!uploadRes.ok) {
                    throw new Error(
                      `Failed to upload ${pending.fileName} to S3 (${uploadRes.statusText}).`,
                    );
                  }

                  await commitMarkFileBindAsUploaded({
                    id: matchingBind.id,
                    input: {
                      fileName: pending.fileName,
                      uncompressedFileSizeBytes:
                        pending.uncompressedFileSizeBytes,
                      digest: pending.digest,
                      encoding: pending.encoding,
                    },
                  });
                }

                for (const pending of pendingEnvUploads) {
                  // pending.containerId and cd.container.id are both GraphQL
                  // global IDs of the container, so they compare directly.
                  const matchingDeployment = containerDeployments.find(
                    (cd) => cd.container?.id === pending.containerId,
                  );
                  const matchingEnvFile = matchingDeployment?.envFiles?.find(
                    (envFile) => envFile.uploadUrl,
                  );

                  if (!matchingEnvFile || !matchingEnvFile.uploadUrl) {
                    throw new Error(
                      `No presigned upload URL returned for env file of container ${pending.containerId}.`,
                    );
                  }

                  const uploadRes = await fetch(matchingEnvFile.uploadUrl, {
                    method: "PUT",
                    body: pending.file,
                    headers: {
                      "Content-Type":
                        pending.file.type || "application/octet-stream",
                    },
                  });

                  if (!uploadRes.ok) {
                    throw new Error(
                      `Failed to upload ${pending.fileName} to S3 (${uploadRes.statusText}).`,
                    );
                  }

                  await commitMarkEnvFileAsUploaded({
                    id: matchingEnvFile.id,
                    input: {
                      fileName: pending.fileName,
                      uncompressedFileSizeBytes:
                        pending.uncompressedFileSizeBytes,
                      digest: pending.digest,
                      encoding: pending.encoding,
                    },
                  });
                }
              } catch (uploadErr: any) {
                setIsSubmitting(false);
                return setErrorFeedback(
                  uploadErr?.message || "Failed to complete file uploads.",
                );
              }
            }

            setIsSubmitting(false);
            resetSelections();
            setErrorFeedback(null);
            onToggleModal(false);

            return navigate({
              route: Route.deploymentEdit,
              params: { deviceId, deploymentId },
            });
          })();
        },
        onError: () => {
          setIsSubmitting(false);
          setErrorFeedback(
            <FormattedMessage
              id="components.apps.releases.install-application-modal.InstallApplicationModal.deployErrorFeedback"
              defaultMessage="Could not deploy the Application, please try again."
            />,
          );
        },
      });
    } catch (err: any) {
      setIsSubmitting(false);
      setErrorFeedback(
        err?.message || "An unexpected error occurred during deployment.",
      );
    }
  }, [
    selectedRelease,
    allRequiredMountsConfigured,
    containersWithMounts,
    releaseContainers,
    envModes,
    envStrategies,
    envJsons,
    parseEnvJson,
    deployRelease,
    deviceId,
    commitMarkFileBindAsUploaded,
    commitMarkEnvFileAsUploaded,
    intl,
    resetSelections,
    setErrorFeedback,
    onToggleModal,
    navigate,
  ]);

  return (
    <ConfirmModal
      size="lg"
      title={
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.title"
          defaultMessage="Install Application"
        />
      }
      confirmLabel={
        <FormattedMessage
          id="components.apps.releases.install-application-modal.InstallApplicationModal.deployButton"
          defaultMessage="Deploy"
        />
      }
      show={open}
      onCancel={handleCancel}
      onConfirm={handleDeploy}
      disabled={
        !isOnline ||
        !selectedRelease ||
        !allRequiredMountsConfigured ||
        !allEnvJsonValid ||
        isSubmitting ||
        isDeploying
      }
      isConfirming={isDeploying || isSubmitting}
    >
      <div className="d-flex flex-column gap-2">
        <FormRow
          id="select-application"
          label={intl.formatMessage({
            id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectApplication",
            defaultMessage: "Application",
          })}
        >
          <Select
            value={selectedApplicationOption}
            onChange={handleAppChange}
            options={applicationOptions}
            isClearable
            menuPlacement="auto"
            placeholder={intl.formatMessage({
              id: "components.apps.releases.install-application-modal.InstallApplicationModal.searchPlaceholder",
              defaultMessage: "Search or select an application...",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.noApplicationsFoundMatching",
                      defaultMessage:
                        'No applications found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : intl.formatMessage({
                    id: "components.apps.releases.install-application-modal.InstallApplicationModal.noApplicationsAvailable",
                    defaultMessage: "No applications available",
                  })
            }
            filterOption={(option, inputValue) => {
              return option.label
                .toLowerCase()
                .includes(inputValue.toLowerCase());
            }}
          />
        </FormRow>

        <FormRow
          id="select-release"
          label={intl.formatMessage({
            id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectRelease",
            defaultMessage: "Release",
          })}
        >
          <Select
            value={selectedReleaseOption}
            onChange={handleReleaseChange}
            options={releaseOptions}
            isClearable
            menuPlacement="auto"
            placeholder={intl.formatMessage({
              id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectARelease",
              defaultMessage: "Select a release",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.noReleasesFoundMatching",
                      defaultMessage:
                        'No releases found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : selectedApp
                  ? intl.formatMessage({
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.noReleasesAvailable",
                      defaultMessage:
                        "No releases available for this application",
                    })
                  : intl.formatMessage({
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectApplicationFirst",
                      defaultMessage: "Please select an application first",
                    })
            }
            filterOption={(option, inputValue) => {
              return option.label
                .toLowerCase()
                .includes(inputValue.toLowerCase());
            }}
            isDisabled={!selectedApp}
            isOptionDisabled={(option) => option.disabled}
          />
        </FormRow>

        {selectedRelease && (
          <div className="mt-2 pt-2 border-top">
            <CollapseItem
              title={
                <FormattedMessage
                  id="components.apps.releases.install-application-modal.InstallApplicationModal.environmentConfigurationTitle"
                  defaultMessage="Environment configuration"
                />
              }
              open={envSectionOpen}
              onToggle={() => setEnvSectionOpen((prev) => !prev)}
              caretPosition="right"
              headerClassName="fw-semibold ps-0 border-0"
              contentClassName="pt-2"
            >
              <div
                className="d-flex flex-column gap-3 overflow-auto pe-1 pb-5"
                style={{ maxHeight: "55vh" }}
              >
                {releaseContainers.map((container) => {
                  const containerEnvMode = envModes[container.id] || "none";
                  const containerEnvJson = envJsons[container.id] || "{}";
                  const containerEnvJsonValid =
                    isEnvJsonValid(containerEnvJson);
                  return (
                    <div
                      key={container.id}
                      className="border rounded p-3 bg-light"
                      data-testid={`container-env-files-${container.id}`}
                    >
                      <div className="fw-bold mb-2 small text-secondary">
                        <FormattedMessage
                          id="components.apps.releases.install-application-modal.InstallApplicationModal.containerLabel"
                          defaultMessage="Container: {containerName}"
                          values={{ containerName: container.name }}
                        />
                      </div>

                      <ToggleButtonGroup
                        type="radio"
                        name={`env-mode-${container.id}`}
                        value={containerEnvMode}
                        onChange={(value: EnvMode) =>
                          setEnvModes((prev) => ({
                            ...prev,
                            [container.id]: value,
                          }))
                        }
                        size="sm"
                        className="mb-2"
                      >
                        <ToggleButton
                          id={`env-mode-none-${container.id}`}
                          value="none"
                          variant="outline-primary"
                        >
                          <FormattedMessage
                            id="components.apps.releases.install-application-modal.InstallApplicationModal.envModeNone"
                            defaultMessage="No config"
                          />
                        </ToggleButton>

                        <ToggleButton
                          id={`env-mode-override-${container.id}`}
                          value="override"
                          variant="outline-primary"
                        >
                          <FormattedMessage
                            id="components.apps.releases.install-application-modal.InstallApplicationModal.envModeOverride"
                            defaultMessage="Env override"
                          />
                        </ToggleButton>

                        <ToggleButton
                          id={`env-mode-file-${container.id}`}
                          value="file"
                          variant="outline-primary"
                        >
                          <FormattedMessage
                            id="components.apps.releases.install-application-modal.InstallApplicationModal.envModeFile"
                            defaultMessage="Env file"
                          />
                        </ToggleButton>
                      </ToggleButtonGroup>

                      {containerEnvMode === "override" && (
                        <>
                          <FormRow
                            id={`select-env-strategy-${container.id}`}
                            label={intl.formatMessage({
                              id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectEnvStrategy",
                              defaultMessage: "Env Strategy",
                            })}
                          >
                            <Select
                              value={selectedEnvStrategyOption(container.id)}
                              onChange={(option) =>
                                setEnvStrategies((prev) => ({
                                  ...prev,
                                  [container.id]: option?.value || "merge",
                                }))
                              }
                              options={envStrategyOptions}
                              menuPlacement="auto"
                            />
                          </FormRow>

                          <FormRow
                            id={`env-json-${container.id}`}
                            label={intl.formatMessage({
                              id: "components.apps.releases.install-application-modal.InstallApplicationModal.envJsonLabel",
                              defaultMessage: "Environment",
                            })}
                          >
                            <MonacoJsonEditor
                              value={containerEnvJson}
                              onChange={(val) =>
                                setEnvJsons((prev) => ({
                                  ...prev,
                                  [container.id]: val ?? "",
                                }))
                              }
                              defaultValue="{}"
                              error={
                                !containerEnvJsonValid
                                  ? intl.formatMessage({
                                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.invalidJsonError",
                                      defaultMessage:
                                        "Invalid JSON. Expected a JSON object mapping keys to string values.",
                                    })
                                  : undefined
                              }
                            />
                          </FormRow>
                        </>
                      )}

                      {containerEnvMode === "file" && (
                        <EnvFileInput
                          key={container.id}
                          ref={(el) => {
                            envFileInputRefs.current[container.id] = el;
                          }}
                          containerId={container.id}
                          deviceId={deviceId}
                          deviceFiles={deviceFiles}
                          fileDownloadRequests={fileDownloadRequests}
                        />
                      )}
                    </div>
                  );
                })}
              </div>
            </CollapseItem>
          </div>
        )}

        {containersWithMounts.length > 0 && (
          <div className="mt-2 pt-2 border-top">
            <CollapseItem
              title={
                <FormattedMessage
                  id="components.apps.releases.install-application-modal.InstallApplicationModal.fileBindsTitle"
                  defaultMessage="File Mounts Configuration"
                />
              }
              open={mountsSectionOpen}
              onToggle={() => setMountsSectionOpen((prev) => !prev)}
              caretPosition="right"
              headerClassName="fw-semibold ps-0 border-0"
              contentClassName="pt-2"
            >
              {hasRequiredMounts && hasNoFilesOnDevice && (
                <Alert variant="warning" className="py-2 px-3 mb-2 small">
                  <FormattedMessage
                    id="components.apps.releases.install-application-modal.InstallApplicationModal.noFilesAvailableWarning"
                    defaultMessage="This device has no available files or download requests. To deploy this release with required file mounts, please first upload a file or initiate a download request on the device."
                  />
                </Alert>
              )}

              <div
                className="d-flex flex-column gap-3 overflow-auto pe-1 pb-5"
                style={{ maxHeight: "55vh" }}
              >
                {containersWithMounts.map((container) => (
                  <div
                    key={container.id}
                    className="border rounded p-3 bg-light"
                    data-testid={`container-mounts-${container.id}`}
                  >
                    <div className="fw-bold mb-2 small text-secondary">
                      <FormattedMessage
                        id="components.apps.releases.install-application-modal.InstallApplicationModal.containerLabel"
                        defaultMessage="Container: {containerName}"
                        values={{ containerName: container.name }}
                      />
                    </div>

                    <div className="d-flex flex-column gap-2">
                      {container.mounts.map((mount) => {
                        return (
                          <FileMountInput
                            key={mount.id}
                            ref={(el) => {
                              mountInputRefs.current[mount.id] = el;
                            }}
                            fileMountId={mount.id}
                            mountpoint={mount.mountpoint}
                            required={mount.required}
                            deviceId={deviceId}
                            defaultFileId={mount.defaultFileId}
                            defaultFileName={mount.defaultFile?.name}
                            deviceFiles={deviceFiles}
                            fileDownloadRequests={fileDownloadRequests}
                            onChange={(result, isValid) =>
                              handleFileBindChange(mount.id, result, isValid)
                            }
                          />
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </CollapseItem>
          </div>
        )}
      </div>
    </ConfirmModal>
  );
};

export default InstallApplicationModal;
