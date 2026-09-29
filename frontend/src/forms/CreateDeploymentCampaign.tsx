/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

import { useCallback, useMemo, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import { Controller, useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

import type {
  CreateDeploymentCampaign_ApplicationOptionsFragment$data,
  CreateDeploymentCampaign_ApplicationOptionsFragment$key,
} from "@/api/__generated__/CreateDeploymentCampaign_ApplicationOptionsFragment.graphql";
import type { CreateDeploymentCampaign_ApplicationPaginationQuery } from "@/api/__generated__/CreateDeploymentCampaign_ApplicationPaginationQuery.graphql";
import type {
  CreateDeploymentCampaign_ChannelOptionsFragment$data,
  CreateDeploymentCampaign_ChannelOptionsFragment$key,
} from "@/api/__generated__/CreateDeploymentCampaign_ChannelOptionsFragment.graphql";
import type { CreateDeploymentCampaign_ChannelPaginationQuery } from "@/api/__generated__/CreateDeploymentCampaign_ChannelPaginationQuery.graphql";
import type {
  CampaignMechanismInput,
  DeploymentConfigSpecInput,
  FileBindSpecInput,
} from "@/api/__generated__/DeploymentCampaignCreate_CreateCampaign_Mutation.graphql";

import Alert from "@/components/ui/alert/Alert";
import Button from "@/components/ui/button/Button";
import Form from "@/components/ui/form/Form";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import { FormRow } from "@/components/ui/form-row/FormRow";
import ReleaseSelectWrapper from "@/components/apps/releases/release-select/ReleaseSelect";
import FileMountInput, {
  FileBindResult,
} from "@/components/apps/containers/file-mount-input/FileMountInput";
import FormFeedback from "@/forms/FormFeedback";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import {
  deploymentCampaignSchema,
  DeploymentCampaignFormData,
} from "@/forms/validation";
import DatePicker from "@/components/ui/date-picker/DatePicker";
import SelectFormField from "@/forms/SelectFormFIeld";

const CAMPAIGN_APPLICATION_OPTIONS_FRAGMENT = graphql`
  fragment CreateDeploymentCampaign_ApplicationOptionsFragment on RootQueryType
  @refetchable(queryName: "CreateDeploymentCampaign_ApplicationPaginationQuery")
  @argumentDefinitions(filter: { type: "ApplicationFilterInput" }) {
    applications(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateDeploymentCampaign_applications") {
      edges {
        node {
          id
          name
          releases(first: 10000) {
            edges {
              node {
                id
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
                            fileMode
                            userId
                            groupId
                            defaultFile {
                              id
                              name
                            }
                            fileMode
                            userId
                            groupId
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

const CAMPAIGN_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment CreateDeploymentCampaign_ChannelOptionsFragment on RootQueryType
  @refetchable(queryName: "CreateDeploymentCampaign_ChannelPaginationQuery")
  @argumentDefinitions(filter: { type: "ChannelFilterInput" }) {
    channels(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateDeploymentCampaign_channels") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type OperationType = "Deploy" | "Start" | "Stop" | "Upgrade" | "Delete";

type DeploymentAction =
  | "deploymentDeploy"
  | "deploymentStart"
  | "deploymentStop"
  | "deploymentUpgrade"
  | "deploymentDelete";

type ApplicationRecord = NonNullable<
  NonNullable<
    CreateDeploymentCampaign_ApplicationOptionsFragment$data["applications"]
  >["edges"]
>[number]["node"];

type ConnectionNode<T> = T extends {
  readonly edges: ReadonlyArray<{ node: infer N }> | null;
}
  ? N
  : never;

type ReleaseRecord = ConnectionNode<ApplicationRecord["releases"]>;

type ContainerRecord = ConnectionNode<ReleaseRecord["containers"]>;

type ContainerFileMountRecord = ConnectionNode<ContainerRecord["fileMounts"]>;

type ChannelRecord = NonNullable<
  NonNullable<
    CreateDeploymentCampaign_ChannelOptionsFragment$data["channels"]
  >["edges"]
>[number]["node"];

type DeploymentCampaignData = {
  channelId: string;
  name: string;
  scheduledAtTimestamp?: string;
  campaignMechanism: CampaignMechanismInput;
};

type DeploymentConfig = {
  releaseId: string;
  targetReleaseId?: string;
  maxFailurePercentage: number;
  maxInProgressOperations: number;
  requestRetries: number;
  requestTimeoutSeconds: number;
  configs?: DeploymentConfigSpecInput[];
};

type SelectOption = {
  value: OperationType;
  label: string;
};

const OPERATION_TO_MECHANISM: Record<OperationType, DeploymentAction> = {
  Deploy: "deploymentDeploy",
  Start: "deploymentStart",
  Stop: "deploymentStop",
  Upgrade: "deploymentUpgrade",
  Delete: "deploymentDelete",
};

const OPERATION_TYPES_WITH_CONFIGS: OperationType[] = ["Deploy", "Upgrade"];

const MECHANISMS_WITH_CONFIGS = OPERATION_TYPES_WITH_CONFIGS.map(
  (operationType) => OPERATION_TO_MECHANISM[operationType],
);

const initialData: DeploymentCampaignFormData = {
  name: "",
  scheduledAtTimestamp: "",
  channel: { id: "", name: "" },
  application: { id: "", name: "" },
  release: { id: "", version: "" },
  operationType: "Deploy",
  maxFailurePercentage: 0,
  maxInProgressOperations: 1,
  requestRetries: 3,
  requestTimeoutSeconds: 300,
};

export const transformOutputData = (
  data: DeploymentCampaignFormData,
  configs: DeploymentConfigSpecInput[] = [],
): DeploymentCampaignData => {
  const {
    name,
    scheduledAtTimestamp,
    channel,
    release,
    targetRelease,
    operationType,
    maxFailurePercentage,
    maxInProgressOperations,
    requestRetries,
    requestTimeoutSeconds,
  } = data;

  const mechanismKey = OPERATION_TO_MECHANISM[operationType as OperationType];

  const deploymentConfig: DeploymentConfig = {
    releaseId: release.id,
    maxFailurePercentage,
    maxInProgressOperations,
    requestRetries,
    requestTimeoutSeconds,
    ...(targetRelease && { targetReleaseId: targetRelease.id }),
    ...(MECHANISMS_WITH_CONFIGS.includes(mechanismKey) &&
      configs.length > 0 && { configs }),
  };

  return {
    name,
    channelId: channel.id,
    ...(scheduledAtTimestamp
      ? {
          scheduledAtTimestamp: new Date(scheduledAtTimestamp).toISOString(),
        }
      : {}),
    campaignMechanism: {
      [mechanismKey]: deploymentConfig,
    },
  };
};

const operationTypesOptions: SelectOption[] = [
  { value: "Deploy", label: "Deploy" },
  { value: "Start", label: "Start" },
  { value: "Stop", label: "Stop" },
  { value: "Upgrade", label: "Upgrade" },
  { value: "Delete", label: "Delete" },
];

const noApplicationOptionsMessage = (
  intl: ReturnType<typeof useIntl>,
  inputValue: string,
) =>
  inputValue
    ? intl.formatMessage(
        {
          id: "forms.CreateDeploymentCampaign.noApplicationsFoundMatching",
          defaultMessage: 'No applications found matching "{inputValue}"',
        },
        { inputValue },
      )
    : intl.formatMessage({
        id: "forms.CreateDeploymentCampaign.noApplicationsAvailable",
        defaultMessage: "No applications available",
      });

const noChannelOptionsMessage = (
  intl: ReturnType<typeof useIntl>,
  inputValue: string,
) =>
  inputValue
    ? intl.formatMessage(
        {
          id: "forms.CreateDeploymentCampaign.noChannelsFoundMatching",
          defaultMessage: 'No channels found matching "{inputValue}"',
        },
        { inputValue },
      )
    : intl.formatMessage({
        id: "forms.CreateDeploymentCampaign.noChannelsAvailable",
        defaultMessage: "No channels available",
      });

type CreateDeploymentCampaignFormProps = {
  campaignOptionsRef: CreateDeploymentCampaign_ApplicationOptionsFragment$key &
    CreateDeploymentCampaign_ChannelOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: DeploymentCampaignData) => void;
};

const CreateDeploymentCampaignForm = ({
  campaignOptionsRef,
  isLoading = false,
  onSubmit,
}: CreateDeploymentCampaignFormProps) => {
  const intl = useIntl();

  const {
    register,
    handleSubmit,
    formState: { errors },
    control,
    resetField,
  } = useForm<DeploymentCampaignFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(deploymentCampaignSchema),
  });

  const [mountBindings, setMountBindings] = useState<
    Record<string, FileBindSpecInput>
  >({});

  const [showMissingBindsFeedback, setShowMissingBindsFeedback] =
    useState(false);

  const selectedApp = useWatch({ control, name: "application" });
  const selectedRelease = useWatch({ control, name: "release" });
  const selectedOperationType = useWatch({ control, name: "operationType" });

  const supportsFileMounts =
    selectedOperationType != null &&
    OPERATION_TYPES_WITH_CONFIGS.includes(selectedOperationType);

  const {
    data: applicationPaginationData,
    loadNext: loadNextApplications,
    hasNext: hasNextApplication,
    isLoadingNext: isLoadingNextApplication,
    refetch: refetchApplications,
  } = usePaginationFragment<
    CreateDeploymentCampaign_ApplicationPaginationQuery,
    CreateDeploymentCampaign_ApplicationOptionsFragment$key
  >(CAMPAIGN_APPLICATION_OPTIONS_FRAGMENT, campaignOptionsRef);

  const [searchApplicationText, setSearchApplicationText] = useState<
    string | null
  >(null);

  const { onLoadMore: onLoadMoreApplicationOptions } =
    useRelayConnectionPagination({
      hasNext: hasNextApplication,
      isLoadingNext: isLoadingNextApplication,
      loadNext: loadNextApplications,
      refetch: refetchApplications,
      searchText: searchApplicationText,
      buildFilter: (text) => {
        if (text === "") {
          return undefined;
        }

        return {
          name: {
            ilike: `%${text}%`,
          },
        };
      },
    });

  const applicationOptions = useMemo(() => {
    return (
      applicationPaginationData.applications?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is ApplicationRecord => node != null) ?? []
    );
  }, [applicationPaginationData]);

  const {
    data: channelPaginationData,
    loadNext: loadNextChannels,
    hasNext: hasNextChannel,
    isLoadingNext: isLoadingNextChannel,
    refetch: refetchChannels,
  } = usePaginationFragment<
    CreateDeploymentCampaign_ChannelPaginationQuery,
    CreateDeploymentCampaign_ChannelOptionsFragment$key
  >(CAMPAIGN_CHANNEL_OPTIONS_FRAGMENT, campaignOptionsRef);

  const [searchChannelText, setSearchChannelText] = useState<string | null>(
    null,
  );

  const { onLoadMore: onLoadMoreChannelOptions } = useRelayConnectionPagination(
    {
      hasNext: hasNextChannel,
      isLoadingNext: isLoadingNextChannel,
      loadNext: loadNextChannels,
      refetch: refetchChannels,
      searchText: searchChannelText,
      buildFilter: (text) => {
        if (text === "") {
          return undefined;
        }

        return {
          name: {
            ilike: `%${text}%`,
          },
        };
      },
    },
  );

  const channels = useMemo(() => {
    return (
      channelPaginationData.channels?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is ChannelRecord => node != null) ?? []
    );
  }, [channelPaginationData]);

  const releaseContainers = useMemo<ContainerRecord[]>(() => {
    if (!selectedApp?.id || !selectedRelease?.id) {
      return [];
    }

    const application = applicationOptions.find(
      (candidate) => candidate.id === selectedApp.id,
    );

    const release = application?.releases?.edges
      ?.map((edge) => edge?.node)
      .find((node) => node?.id === selectedRelease.id);

    return (
      release?.containers?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is ContainerRecord => node != null) ?? []
    );
  }, [applicationOptions, selectedApp, selectedRelease]);

  const containersWithMounts = useMemo(() => {
    if (!supportsFileMounts) {
      return [];
    }

    return releaseContainers
      .map((container) => ({
        id: container.id,
        name: container.name,
        mounts:
          container.fileMounts?.edges
            ?.map((edge) => edge?.node)
            .filter((node): node is ContainerFileMountRecord => node != null) ??
          [],
      }))
      .filter((container) => container.mounts.length > 0);
  }, [releaseContainers, supportsFileMounts]);

  // A default file already satisfies a required mount, exactly like it does
  // server-side, so it never counts as missing.
  const isRequiredMountMissing = useCallback(
    (mount: ContainerFileMountRecord) =>
      mount.required &&
      !mount.defaultFileId &&
      !mount.defaultFile?.name &&
      mountBindings[mount.id]?.fileId == null,
    [mountBindings],
  );

  const missingRequiredMounts = useMemo(() => {
    return containersWithMounts.flatMap((container) =>
      container.mounts.filter(isRequiredMountMissing).map((mount) => ({
        id: mount.id,
        mountpoint: mount.mountpoint,
        containerName: container.name,
      })),
    );
  }, [containersWithMounts, isRequiredMountMissing]);

  const handleFileBindChange = useCallback(
    (mountId: string, result: FileBindResult | null) => {
      setMountBindings((prev) => {
        const existing = prev[mountId];

        if (result?.spec?.fileId == null) {
          if (!(mountId in prev)) {
            return prev;
          }

          const next = { ...prev };
          delete next[mountId];

          return next;
        }

        if (
          existing?.fileId === result.spec.fileId &&
          existing?.fileMode === result.spec.fileMode &&
          existing?.userId === result.spec.userId &&
          existing?.groupId === result.spec.groupId
        ) {
          return prev;
        }

        return { ...prev, [mountId]: result.spec };
      });
    },
    [],
  );

  const resetMountBindings = useCallback(() => {
    setMountBindings({});
  }, []);

  const onFormSubmit = (data: DeploymentCampaignFormData) => {
    // The submit button is disabled while required mounts are unconfigured, but
    // a disabled button does not stop react-hook-form from submitting on Enter.
    // Guard here as well so the form can never be submitted incomplete.
    if (missingRequiredMounts.length > 0) {
      setShowMissingBindsFeedback(true);
      return;
    }

    const configs: DeploymentConfigSpecInput[] = containersWithMounts
      .map<DeploymentConfigSpecInput | null>((container) => {
        const fileBinds = container.mounts
          .map((mount) => mountBindings[mount.id])
          .filter((bind): bind is FileBindSpecInput => !!bind?.fileId);

        if (fileBinds.length === 0) {
          return null;
        }

        return {
          containerId: container.id,
          fileBinds,
        };
      })
      .filter((config): config is DeploymentConfigSpecInput => !!config);

    onSubmit(transformOutputData(data, configs));
  };

  return (
    <form
      onSubmit={handleSubmit(onFormSubmit)}
      data-testid="create-deployment-campaign-form"
    >
      <Stack gap={3}>
        <FormRow
          id="create-deployment-campaign-form-operation-type"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.operationTypeLabel"
              defaultMessage="Operation type"
            />
          }
        >
          <SelectFormField
            control={control}
            name="operationType"
            options={operationTypesOptions}
            placeholder={intl.formatMessage({
              id: "forms.CreateDeploymentCampaign.operationTypeOption",
              defaultMessage: "Select an operation type...",
            })}
            noOptionsMessage={() =>
              intl.formatMessage({
                id: "forms.CreateDeploymentCampaign.noOperationTypesAvailable",
                defaultMessage: "No operation types available",
              })
            }
          />
          <FormFeedback feedback={errors.operationType?.message} />
        </FormRow>

        <FormRow
          id="create-deployment-campaign-form-name"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>

        <FormRow
          id="create-deployment-campaign-form-application"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.applicationLabel"
              defaultMessage="Application"
            />
          }
        >
          <SelectFormField
            control={control}
            name="application"
            valueType="object"
            options={applicationOptions.map((application) => ({
              value: application.id,
              label: application.name,
            }))}
            placeholder={intl.formatMessage({
              id: "forms.CreateDeploymentCampaign.applicationOption",
              defaultMessage: "Search or select an application...",
            })}
            isLoading={isLoadingNextApplication}
            onMenuScrollToBottom={onLoadMoreApplicationOptions}
            onInputChange={setSearchApplicationText}
            noOptionsMessage={({ inputValue }) =>
              noApplicationOptionsMessage(intl, inputValue)
            }
            onChange={() => {
              resetField("release");
              resetMountBindings();
            }}
          />
          <FormFeedback feedback={errors.application?.id?.message} />
        </FormRow>

        <FormRow
          id="create-deployment-campaign-form-release"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.releaseLabel"
              defaultMessage="Release"
            />
          }
        >
          {selectedApp?.id ? (
            <>
              <Controller
                name="release"
                control={control}
                render={({
                  field: { value, onChange },
                  fieldState: { invalid },
                }) => (
                  <ReleaseSelectWrapper
                    selectedApp={selectedApp}
                    controllerProps={{
                      value: value,
                      invalid: invalid,
                      onChange: (release) => {
                        resetMountBindings();
                        onChange(release);
                      },
                    }}
                  />
                )}
              />
              <FormFeedback feedback={errors.release?.id?.message} />
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.selectApplication"
                defaultMessage="Select an application..."
              />
            </div>
          )}
        </FormRow>

        {selectedOperationType === "Upgrade" && (
          <FormRow
            id="create-deployment-campaign-form-target-release"
            label={
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.targetReleaseLabel"
                defaultMessage="Target Release"
              />
            }
          >
            {selectedApp?.id && selectedRelease?.id ? (
              <>
                <Controller
                  name="targetRelease"
                  control={control}
                  render={({
                    field: { value, onChange },
                    fieldState: { invalid },
                  }) => (
                    <ReleaseSelectWrapper
                      isTarget={true}
                      selectedApp={selectedApp}
                      selectedRelease={selectedRelease}
                      controllerProps={{
                        value: value,
                        invalid: invalid,
                        onChange: onChange,
                      }}
                    />
                  )}
                />
                <FormFeedback feedback={errors.targetRelease?.id?.message} />
              </>
            ) : (
              <div className="d-flex align-content-center fst-italic text-muted">
                <FormattedMessage
                  id="forms.CreateDeploymentCampaign.selectApplicationAndRelease"
                  defaultMessage="Select an application and a release..."
                />
              </div>
            )}
          </FormRow>
        )}

        {supportsFileMounts && containersWithMounts.length > 0 && (
          <div
            className="mt-2 pt-2 border-top"
            data-testid="deployment-campaign-file-mounts"
          >
            <h6 className="mb-2 fw-semibold">
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.fileBindsTitle"
                defaultMessage="File Mounts Configuration"
              />
            </h6>

            <p className="mb-2 small text-muted">
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.fileBindsDescription"
                defaultMessage="Select the repository file to mount at each mountpoint. The file is sent to every device targeted by the channel."
              />
            </p>

            <Alert
              show={
                showMissingBindsFeedback && missingRequiredMounts.length > 0
              }
              variant="danger"
              data-testid="missing-required-binds-feedback"
            >
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.missingRequiredBindsFeedback"
                defaultMessage="Please configure a file source for all required file mounts."
              />
              <ul className="mb-0 mt-1">
                {missingRequiredMounts.map((mount) => (
                  <li key={mount.id}>
                    {intl.formatMessage(
                      {
                        id: "forms.CreateDeploymentCampaign.containerLabel",
                        defaultMessage: "Container: {containerName}",
                      },
                      { containerName: mount.containerName },
                    )}{" "}
                    — {mount.mountpoint}
                  </li>
                ))}
              </ul>
            </Alert>

            <div className="d-flex flex-column gap-3 pe-1 pb-2">
              {containersWithMounts.map((container) => (
                <div
                  key={container.id}
                  className="border rounded p-3 bg-light"
                  data-testid={`container-mounts-${container.id}`}
                >
                  <div className="fw-bold mb-2 small text-secondary">
                    <FormattedMessage
                      id="forms.CreateDeploymentCampaign.containerLabel"
                      defaultMessage="Container: {containerName}"
                      values={{ containerName: container.name }}
                    />
                  </div>

                  <div className="d-flex flex-column gap-2">
                    {container.mounts.map((mount) => (
                      <FileMountInput
                        key={mount.id}
                        fileMountId={mount.id}
                        mountpoint={mount.mountpoint}
                        required={mount.required}
                        defaultFileId={mount.defaultFileId}
                        defaultFileName={mount.defaultFile?.name}
                        defaultFileMode={mount.fileMode}
                        defaultUserId={mount.userId}
                        defaultGroupId={mount.groupId}
                        onChange={(result) =>
                          handleFileBindChange(mount.id, result)
                        }
                      />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        <FormRow
          id="create-deployment-campaign-form-channel"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.channelLabel"
              defaultMessage="Channel"
            />
          }
        >
          <SelectFormField
            control={control}
            name="channel"
            valueType="object"
            options={channels.map((channel) => ({
              value: channel.id,
              label: channel.name,
            }))}
            isLoading={isLoadingNextChannel}
            onMenuScrollToBottom={onLoadMoreChannelOptions}
            onInputChange={setSearchChannelText}
            placeholder={intl.formatMessage({
              id: "forms.CreateDeploymentCampaign.channelOption",
              defaultMessage: "Search or select a channel...",
            })}
            noOptionsMessage={({ inputValue }) =>
              noChannelOptionsMessage(intl, inputValue)
            }
          />
          <FormFeedback feedback={errors.channel?.id?.message} />
        </FormRow>

        <FormRow
          id="create-deployment-campaign-form-max-in-progress-updates"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.maxInProgressOperationsLabel"
              defaultMessage="Max Pending Operations"
            />
          }
        >
          <Form.Control
            {...register("maxInProgressOperations", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            type="text"
            isInvalid={!!errors.maxInProgressOperations}
          />
          <FormFeedback feedback={errors.maxInProgressOperations?.message} />
        </FormRow>

        <FormRow
          id="create-deployment-campaign-form-max-failure-percentage"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.maxFailurePercentageLabel"
              defaultMessage="Max Failures <muted>(%)</muted>"
              values={{
                muted: (chunks: React.ReactNode) => (
                  <span className="small text-muted">{chunks}</span>
                ),
              }}
            />
          }
        >
          <Form.Control
            {...register("maxFailurePercentage", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            type="text"
            isInvalid={!!errors.maxFailurePercentage}
          />
          <FormFeedback feedback={errors.maxFailurePercentage?.message} />
        </FormRow>
        <FormRow
          id="create-deployment-campaign-form-ota-request-timeout"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.requestTimeoutSecondsLabel"
              defaultMessage="Request Timeout <muted>(seconds)</muted>"
              values={{
                muted: (chunks: React.ReactNode) => (
                  <span className="small text-muted">{chunks}</span>
                ),
              }}
            />
          }
        >
          <Form.Control
            {...register("requestTimeoutSeconds", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            type="text"
            isInvalid={!!errors.requestTimeoutSeconds}
          />
          <FormFeedback feedback={errors.requestTimeoutSeconds?.message} />
        </FormRow>
        <FormRow
          id="create-deployment-campaign-form-ota-request-retries"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.requestRetriesLabel"
              defaultMessage="Request Retries"
            />
          }
        >
          <Form.Control
            {...register("requestRetries", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            type="text"
            isInvalid={!!errors.requestRetries}
          />
          <FormFeedback feedback={errors.requestRetries?.message} />
        </FormRow>

        <FormRow
          id="create-deployment-campaign-form-scheduled-at-timestamp"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.scheduledAtTimestampLabel"
              defaultMessage="Scheduled At"
            />
          }
        >
          <Controller
            name="scheduledAtTimestamp"
            control={control}
            render={({ field: { value, onChange } }) => (
              <DatePicker
                selected={value ? new Date(value) : null}
                onChange={(date: Date | null) =>
                  onChange(date ? date.toISOString() : "")
                }
                minDate={new Date()}
              />
            )}
          />
          {errors.scheduledAtTimestamp ? (
            <FormFeedback feedback={errors.scheduledAtTimestamp.message} />
          ) : (
            <Form.Text muted>
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.scheduledAtTimestampLabelHint"
                defaultMessage="Optional. If set, the campaign will be scheduled to start at the specified date and time. Otherwise, it will start immediately."
              />
            </Form.Text>
          )}
        </FormRow>

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            {selectedOperationType ? (
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.submitWithType"
                defaultMessage="Create {type} campaign"
                values={{ type: selectedOperationType.toLowerCase() }}
              />
            ) : (
              <FormattedMessage
                id="forms.CreateDeploymentCampaign.submitButton"
                defaultMessage="Create"
              />
            )}
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type {
  ApplicationRecord,
  DeploymentCampaignData,
  OperationType,
  DeploymentAction,
};

export default CreateDeploymentCampaignForm;
