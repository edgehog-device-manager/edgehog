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
  FileBindSpecInput,
  InstallApplicationModal_DeployRelease_Mutation,
} from "@/api/__generated__/InstallApplicationModal_DeployRelease_Mutation.graphql";
import type { InstallApplicationModal_markFileBindAsUploaded_Mutation } from "@/api/__generated__/InstallApplicationModal_markFileBindAsUploaded_Mutation.graphql";
import { useNavigate, Route } from "@/Navigation";
import Select from "@/components/ui/select/Select";
import { FormRow } from "@/components/ui/form-row/FormRow";
import ConfirmModal from "@/components/ui/confirm-modal/ConfirmModal";
import Alert from "@/components/ui/alert/Alert";
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
              fileBinds {
                id
                fileMountId
                fileMount {
                  id
                }
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
  const [envStrategy, setEnvStrategy] = useState<string>("merge");
  const [envJson, setEnvJson] = useState<string>("{}");
  const [mountValidity, setMountValidity] = useState<Record<string, boolean>>(
    {},
  );
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const mountInputRefs = useRef<Record<string, FileMountInputRef | null>>({});

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

  const selectedEnvStrategyOption = useMemo(() => {
    return (
      envStrategyOptions.find((opt) => opt.value === envStrategy) ||
      envStrategyOptions[0]
    );
  }, [envStrategyOptions, envStrategy]);

  const parsedEnv = useMemo((): ContainerEnvVarInput[] | undefined => {
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
  }, [envJson]);

  const isEnvJsonValid = useMemo(() => {
    if (!envJson || !envJson.trim()) return true;
    try {
      const parsed = JSON.parse(envJson);
      return (
        typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
      );
    } catch {
      return false;
    }
  }, [envJson]);

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
    setEnvStrategy("merge");
    setEnvJson("{}");
  };

  const handleReleaseChange = (option: SingleValue<SelectOption>) => {
    setSelectedRelease(option?.value || null);
    setMountValidity({});
    setEnvStrategy("merge");
    setEnvJson("{}");
  };

  const resetSelections = useCallback(() => {
    setSelectedApp(null);
    setSelectedRelease(null);
    setMountValidity({});
    setEnvStrategy("merge");
    setEnvJson("{}");
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
      const mountSpecs: Record<string, FileBindSpecInput> = {};

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

      const deployConfigs: DeploymentConfigSpecInput[] = releaseContainers
        .map((container) => {
          const binds = container.mounts
            .map((mount) => mountSpecs[mount.id])
            .filter((b): b is FileBindSpecInput => !!b);

          const hasBinds = binds.length > 0;
          const hasEnv = !!parsedEnv && parsedEnv.length > 0;

          if (!hasBinds && !hasEnv && envStrategy === "merge") {
            return null;
          }

          return {
            containerId: container.id,
            envStrategy,
            ...(hasEnv ? { env: parsedEnv } : {}),
            ...(hasBinds ? { fileBinds: binds } : {}),
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

            if (pendingUploads.length > 0) {
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
    parsedEnv,
    envStrategy,
    deployRelease,
    deviceId,
    commitMarkFileBindAsUploaded,
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
        !isEnvJsonValid ||
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

        <FormRow
          id="select-env-strategy"
          label={intl.formatMessage({
            id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectEnvStrategy",
            defaultMessage: "Env Strategy",
          })}
        >
          <Select
            value={selectedEnvStrategyOption}
            onChange={(option) => setEnvStrategy(option?.value || "merge")}
            options={envStrategyOptions}
            menuPlacement="auto"
            isDisabled={!selectedRelease}
          />
        </FormRow>

        <FormRow
          id="env-json"
          label={intl.formatMessage({
            id: "components.apps.releases.install-application-modal.InstallApplicationModal.envJsonLabel",
            defaultMessage: "Environment",
          })}
        >
          <MonacoJsonEditor
            value={envJson}
            onChange={(val) => setEnvJson(val ?? "")}
            defaultValue="{}"
            error={
              !isEnvJsonValid
                ? intl.formatMessage({
                    id: "components.apps.releases.install-application-modal.InstallApplicationModal.invalidJsonError",
                    defaultMessage:
                      "Invalid JSON. Expected a JSON object mapping keys to string values.",
                  })
                : undefined
            }
            readonly={!selectedRelease}
          />
        </FormRow>

        {containersWithMounts.length > 0 && (
          <div className="mt-2 pt-2 border-top">
            <h6 className="mb-2 fw-semibold">
              <FormattedMessage
                id="components.apps.releases.install-application-modal.InstallApplicationModal.fileBindsTitle"
                defaultMessage="File Mounts Configuration"
              />
            </h6>

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
          </div>
        )}
      </div>
    </ConfirmModal>
  );
};

export default InstallApplicationModal;
