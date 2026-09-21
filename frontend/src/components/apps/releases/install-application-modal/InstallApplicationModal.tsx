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

import React, { useCallback, useState, useMemo, useEffect } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  useLazyLoadQuery,
  useMutation,
  fetchQuery,
} from "react-relay/hooks";
import { SingleValue } from "react-select";

import type { InstallApplicationModal_GetApplicationsWithReleases_Query } from "@/api/__generated__/InstallApplicationModal_GetApplicationsWithReleases_Query.graphql";
import type { InstallApplicationModal_DeployRelease_Mutation } from "@/api/__generated__/InstallApplicationModal_DeployRelease_Mutation.graphql";
import type { InstallApplicationModal_GetReleaseContainers_Query } from "@/api/__generated__/InstallApplicationModal_GetReleaseContainers_Query.graphql";
import { useNavigate, Route } from "@/Navigation";
import Select from "@/components/ui/select/Select";
import { FormRow } from "@/components/ui/form-row/FormRow";
import ConfirmModal from "@/components/ui/confirm-modal/ConfirmModal";
import EnvVarEditor, {
  type EnvVar,
} from "@/components/apps/deploy/env-var-editor/EnvVarEditor";
import EnvStrategySelect, {
  type EnvStrategy,
} from "@/components/apps/deploy/env-strategy-select/EnvStrategySelect";
import EnvFileSelector, {
  type EnvFileSource,
} from "@/components/apps/deploy/env-file-selector/EnvFileSelector";
import CollapseItem, {
  useCollapsibleSections,
} from "@/components/ui/collapse-item/CollapseItem";
import { useRelayEnvironment } from "react-relay/hooks";

const GET_APPLICATIONS_WITH_RELEASES_QUERY = graphql`
  query InstallApplicationModal_GetApplicationsWithReleases_Query(
    $filter: ApplicationFilterInput = {}
  ) {
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
              }
            }
          }
        }
      }
    }
  }
`;

const GET_RELEASE_CONTAINERS_QUERY = graphql`
  query InstallApplicationModal_GetReleaseContainers_Query($id: ID!) {
    release(id: $id) {
      id
      containers(first: 100) {
        edges {
          node {
            id
            name
          }
        }
      }
    }
  }
`;

const GET_DEVICE_FILES_QUERY = graphql`
  query InstallApplicationModal_GetDeviceFiles_Query($deviceId: ID!) {
    device(id: $deviceId) {
      id
      deviceFiles(first: 100, filter: { deleted: { eq: false } }) {
        edges {
          node {
            id
            pathOnDevice
            fileId
          }
        }
      }
      fileDownloadRequests(
        first: 100
        sort: [{ field: UPDATED_AT, order: DESC }]
      ) {
        edges {
          node {
            id
            fileName
            status
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
        containerDeployments(first: 100) {
          edges {
            node {
              id
              container {
                id
              }
              envFiles {
                id
                uploadUrl
              }
            }
          }
        }
      }
      errors {
        message
        fields
      }
    }
  }
`;

const MARK_ENV_FILE_AS_UPLOADED_MUTATION = graphql`
  mutation InstallApplicationModal_MarkEnvFileAsUploaded_Mutation(
    $id: ID!
    $input: MarkEnvFileAsUploadedInput!
  ) {
    markEnvFileAsUploaded(id: $id, input: $input) {
      result {
        id
        uploaded
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
  const [releaseContainers, setReleaseContainers] = useState<
    { id: string; name: string }[]
  >([]);
  type ContainerMode = "none" | "vars" | "file";
  const [configs, setConfigs] = useState<
    Record<
      string,
      {
        mode: ContainerMode;
        env: EnvVar[];
        envStrategy: EnvStrategy;
        envFile: EnvFileSource;
      }
    >
  >({});
  const [configError, setConfigError] = useState<string | null>(null);
  const [deviceFileOptions, setDeviceFileOptions] = useState<
    { value: string; label: string }[]
  >([]);
  const [downloadRequestOptions, setDownloadRequestOptions] = useState<
    { value: string; label: string }[]
  >([]);
  const { toggleSection, isSectionOpen, setOpenSections } =
    useCollapsibleSections<string>([]);

  const data =
    useLazyLoadQuery<InstallApplicationModal_GetApplicationsWithReleases_Query>(
      GET_APPLICATIONS_WITH_RELEASES_QUERY,
      {
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

  const [deployRelease, isDeploying] =
    useMutation<InstallApplicationModal_DeployRelease_Mutation>(
      DEPLOY_RELEASE_MUTATION,
    );

  const [markEnvFileAsUploaded] = useMutation(
    MARK_ENV_FILE_AS_UPLOADED_MUTATION,
  );

  const environment = useRelayEnvironment();

  // Load containers when release changes
  useEffect(() => {
    if (!selectedRelease) return;
    fetchQuery<InstallApplicationModal_GetReleaseContainers_Query>(
      environment,
      GET_RELEASE_CONTAINERS_QUERY,
      { id: selectedRelease },
    )
      .toPromise()
      .then((data) => {
        const containers =
          data?.release?.containers?.edges
            ?.map((e) => e?.node)
            .filter((n): n is { id: string; name: string } => !!n) ?? [];
        setReleaseContainers(containers);
        setConfigs((prev) => {
          const next: Record<
            string,
            {
              mode: ContainerMode;
              env: EnvVar[];
              envStrategy: EnvStrategy;
              envFile: EnvFileSource;
            }
          > = {};
          containers.forEach((c) => {
            next[c.id] = prev[c.id] ?? {
              mode: "none" as ContainerMode,
              env: [],
              envStrategy: "merge" as EnvStrategy,
              envFile: { type: "deviceFile", id: "" } as EnvFileSource,
            };
          });
          return next;
        });
        setOpenSections(containers.slice(0, 1).map((c) => c.id));
      })
      .catch(() => {
        setReleaseContainers([]);
      });
  }, [selectedRelease, environment, setOpenSections]);

  // Load device files and download requests for searchable selects
  useEffect(() => {
    if (!open || !deviceId) return;
    fetchQuery(environment, GET_DEVICE_FILES_QUERY, { deviceId })
      .toPromise()
      .then((data: unknown) => {
        const d = data as {
          device?: {
            deviceFiles?: {
              edges:
                | {
                    node: {
                      id: string;
                      pathOnDevice?: string | null;
                      fileId?: string | null;
                    } | null;
                  }[]
                | null;
            } | null;
            fileDownloadRequests?: {
              edges:
                | {
                    node: {
                      id: string;
                      fileName?: string | null;
                      status?: string | null;
                    } | null;
                  }[]
                | null;
            } | null;
          } | null;
        };
        const files =
          d?.device?.deviceFiles?.edges
            ?.map((e) => e?.node)
            .filter(
              (
                n,
              ): n is {
                id: string;
                pathOnDevice?: string | null;
                fileId?: string | null;
              } => !!n,
            )
            .map((n) => ({
              value: n.id,
              label: n.pathOnDevice || n.fileId || n.id,
            })) ?? [];
        const requests =
          d?.device?.fileDownloadRequests?.edges
            ?.map((e) => e?.node)
            .filter(
              (
                n,
              ): n is {
                id: string;
                fileName?: string | null;
                status?: string | null;
              } => !!n,
            )
            .map((n) => ({
              value: n.id,
              label: n.fileName ? `${n.fileName} (${n.status ?? ""})` : n.id,
            })) ?? [];
        setDeviceFileOptions(files);
        setDownloadRequestOptions(requests);
      })
      .catch(() => {
        setDeviceFileOptions([]);
        setDownloadRequestOptions([]);
      });
  }, [open, deviceId, environment]);

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
    setSelectedRelease(null); // Reset release when app changes
  };

  const handleReleaseChange = (option: SingleValue<SelectOption>) => {
    const newId = option?.value || null;
    setSelectedRelease(newId);
    if (!newId) {
      setReleaseContainers([]);
      setConfigs({});
      setOpenSections([]);
    }
  };

  const resetSelections = useCallback(() => {
    setSelectedApp(null);
    setSelectedRelease(null);
    setReleaseContainers([]);
    setConfigs({});
    setConfigError(null);
    setOpenSections([]);
  }, [setOpenSections]);

  const handleCancel = useCallback(() => {
    resetSelections();
    onToggleModal(false);
  }, [resetSelections, onToggleModal]);

  const validateConfigs = useCallback(() => {
    for (const [cid, cfg] of Object.entries(configs)) {
      if (cfg.mode === "vars") {
        const keys = cfg.env.map((e) => e.key.trim()).filter(Boolean);
        if (cfg.env.some((e) => e.key.trim() === "" && e.value !== "")) {
          return `Container ${cid}: env key must not be empty`;
        }
        if (new Set(keys).size !== keys.length) {
          return `Container ${cid}: duplicate env keys`;
        }
      } else if (cfg.mode === "file") {
        if (cfg.envFile.type === "deviceFile" && !cfg.envFile.id.trim()) {
          return `Container ${cid}: device file required`;
        }
        if (
          cfg.envFile.type === "fileDownloadRequest" &&
          !cfg.envFile.id.trim()
        ) {
          return `Container ${cid}: file download request required`;
        }
        if (
          cfg.envFile.type === "upload" &&
          (!cfg.envFile.file || cfg.envFile.file.size === 0)
        ) {
          return `Container ${cid}: file to upload required`;
        }
      }
    }
    return null;
  }, [configs]);

  const uploadEnvFiles = useCallback(
    async (
      containerDeployments: ReadonlyArray<{
        container: { id: string } | null;
        envFiles: ReadonlyArray<{
          id: string;
          uploadUrl: string | null;
        } | null> | null;
      } | null> | null,
    ) => {
      if (!containerDeployments) return;
      for (const cd of containerDeployments) {
        const cid = cd?.container?.id;
        if (!cid) continue;
        const cfg = configs[cid];
        if (
          !cfg ||
          cfg.mode !== "file" ||
          cfg.envFile.type !== "upload" ||
          !cfg.envFile.file
        )
          continue;
        const envFile = cd.envFiles?.[0];
        if (!envFile?.uploadUrl || !envFile?.id) continue;
        const edge = envFile;
        const file = cfg.envFile.file;
        try {
          // compute digest (SHA-256 hex)
          const buf = await file.arrayBuffer();
          const hashBuf = await crypto.subtle.digest("SHA-256", buf);
          const digest =
            "sha256:" +
            Array.from(new Uint8Array(hashBuf))
              .map((b) => b.toString(16).padStart(2, "0"))
              .join("");
          const targetUrl: string = edge.uploadUrl as string;
          const putRes = await fetch(targetUrl, {
            method: "PUT",
            body: file,
          });
          if (!putRes.ok) throw new Error(`Upload failed ${putRes.status}`);
          await new Promise<void>((resolve, reject) => {
            markEnvFileAsUploaded({
              variables: {
                id: edge.id,
                input: {
                  fileName: file.name,
                  digest,
                  encoding: "",
                  uncompressedFileSizeBytes: file.size,
                },
              },
              onCompleted: (
                d: unknown,
                errs: readonly { message: string | null }[] | null,
              ) => {
                const typed = d as {
                  markEnvFileAsUploaded?: {
                    errors: { message: string | null }[];
                  };
                };
                if (errs?.length)
                  return reject(new Error(errs[0].message ?? "unknown"));
                if (typed?.markEnvFileAsUploaded?.errors?.length)
                  return reject(
                    new Error(
                      typed.markEnvFileAsUploaded.errors[0].message ?? "",
                    ),
                  );
                resolve();
              },
              onError: (e: Error) => reject(e),
            });
          });
        } catch (e) {
          setErrorFeedback(
            String(e) ||
              intl.formatMessage({
                id: "components.apps.releases.install-application-modal.InstallApplicationModal.uploadError",
                defaultMessage: "Env file upload failed",
              }),
          );
        }
      }
    },
    [configs, markEnvFileAsUploaded, setErrorFeedback, intl],
  );

  const handleDeploy = useCallback(() => {
    if (!selectedRelease) return;
    const validation = validateConfigs();
    if (validation) {
      setConfigError(validation);
      return;
    }
    setConfigError(null);

    const hasCustomConfig = Object.values(configs).some(
      (c) =>
        (c.mode === "vars" &&
          (c.env.length > 0 || c.envStrategy !== "merge")) ||
        c.mode === "file",
    );

    const configsInput = hasCustomConfig
      ? Object.entries(configs)
          .filter(
            ([, c]) =>
              (c.mode === "vars" &&
                (c.env.length > 0 || c.envStrategy !== "merge")) ||
              c.mode === "file",
          )
          .map(([containerId, c]) => {
            if (c.mode === "vars") {
              const env =
                c.env.length > 0
                  ? c.env
                      .filter((e) => e.key.trim() !== "")
                      .map((e) => ({ key: e.key.trim(), value: e.value }))
                  : undefined;
              const envStrategy =
                c.envStrategy !== "merge" ? c.envStrategy : undefined;
              return {
                containerId,
                ...(env ? { env } : {}),
                ...(envStrategy ? { envStrategy } : {}),
              };
            }
            if (c.mode === "file") {
              let envFiles:
                | { deviceFileId?: string; fileDownloadRequestId?: string }[]
                | undefined;
              if (c.envFile.type === "deviceFile") {
                envFiles = [{ deviceFileId: c.envFile.id.trim() }];
              } else if (c.envFile.type === "fileDownloadRequest") {
                envFiles = [{ fileDownloadRequestId: c.envFile.id.trim() }];
              } else if (c.envFile.type === "upload") {
                envFiles = [{}];
              }
              return {
                containerId,
                ...(envFiles ? { envFiles } : {}),
              };
            }
            return { containerId };
          })
      : undefined;

    deployRelease({
      variables: {
        input: {
          deviceId: deviceId,
          releaseId: selectedRelease,
          ...(configsInput ? { configs: configsInput } : {}),
        },
      },
      onCompleted: (data, errors) => {
        if (errors) {
          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields?.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          return setErrorFeedback(errorFeedback);
        }
        const raw = data as unknown as {
          deployRelease?: {
            errors?: { message: string | null; fields: string[] | null }[];
            result?: {
              id: string;
              containerDeployments?: {
                edges: ReadonlyArray<{
                  node: {
                    container: { id: string } | null;
                    envFiles: ReadonlyArray<{
                      id: string;
                      uploadUrl: string | null;
                    } | null> | null;
                  } | null;
                } | null> | null;
              } | null;
            };
          };
        };
        if (raw?.deployRelease?.errors?.length) {
          return setErrorFeedback(
            raw.deployRelease.errors.map((e) => e.message).join(". "),
          );
        }
        const deployment = raw?.deployRelease?.result;

        if (deployment?.containerDeployments) {
          void uploadEnvFiles(
            (deployment.containerDeployments.edges
              ?.map((e) => e?.node)
              .filter(Boolean) as never) ?? [],
          );
        }

        resetSelections();
        setErrorFeedback(null);
        onToggleModal(false);

        const deploymentId = data?.deployRelease?.result?.id;

        if (deploymentId) {
          return navigate({
            route: Route.deploymentEdit,
            params: { deviceId, deploymentId },
          });
        }
      },
      onError: () => {
        setErrorFeedback(
          <FormattedMessage
            id="components.apps.releases.install-application-modal.InstallApplicationModal.deployErrorFeedback"
            defaultMessage="Could not deploy the Application, please try again."
          />,
        );
      },
    });
  }, [
    deviceId,
    selectedRelease,
    deployRelease,
    resetSelections,
    setErrorFeedback,
    onToggleModal,
    navigate,
    configs,
    validateConfigs,
    uploadEnvFiles,
  ]);

  const isConfirmDisabled =
    !isOnline || !selectedRelease || !!validateConfigs();

  return (
    <ConfirmModal
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
      disabled={isConfirmDisabled}
      isConfirming={isDeploying}
    >
      <div className="d-flex flex-column gap-3">
        <div className="d-flex flex-column gap-2">
          <FormRow
            id="select-application"
            label={intl.formatMessage({
              id: "components.apps.releases.install-application-modal.InstallApplicationModal.selectApplication",
              defaultMessage: "Select Application",
            })}
          >
            <Select
              value={selectedApplicationOption}
              onChange={handleAppChange}
              options={applicationOptions}
              isClearable
              menuPortalTarget={document.body}
              menuPosition="fixed"
              styles={{
                menuPortal: (base: any) => ({ ...base, zIndex: 9999 }) as any,
              }}
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
              defaultMessage: "Select Release",
            })}
          >
            <Select
              value={selectedReleaseOption}
              onChange={handleReleaseChange}
              options={releaseOptions}
              isClearable
              menuPortalTarget={document.body}
              menuPosition="fixed"
              styles={{
                menuPortal: (base: any) => ({ ...base, zIndex: 9999 }) as any,
              }}
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
        </div>

        {selectedRelease && (
          <>
            {configError && (
              <div className="alert alert-danger py-2 small mb-0">
                {configError}
              </div>
            )}
            {releaseContainers.map((container) => {
              const cfg = configs[container.id];
              if (!cfg) return null;
              const envSummary =
                cfg.mode === "vars" && cfg.env.length > 0
                  ? `${cfg.env.length} var(s)`
                  : cfg.mode === "vars"
                    ? intl.formatMessage({
                        id: "components.apps.releases.install-application-modal.InstallApplicationModal.noEnvVars",
                        defaultMessage: "no env vars",
                      })
                    : "";
              const fileSummary =
                cfg.mode === "file"
                  ? cfg.envFile.type === "upload"
                    ? (cfg.envFile.file?.name ?? "upload")
                    : cfg.envFile.id
                      ? cfg.envFile.id.slice(0, 8)
                      : intl.formatMessage({
                          id: "components.apps.releases.install-application-modal.InstallApplicationModal.noFileSelected",
                          defaultMessage: "no file selected",
                        })
                  : "";
              const modeLabel =
                cfg.mode === "none"
                  ? intl.formatMessage({
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeNone",
                      defaultMessage: "no override",
                    })
                  : cfg.mode === "vars"
                    ? `${cfg.envStrategy} • ${envSummary}`
                    : fileSummary;
              return (
                <CollapseItem
                  key={container.id}
                  title={container.name}
                  open={isSectionOpen(container.id)}
                  onToggle={() => toggleSection(container.id)}
                  caretPosition="right"
                  headerClassName="fw-bold border rounded"
                  contentClassName="border rounded p-3 mt-1 overflow-hidden"
                  rightContent={
                    <span className="small text-muted">{modeLabel}</span>
                  }
                >
                  <FormRow
                    id={`mode-${container.id}`}
                    label={intl.formatMessage({
                      id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeLabel",
                      defaultMessage: "Configuration",
                    })}
                  >
                    <Select
                      value={
                        [
                          {
                            value: "none",
                            label: intl.formatMessage({
                              id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeNoneLabel",
                              defaultMessage: "No override",
                            }),
                          },
                          {
                            value: "vars",
                            label: intl.formatMessage({
                              id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeVarsLabel",
                              defaultMessage:
                                "Additional environment variables",
                            }),
                          },
                          {
                            value: "file",
                            label: intl.formatMessage({
                              id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeFileLabel",
                              defaultMessage: "Environment file",
                            }),
                          },
                        ].find((o) => o.value === cfg.mode) ?? null
                      }
                      onChange={(opt) => {
                        const v =
                          (opt as { value: ContainerMode } | null)?.value ??
                          "none";
                        setConfigs((prev) => ({
                          ...prev,
                          [container.id]: { ...prev[container.id], mode: v },
                        }));
                      }}
                      options={[
                        {
                          value: "none",
                          label: intl.formatMessage({
                            id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeNoneLabel",
                            defaultMessage: "No override",
                          }),
                        },
                        {
                          value: "vars",
                          label: intl.formatMessage({
                            id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeVarsLabel",
                            defaultMessage: "Additional environment variables",
                          }),
                        },
                        {
                          value: "file",
                          label: intl.formatMessage({
                            id: "components.apps.releases.install-application-modal.InstallApplicationModal.modeFileLabel",
                            defaultMessage: "Environment file",
                          }),
                        },
                      ]}
                      isClearable={false}
                      isSearchable={false}
                      menuPortalTarget={document.body}
                      menuPosition="fixed"
                      styles={{
                        menuPortal: (base: any) =>
                          ({ ...base, zIndex: 9999 }) as any,
                      }}
                    />
                  </FormRow>
                  {cfg.mode === "vars" && (
                    <>
                      <FormRow
                        id={`env-strategy-${container.id}`}
                        label={intl.formatMessage({
                          id: "components.apps.releases.install-application-modal.InstallApplicationModal.envStrategy",
                          defaultMessage: "Env strategy",
                        })}
                      >
                        <EnvStrategySelect
                          value={cfg.envStrategy}
                          onChange={(v) =>
                            setConfigs((prev) => ({
                              ...prev,
                              [container.id]: {
                                ...prev[container.id],
                                envStrategy: v,
                              },
                            }))
                          }
                        />
                      </FormRow>
                      <FormRow
                        id={`env-vars-${container.id}`}
                        label={intl.formatMessage({
                          id: "components.apps.releases.install-application-modal.InstallApplicationModal.envVars",
                          defaultMessage: "Additional env vars (JSON)",
                        })}
                      >
                        <EnvVarEditor
                          value={cfg.env}
                          onChange={(env) =>
                            setConfigs((prev) => ({
                              ...prev,
                              [container.id]: { ...prev[container.id], env },
                            }))
                          }
                        />
                      </FormRow>
                    </>
                  )}
                  {cfg.mode === "file" && (
                    <FormRow
                      id={`env-file-${container.id}`}
                      label={intl.formatMessage({
                        id: "components.apps.releases.install-application-modal.InstallApplicationModal.envFile",
                        defaultMessage: "Env file",
                      })}
                    >
                      <EnvFileSelector
                        value={cfg.envFile}
                        onChange={(envFile) =>
                          setConfigs((prev) => ({
                            ...prev,
                            [container.id]: { ...prev[container.id], envFile },
                          }))
                        }
                        deviceFileOptions={deviceFileOptions}
                        downloadRequestOptions={downloadRequestOptions}
                      />
                    </FormRow>
                  )}
                </CollapseItem>
              );
            })}
            {releaseContainers.length === 0 && (
              <div className="text-muted small fst-italic">
                <FormattedMessage
                  id="components.apps.releases.install-application-modal.InstallApplicationModal.noContainers"
                  defaultMessage="No containers in this release."
                />
              </div>
            )}
          </>
        )}
      </div>
    </ConfirmModal>
  );
};

export default InstallApplicationModal;
