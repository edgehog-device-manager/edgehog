/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { zodResolver } from "@hookform/resolvers/zod";
import _ from "lodash";
import type { ReactNode } from "react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import Select from "react-select";
import type { z } from "zod";

import type {
  CreateFileDownloadCampaign_ChannelOptionsFragment$data,
  CreateFileDownloadCampaign_ChannelOptionsFragment$key,
} from "@/api/__generated__/CreateFileDownloadCampaign_ChannelOptionsFragment.graphql";
import type { CreateFileDownloadCampaign_ChannelPaginationQuery } from "@/api/__generated__/CreateFileDownloadCampaign_ChannelPaginationQuery.graphql";
import type {
  CreateFileDownloadCampaign_RepositoryOptionsFragment$data,
  CreateFileDownloadCampaign_RepositoryOptionsFragment$key,
} from "@/api/__generated__/CreateFileDownloadCampaign_RepositoryOptionsFragment.graphql";
import type { CreateFileDownloadCampaign_RepositoryPaginationQuery } from "@/api/__generated__/CreateFileDownloadCampaign_RepositoryPaginationQuery.graphql";

import Button from "@/components/Button";
import CollapseItem, { useCollapseToggle } from "@/components/CollapseItem";
import FileSelect from "@/components/FileSelect";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import FormFeedback from "@/forms/FormFeedback";
import {
  FileDownloadCampaignFormData,
  fileDownloadCampaignSchema,
} from "@/forms/validation";

const CAMPAIGN_REPOSITORY_OPTIONS_FRAGMENT = graphql`
  fragment CreateFileDownloadCampaign_RepositoryOptionsFragment on RootQueryType
  @refetchable(
    queryName: "CreateFileDownloadCampaign_RepositoryPaginationQuery"
  )
  @argumentDefinitions(filter: { type: "RepositoryFilterInput" }) {
    repositories(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateFileDownloadCampaign_repositories") {
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
  fragment CreateFileDownloadCampaign_ChannelOptionsFragment on RootQueryType
  @refetchable(queryName: "CreateFileDownloadCampaign_ChannelPaginationQuery")
  @argumentDefinitions(filter: { type: "ChannelFilterInput" }) {
    channels(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateFileDownloadCampaign_channels") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type FileDestination = "STORAGE" | "STREAMING" | "FILESYSTEM";

type RepositoryRecord = NonNullable<
  NonNullable<
    CreateFileDownloadCampaign_RepositoryOptionsFragment$data["repositories"]
  >["edges"]
>[number]["node"];

type ChannelRecord = NonNullable<
  NonNullable<
    CreateFileDownloadCampaign_ChannelOptionsFragment$data["channels"]
  >["edges"]
>[number]["node"];

type FileDownloadCampaignOutputData = {
  channelId: string;
  name: string;
  campaignMechanism: {
    fileDownload: {
      fileId: string;
      maxFailurePercentage: number;
      maxInProgressOperations: number;
      requestRetries: number;
      requestTimeoutSeconds: number;
      destinationType: FileDestination;
      destination: string | null;
      compression: string;
      ttlSeconds: number;
      fileMode?: number;
      userId?: number;
      groupId?: number;
    };
  };
};

const initialData: FileDownloadCampaignFormData = {
  name: "",
  channel: { id: "", name: "" },
  repository: { id: "", name: "" },
  file: { id: "", name: "" },
  maxFailurePercentage: 0,
  maxInProgressOperations: 1,
  requestRetries: 3,
  requestTimeoutSeconds: 300,
  destinationType: "STORAGE",
  destination: null,
  ttlSeconds: 0,
  fileMode: undefined,
  userId: undefined,
  groupId: undefined,
};

const destinationOptions = [
  { value: "STORAGE", label: "Storage" },
  { value: "STREAMING", label: "Streaming" },
  { value: "FILESYSTEM", label: "File System" },
] as const;

const transformOutputData = (
  data: FileDownloadCampaignFormData,
): FileDownloadCampaignOutputData => {
  const {
    name,
    channel,
    file,
    maxFailurePercentage,
    maxInProgressOperations,
    requestRetries,
    requestTimeoutSeconds,
    destinationType,
    destination,
    ttlSeconds,
    fileMode,
    userId,
    groupId,
  } = data;

  let compression = "";
  if (/\.(tar\.gz|tgz)$/i.test(file.name)) {
    compression = "tar.gz";
  }

  return {
    name,
    channelId: channel.id,
    campaignMechanism: {
      fileDownload: {
        fileId: file.id,
        maxFailurePercentage,
        maxInProgressOperations,
        requestRetries,
        requestTimeoutSeconds,
        destinationType,
        destination,
        compression,
        ttlSeconds,
        fileMode,
        userId,
        groupId,
      },
    },
  };
};

type FileDownloadCampaignFormInputData = z.input<
  typeof fileDownloadCampaignSchema
>;

type CreateFileDownloadCampaignFormProps = {
  campaignOptionsRef: CreateFileDownloadCampaign_RepositoryOptionsFragment$key &
    CreateFileDownloadCampaign_ChannelOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: FileDownloadCampaignOutputData) => void;
};

const CreateFileDownloadCampaignForm = ({
  campaignOptionsRef,
  isLoading = false,
  onSubmit,
}: CreateFileDownloadCampaignFormProps) => {
  const intl = useIntl();

  const { open: advancedOptionsOpen, toggle: toggleAdvancedOptions } =
    useCollapseToggle();

  const {
    register,
    handleSubmit,
    formState: { errors },
    control,
    resetField,
  } = useForm<
    FileDownloadCampaignFormInputData,
    unknown,
    FileDownloadCampaignFormData
  >({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(fileDownloadCampaignSchema),
  });

  const onFormSubmit = (data: FileDownloadCampaignFormData) => {
    onSubmit(transformOutputData(data));
  };

  const selectedRepository = useWatch({
    control,
    name: "repository",
  });

  const selectedDestinationType = useWatch({
    control,
    name: "destinationType",
  });

  const {
    data: repositoryPaginationData,
    loadNext: loadNextRepositories,
    hasNext: hasNextRepository,
    isLoadingNext: isLoadingNextRepository,
    refetch: refetchRepositories,
  } = usePaginationFragment<
    CreateFileDownloadCampaign_RepositoryPaginationQuery,
    CreateFileDownloadCampaign_RepositoryOptionsFragment$key
  >(CAMPAIGN_REPOSITORY_OPTIONS_FRAGMENT, campaignOptionsRef);

  const [searchRepositoryText, setSearchRepositoryText] = useState<
    string | null
  >(null);

  const debounceRepositoryRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetchRepositories(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetchRepositories(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetchRepositories],
  );

  useEffect(() => {
    if (searchRepositoryText !== null) {
      debounceRepositoryRefetch(searchRepositoryText);
    }
  }, [debounceRepositoryRefetch, searchRepositoryText]);

  const loadNextRepositoryOptions = useCallback(() => {
    if (hasNextRepository && !isLoadingNextRepository) {
      loadNextRepositories(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNextRepository, isLoadingNextRepository, loadNextRepositories]);

  const repositories = useMemo(() => {
    return (
      repositoryPaginationData.repositories?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is RepositoryRecord => node != null) ?? []
    );
  }, [repositoryPaginationData]);

  const noRepositoryOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.CreateFileDownloadCampaign.noRepositoriesFoundMatching",
            defaultMessage: 'No repositories found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.CreateFileDownloadCampaign.noRepositoriesAvailable",
          defaultMessage: "No repositories available",
        });

  const { onChange: onRepositoryChange } = register("repository");
  const { onChange: onFileChange } = register("file");

  const {
    data: channelPaginationData,
    loadNext: loadNextChannels,
    hasNext: hasNextChannel,
    isLoadingNext: isLoadingNextChannel,
    refetch: refetchChannels,
  } = usePaginationFragment<
    CreateFileDownloadCampaign_ChannelPaginationQuery,
    CreateFileDownloadCampaign_ChannelOptionsFragment$key
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

  const noChannelOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.CreateFileDownloadCampaign.noChannelsFoundMatching",
            defaultMessage: 'No channels found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.CreateFileDownloadCampaign.noChannelsAvailable",
          defaultMessage: "No channels available",
        });

  const { onChange: onChannelChange } = register("channel");

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="name"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.nameLabel"
              defaultMessage="Campaign Name"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("name")}
            isInvalid={!!errors.name}
          />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>

        <FormRow
          id="repository"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.repositoryLabel"
              defaultMessage="Repository"
            />
          }
        >
          <Controller
            name="repository"
            control={control}
            render={({
              field: { value, onChange },
              fieldState: { invalid },
            }) => (
              <Select
                value={value}
                onChange={(e) => {
                  onChange(e);
                  onRepositoryChange({ target: e });
                  resetField("file");
                }}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "forms.CreateFileDownloadCampaign.repositoryOption",
                  defaultMessage: "Search or select a repository...",
                })}
                options={repositories}
                getOptionLabel={(opt) => opt.name}
                getOptionValue={(opt) => opt.id}
                noOptionsMessage={({ inputValue }) =>
                  noRepositoryOptionsMessage(inputValue)
                }
                isLoading={isLoadingNextRepository}
                onMenuScrollToBottom={
                  hasNextRepository ? loadNextRepositoryOptions : undefined
                }
                onInputChange={(text) => setSearchRepositoryText(text)}
              />
            )}
          />
          <FormFeedback feedback={errors.repository?.id?.message} />
        </FormRow>

        <FormRow
          id="file"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.fileLabel"
              defaultMessage="File"
            />
          }
        >
          {selectedRepository?.id ? (
            <>
              <Controller
                name="file"
                control={control}
                render={({
                  field: { value, onChange },
                  fieldState: { invalid },
                }) => (
                  <FileSelect
                    selectedRepository={selectedRepository}
                    controllerProps={{
                      value,
                      invalid,
                      onChange: (e) => {
                        onChange(e);
                        onFileChange({ target: e });
                      },
                    }}
                  />
                )}
              />
              <FormFeedback feedback={errors.file?.id?.message} />
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.CreateFileDownloadCampaign.selectRepositoryHint"
                defaultMessage="Select a repository before selecting a file..."
              />
            </div>
          )}
        </FormRow>

        <FormRow
          id="channel"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.channelLabel"
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
                onChange={(e) => {
                  onChange(e);
                  onChannelChange({ target: e });
                }}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "forms.CreateFileDownloadCampaign.channelOption",
                  defaultMessage: "Search or select a channel...",
                })}
                options={channels}
                getOptionLabel={(opt) => opt.name}
                getOptionValue={(opt) => opt.id}
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
          <FormFeedback feedback={errors.channel?.id?.message} />
        </FormRow>

        <FormRow
          id="destinationType"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.destinationLabel"
              defaultMessage="Destination"
            />
          }
        >
          <Controller
            control={control}
            name="destinationType"
            render={({ field }) => {
              const selectedOption =
                destinationOptions.find((opt) => opt.value === field.value) ||
                null;

              return (
                <Select
                  value={selectedOption}
                  onChange={(option) => {
                    field.onChange(option ? option.value : null);
                  }}
                  options={destinationOptions}
                />
              );
            }}
          />
        </FormRow>

        {selectedDestinationType === "FILESYSTEM" && (
          <FormRow
            id="destination"
            label={
              <FormattedMessage
                id="forms.CreateFileDownloadCampaign.destinationPathLabel"
                defaultMessage="Destination Path"
              />
            }
          >
            <Form.Control
              type="text"
              {...register("destination")}
              isInvalid={!!errors.destination}
            />
            <FormFeedback feedback={errors.destination?.message} />
          </FormRow>
        )}

        <FormRow
          id="maxInProgressOperations"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.maxInProgressOperationsLabel"
              defaultMessage="Max Pending Operations"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("maxInProgressOperations", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.maxInProgressOperations}
          />
          <FormFeedback feedback={errors.maxInProgressOperations?.message} />
        </FormRow>

        <FormRow
          id="maxFailurePercentage"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.maxFailurePercentageLabel"
              defaultMessage="Max Failures <muted>(%)</muted>"
              values={{
                muted: (chunks: ReactNode) => (
                  <span className="small text-muted">{chunks}</span>
                ),
              }}
            />
          }
        >
          <Form.Control
            type="text"
            {...register("maxFailurePercentage", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.maxFailurePercentage}
          />
          <FormFeedback feedback={errors.maxFailurePercentage?.message} />
        </FormRow>

        <FormRow
          id="requestTimeoutSeconds"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.requestTimeoutSecondsLabel"
              defaultMessage="Request Timeout <muted>(seconds)</muted>"
              values={{
                muted: (chunks: ReactNode) => (
                  <span className="small text-muted">{chunks}</span>
                ),
              }}
            />
          }
        >
          <Form.Control
            type="text"
            {...register("requestTimeoutSeconds", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.requestTimeoutSeconds}
          />
          <FormFeedback feedback={errors.requestTimeoutSeconds?.message} />
        </FormRow>

        <FormRow
          id="requestRetries"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.requestRetriesLabel"
              defaultMessage="Request Retries"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("requestRetries", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.requestRetries}
          />
          <FormFeedback feedback={errors.requestRetries?.message} />
        </FormRow>

        <FormRow
          id="ttlSeconds"
          label={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.ttlLabel"
              defaultMessage="TTL <muted>(seconds)</muted>"
              values={{
                muted: (chunks: ReactNode) => (
                  <span className="small text-muted">{chunks}</span>
                ),
              }}
            />
          }
        >
          <Form.Control
            type="text"
            {...register("ttlSeconds", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.ttlSeconds}
          />
          <FormFeedback feedback={errors.ttlSeconds?.message} />
        </FormRow>

        <CollapseItem
          type="flat"
          open={advancedOptionsOpen}
          onToggle={toggleAdvancedOptions}
          isInsideTable={true}
          title={
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.advancedOptionsTitle"
              defaultMessage="Advanced Options"
            />
          }
        >
          <Stack gap={3}>
            <FormRow
              id="fileMode"
              label={
                <FormattedMessage
                  id="forms.CreateFileDownloadCampaign.fileModeLabel"
                  defaultMessage="File Mode"
                />
              }
            >
              <Form.Control
                type="text"
                {...register("fileMode", {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.fileMode}
              />
              <FormFeedback feedback={errors.fileMode?.message} />
            </FormRow>

            <FormRow
              id="userId"
              label={
                <FormattedMessage
                  id="forms.CreateFileDownloadCampaign.userIdLabel"
                  defaultMessage="User ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register("userId", {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.userId}
              />
              <FormFeedback feedback={errors.userId?.message} />
            </FormRow>

            <FormRow
              id="groupId"
              label={
                <FormattedMessage
                  id="forms.CreateFileDownloadCampaign.groupIdLabel"
                  defaultMessage="Group ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register("groupId", {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.groupId}
              />
              <FormFeedback feedback={errors.groupId?.message} />
            </FormRow>
          </Stack>
        </CollapseItem>

        <div className="d-flex justify-content-end align-items-center">
          <Button type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateFileDownloadCampaign.submitButton"
              defaultMessage="Create Campaign"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { FileDownloadCampaignOutputData };
export default CreateFileDownloadCampaignForm;
