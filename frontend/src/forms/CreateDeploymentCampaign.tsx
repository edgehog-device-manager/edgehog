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

import _ from "lodash";
import { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import { Controller, useForm } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";
import Select from "react-select";

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
import type { CampaignMechanismInput } from "@/api/__generated__/DeploymentCampaignCreate_CreateCampaign_Mutation.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";
import ReleaseSelectWrapper, {
  ReleaseRecord,
} from "@/components/ReleaseSelect";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { numberSchema, yup } from "@/forms";
import FormFeedback from "@/forms/FormFeedback";

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

type ChannelRecord = NonNullable<
  NonNullable<
    CreateDeploymentCampaign_ChannelOptionsFragment$data["channels"]
  >["edges"]
>[number]["node"];

type DeploymentCampaignData = {
  channelId: string;
  name: string;
  campaignMechanism: CampaignMechanismInput;
};

type FormData = {
  name: string;
  channel: ChannelRecord;
  application: ApplicationRecord;
  release: ReleaseRecord;
  targetRelease?: ReleaseRecord;
  operationType: OperationType | "";
  maxFailurePercentage: number | string;
  maxInProgressOperations: number | string;
  requestRetries: number;
  requestTimeoutSeconds: number;
};

type DeploymentConfig = {
  releaseId: string;
  targetReleaseId?: string;
  maxFailurePercentage: number;
  maxInProgressOperations: number;
  requestRetries: number;
  requestTimeoutSeconds: number;
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

const initialData: FormData = {
  name: "",
  channel: { id: "", name: "" },
  application: { id: "", name: "" },
  release: { id: "", version: "" },
  operationType: "",
  maxFailurePercentage: "",
  maxInProgressOperations: "",
  requestRetries: 3,
  requestTimeoutSeconds: 300,
};

const campaignSchema = (intl: ReturnType<typeof useIntl>) =>
  yup
    .object({
      name: yup.string().required(),
      application: yup
        .object({ id: yup.string().required(), name: yup.string().required() })
        .required(),
      release: yup
        .object({
          id: yup.string().required(),
          version: yup.string().required(),
        })
        .required(),
      targetRelease: yup
        .object({
          id: yup.string().required(),
          version: yup.string().required(),
        })
        .default(undefined)
        .when("operationType", ([operationType], schema) => {
          return operationType === "UPGRADE"
            ? schema.required()
            : schema.notRequired();
        }),
      channel: yup
        .object({ id: yup.string().required(), name: yup.string().required() })
        .required(),
      operationType: yup.string().required(),
      maxInProgressOperations: numberSchema
        .integer()
        .positive()
        .label(
          intl.formatMessage({
            id: "forms.CreateDeploymentCampaign.maxInProgressOperationsLabel",
            defaultMessage: "Max Pending Operations",
          }),
        ),
      maxFailurePercentage: numberSchema
        .min(0)
        .max(100)
        .label(
          intl.formatMessage({
            id: "forms.CreateDeploymentCampaign.maxFailurePercentageValidationLabel",
            defaultMessage: "Max Failures",
          }),
        ),
      requestTimeoutSeconds: numberSchema
        .positive()
        .integer()
        .min(30)
        .label(
          intl.formatMessage({
            id: "forms.CreateDeploymentCampaign.requestTimeoutSecondsValidationLabel",
            defaultMessage: "Request Timeout",
          }),
        ),
      requestRetries: numberSchema
        .integer()
        .min(0)
        .label(
          intl.formatMessage({
            id: "forms.CreateDeploymentCampaign.requestRetriesLabel",
            defaultMessage: "Request Retries",
          }),
        ),
    })
    .required();

const transformOutputData = (data: FormData): DeploymentCampaignData => {
  const {
    name,
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
    maxFailurePercentage:
      typeof maxFailurePercentage === "string"
        ? parseFloat(maxFailurePercentage)
        : maxFailurePercentage,
    maxInProgressOperations:
      typeof maxInProgressOperations === "string"
        ? parseInt(maxInProgressOperations)
        : maxInProgressOperations,
    requestRetries,
    requestTimeoutSeconds,
    ...(targetRelease && { targetReleaseId: targetRelease.id }),
  };

  return {
    name,
    channelId: channel.id,
    campaignMechanism: {
      [mechanismKey]: deploymentConfig,
    },
  };
};

type Props = {
  campaignOptionsRef: CreateDeploymentCampaign_ApplicationOptionsFragment$key &
    CreateDeploymentCampaign_ChannelOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: DeploymentCampaignData) => void;
};

const CreateDeploymentCampaignForm = ({
  campaignOptionsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();

  const {
    register,
    handleSubmit,
    formState: { errors },
    watch,
    control,
    resetField,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(campaignSchema(intl)),
  });

  const onFormSubmit = (data: FormData) => {
    onSubmit(transformOutputData(data));
  };

  const selectedApp = watch("application");
  const selectedRelease = watch("release");
  const selectedOperationType = watch("operationType");

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

  const debounceApplicationRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetchApplications(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetchApplications(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetchApplications],
  );

  useEffect(() => {
    if (searchApplicationText !== null) {
      debounceApplicationRefetch(searchApplicationText);
    }
  }, [debounceApplicationRefetch, searchApplicationText]);

  const loadNextApplicationOptions = useCallback(() => {
    if (hasNextApplication && !isLoadingNextApplication) {
      loadNextApplications(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNextApplication, isLoadingNextApplication, loadNextApplications]);

  const applicationOptions = useMemo(() => {
    return (
      applicationPaginationData.applications?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is ApplicationRecord => node != null) ?? []
    );
  }, [applicationPaginationData]);

  const getApplicationLabel = (application: ApplicationRecord) =>
    application.name;
  const getApplicationValue = (application: ApplicationRecord) =>
    application.id;
  const noApplicationOptionsMessage = (inputValue: string) =>
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

  const { onChange: onApplicationChange } = register("application");

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

  const debounceChannelRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetchChannels(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetchChannels(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetchChannels],
  );

  useEffect(() => {
    if (searchChannelText !== null) {
      debounceChannelRefetch(searchChannelText);
    }
  }, [debounceChannelRefetch, searchChannelText]);

  const loadNextChannelOptions = useCallback(() => {
    if (hasNextChannel && !isLoadingNextChannel) {
      loadNextChannels(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNextChannel, isLoadingNextChannel, loadNextChannels]);

  const channels = useMemo(() => {
    return (
      channelPaginationData.channels?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is ChannelRecord => node != null) ?? []
    );
  }, [channelPaginationData]);

  const getChannelLabel = (channel: ChannelRecord) => channel.name;
  const getChannelValue = (channel: ChannelRecord) => channel.id;
  const noChannelOptionsMessage = (inputValue: string) =>
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

  const operationTypesOptions: SelectOption[] = [
    { value: "Deploy", label: "Deploy" },
    { value: "Start", label: "Start" },
    { value: "Stop", label: "Stop" },
    { value: "Upgrade", label: "Upgrade" },
    { value: "Delete", label: "Delete" },
  ];

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
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
          <Controller
            name="operationType"
            control={control}
            render={({ field }) => (
              <>
                <Select
                  {...field}
                  value={
                    operationTypesOptions.find(
                      (opt) => opt.value === field.value,
                    ) || null
                  }
                  onChange={(option) => field.onChange(option?.value || "")}
                  options={operationTypesOptions}
                  isClearable
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
                  className={errors.operationType && "is-invalid"}
                />

                <FormFeedback feedback={errors.operationType?.message} />
              </>
            )}
          />
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
          <Controller
            name="application"
            control={control}
            render={({
              field: { value, onChange },
              fieldState: { invalid },
            }) => (
              <Select
                value={value}
                onChange={(e) => {
                  onChange(e);
                  onApplicationChange({ target: e });
                  resetField("release");
                }}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "forms.CreateDeploymentCampaign.applicationOption",
                  defaultMessage: "Search or select an application...",
                })}
                options={applicationOptions}
                getOptionLabel={getApplicationLabel}
                getOptionValue={getApplicationValue}
                noOptionsMessage={({ inputValue }) =>
                  noApplicationOptionsMessage(inputValue)
                }
                isLoading={isLoadingNextApplication}
                onMenuScrollToBottom={
                  hasNextApplication ? loadNextApplicationOptions : undefined
                }
                onInputChange={(text) => setSearchApplicationText(text)}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.application && (
              <FormattedMessage id={errors.application?.id?.message} />
            )}
          </Form.Control.Feedback>
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
                      onChange: onChange,
                    }}
                  />
                )}
              />
              <Form.Control.Feedback type="invalid">
                {errors.release && (
                  <FormattedMessage id={errors.release?.id?.message} />
                )}
              </Form.Control.Feedback>
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
                <Form.Control.Feedback type="invalid">
                  {errors.release && (
                    <FormattedMessage id={errors.targetRelease?.id?.message} />
                  )}
                </Form.Control.Feedback>
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

        <FormRow
          id="create-deployment-campaign-form-channel"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.channelLabel"
              defaultMessage="Channel"
            />
          }
        >
          <Controller
            name="channel"
            control={control}
            render={({
              field: { value, onChange },
              fieldState: { invalid },
            }) => (
              <Select
                value={value}
                onChange={onChange}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "forms.CreateDeploymentCampaign.channelOption",
                  defaultMessage: "Search or select a channel...",
                })}
                options={channels}
                getOptionLabel={getChannelLabel}
                getOptionValue={getChannelValue}
                noOptionsMessage={({ inputValue }) =>
                  noChannelOptionsMessage(inputValue)
                }
                isLoading={isLoadingNextChannel}
                onMenuScrollToBottom={
                  hasNextChannel ? loadNextChannelOptions : undefined
                }
                onInputChange={(text) => setSearchChannelText(text)}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.channel && (
              <FormattedMessage id={errors.channel?.id?.message} />
            )}
          </Form.Control.Feedback>
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
            {...register("maxInProgressOperations")}
            type="number"
            min="1"
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
            {...register("maxFailurePercentage")}
            type="number"
            min="0"
            max="100"
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
            {...register("requestTimeoutSeconds")}
            type="number"
            min="30"
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
            {...register("requestRetries")}
            type="number"
            min="0"
            isInvalid={!!errors.requestRetries}
          />
          <FormFeedback feedback={errors.requestRetries?.message} />
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
