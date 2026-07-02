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
import type { ReactNode } from "react";
import { useCallback, useMemo, useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useMutation, usePaginationFragment } from "react-relay";

import type {
  EditFileDownloadCampaignModal_RepositoryOptionsFragment$data,
  EditFileDownloadCampaignModal_RepositoryOptionsFragment$key,
} from "@/api/__generated__/EditFileDownloadCampaignModal_RepositoryOptionsFragment.graphql";
import type { EditFileDownloadCampaignModal_RepositoryPaginationQuery } from "@/api/__generated__/EditFileDownloadCampaignModal_RepositoryPaginationQuery.graphql";
import type {
  EditFileDownloadCampaignModal_updateCampaign_Mutation,
  FileDestination,
} from "@/api/__generated__/EditFileDownloadCampaignModal_updateCampaign_Mutation.graphql";

import CollapseItem, { useCollapseToggle } from "@/components/CollapseItem";
import EditModal from "@/components/EditModal";
import FileSelect from "@/components/FileSelect";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Stack from "@/components/Stack";
import FormFeedback from "@/forms/FormFeedback";
import {
  UpdateFileDownloadCampaignFormData,
  updateFileDownloadCampaignSchema,
} from "@/forms/validation";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import DatePicker from "@/components/DatePicker";
import Select from "@/components/Select";

const CAMPAIGN_REPOSITORY_OPTIONS_FRAGMENT = graphql`
  fragment EditFileDownloadCampaignModal_RepositoryOptionsFragment on RootQueryType
  @refetchable(
    queryName: "EditFileDownloadCampaignModal_RepositoryPaginationQuery"
  )
  @argumentDefinitions(filter: { type: "RepositoryFilterInput" }) {
    repositories(first: $first, after: $after, filter: $filter)
      @connection(key: "EditFileDownloadCampaignModal_repositories") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

const destinationOptions: { value: FileDestination; label: string }[] = [
  { value: "STORAGE", label: "Storage" },
  { value: "STREAMING", label: "Streaming" },
  { value: "FILESYSTEM", label: "File System" },
];

type RepositoryRecord = NonNullable<
  NonNullable<
    EditFileDownloadCampaignModal_RepositoryOptionsFragment$data["repositories"]
  >["edges"]
>[number]["node"];

const UPDATE_CAMPAIGN_MUTATION = graphql`
  mutation EditFileDownloadCampaignModal_updateCampaign_Mutation(
    $id: ID!
    $input: UpdateCampaignInput!
  ) {
    updateCampaign(id: $id, input: $input) {
      result {
        id
      }
      errors {
        message
      }
    }
  }
`;

type Campaign = {
  id: string;
  name: string;
  campaignMechanism?: {
    __typename?: string;
    destinationType?: string | null;
    destination?: string | null;
    file?: {
      id: string;
      name?: string | null;
      repository?: {
        id: string;
        name: string;
      } | null;
    } | null;
    maxFailurePercentage?: number | null;
    maxInProgressOperations?: number | null;
    requestRetries?: number | null;
    requestTimeoutSeconds?: number | null;
    ttlSeconds?: number | null;
    fileMode?: number | null;
    userId?: number | null;
    groupId?: number | null;
  } | null;
  scheduledAtTimestamp?: string | null;
};

type EditFileDownloadCampaignModalProps<C extends Campaign> = {
  campaignToUpdate: C;
  campaignOptionsRef: EditFileDownloadCampaignModal_RepositoryOptionsFragment$key;
  onCancel: () => void;
  onSuccess: () => void;
  setErrorFeedback: (msg: React.ReactNode) => void;
};

const EditFileDownloadCampaignModal = <C extends Campaign>({
  campaignToUpdate,
  campaignOptionsRef,
  onCancel,
  onSuccess,
  setErrorFeedback,
}: EditFileDownloadCampaignModalProps<C>) => {
  const intl = useIntl();

  const [updateCampaign, isUpdating] =
    useMutation<EditFileDownloadCampaignModal_updateCampaign_Mutation>(
      UPDATE_CAMPAIGN_MUTATION,
    );

  const { open: advancedOptionsOpen, toggle: toggleAdvancedOptions } =
    useCollapseToggle();

  const mechanism = campaignToUpdate.campaignMechanism;
  const isFileDownload = mechanism?.__typename === "FileDownload";

  const {
    register,
    handleSubmit,
    control,
    resetField,
    formState: { errors, isSubmitting },
  } = useForm<UpdateFileDownloadCampaignFormData>({
    resolver: zodResolver(updateFileDownloadCampaignSchema),
    mode: "onTouched",
    defaultValues: {
      name: campaignToUpdate.name,
      destinationType: isFileDownload
        ? (mechanism?.destinationType as FileDestination)
        : undefined,
      destination: isFileDownload ? (mechanism?.destination ?? "") : "",
      repository:
        isFileDownload && mechanism?.file?.repository
          ? {
              id: mechanism.file.repository.id,
              name: mechanism.file.repository.name,
            }
          : undefined,
      file:
        isFileDownload && mechanism?.file
          ? { id: mechanism.file.id, name: mechanism.file.name ?? "" }
          : undefined,
      maxFailurePercentage: isFileDownload
        ? (mechanism?.maxFailurePercentage ?? undefined)
        : undefined,
      maxInProgressOperations: isFileDownload
        ? (mechanism?.maxInProgressOperations ?? undefined)
        : undefined,
      requestRetries: isFileDownload
        ? (mechanism?.requestRetries ?? undefined)
        : undefined,
      requestTimeoutSeconds: isFileDownload
        ? (mechanism?.requestTimeoutSeconds ?? undefined)
        : undefined,
      ttlSeconds: isFileDownload
        ? (mechanism?.ttlSeconds ?? undefined)
        : undefined,
      fileMode:
        isFileDownload && mechanism?.fileMode !== 0
          ? (mechanism?.fileMode ?? undefined)
          : undefined,
      userId:
        isFileDownload && mechanism?.userId !== -1
          ? (mechanism?.userId ?? undefined)
          : undefined,
      groupId:
        isFileDownload && mechanism?.groupId !== -1
          ? (mechanism?.groupId ?? undefined)
          : undefined,
      scheduledAtTimestamp: campaignToUpdate.scheduledAtTimestamp ?? undefined,
    },
  });

  const selectedDestinationType = useWatch({
    control,
    name: "destinationType",
  });
  const selectedRepository = useWatch({ control, name: "repository" });

  const { onChange: onRepositoryChange } = register("repository");
  const { onChange: onFileChange } = register("file");

  const {
    data: repositoryPaginationData,
    loadNext: loadNextRepositories,
    hasNext: hasNextRepository,
    isLoadingNext: isLoadingNextRepository,
    refetch: refetchRepositories,
  } = usePaginationFragment<
    EditFileDownloadCampaignModal_RepositoryPaginationQuery,
    EditFileDownloadCampaignModal_RepositoryOptionsFragment$key
  >(CAMPAIGN_REPOSITORY_OPTIONS_FRAGMENT, campaignOptionsRef);

  const [searchRepositoryText, setSearchRepositoryText] = useState<
    string | null
  >(null);

  const { onLoadMore: onLoadMoreRepositoryOptions } =
    useRelayConnectionPagination({
      hasNext: hasNextRepository,
      isLoadingNext: isLoadingNextRepository,
      loadNext: loadNextRepositories,
      refetch: refetchRepositories,
      searchText: searchRepositoryText,
      buildFilter: (text) =>
        text === "" ? undefined : { name: { ilike: `%${text}%` } },
    });

  const repositories = useMemo(() => {
    return (
      repositoryPaginationData.repositories?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is RepositoryRecord => node != null) ?? []
    );
  }, [repositoryPaginationData]);

  const onSubmit = useCallback(
    (data: UpdateFileDownloadCampaignFormData) => {
      updateCampaign({
        variables: {
          id: campaignToUpdate.id,
          input: {
            name: data.name,
            destinationType:
              (data.destinationType as FileDestination) || undefined,
            destination: data.destination || undefined,
            fileId: data.file?.id || undefined,
            maxFailurePercentage: data.maxFailurePercentage,
            maxInProgressOperations: data.maxInProgressOperations,
            requestRetries: data.requestRetries,
            requestTimeoutSeconds: data.requestTimeoutSeconds,
            ttlSeconds: data.ttlSeconds,
            fileMode: data.fileMode,
            userId: data.userId,
            groupId: data.groupId,
            scheduledAtTimestamp: data.scheduledAtTimestamp
              ? new Date(data.scheduledAtTimestamp).toISOString()
              : undefined,
          },
        },
        onCompleted(response, mutationErrors) {
          const combinedErrors =
            mutationErrors || response.updateCampaign?.errors;
          if (combinedErrors?.length) {
            setErrorFeedback(combinedErrors.map((e) => e.message).join("\n"));
            return;
          }
          setErrorFeedback(null);
          onSuccess();
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.error"
              defaultMessage="Could not update campaign."
            />,
          );
        },
      });
    },
    [campaignToUpdate.id, updateCampaign, onSuccess, setErrorFeedback],
  );

  return (
    <EditModal
      title={
        <FormattedMessage
          id="components.EditFileDownloadCampaignModal.title"
          defaultMessage="Update Campaign"
        />
      }
      onCancel={onCancel}
      onSubmit={handleSubmit(onSubmit)}
      isSubmitting={isUpdating || isSubmitting}
    >
      <Stack gap={3}>
        <FormRow
          id="name"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.nameLabel"
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
          id="destinationType"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.destinationLabel"
              defaultMessage="Destination"
            />
          }
        >
          <Controller
            control={control}
            name="destinationType"
            render={({ field }) => (
              <Select
                value={
                  destinationOptions.find((opt) => opt.value === field.value) ||
                  null
                }
                onChange={(option) =>
                  field.onChange(option ? option.value : null)
                }
                options={destinationOptions}
                className={errors.destinationType ? "is-invalid" : ""}
              />
            )}
          />
          <FormFeedback feedback={errors.destinationType?.message as string} />
        </FormRow>

        {selectedDestinationType === "FILESYSTEM" && (
          <FormRow
            id="destination"
            label={
              <FormattedMessage
                id="components.EditFileDownloadCampaignModal.destinationPathLabel"
                defaultMessage="Destination Path"
              />
            }
          >
            <Form.Control
              type="text"
              {...register("destination")}
              isInvalid={!!errors.destination}
            />
            <FormFeedback feedback={errors.destination?.message as string} />
          </FormRow>
        )}

        <FormRow
          id="repository"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.repositoryLabel"
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
                  id: "components.EditFileDownloadCampaignModal.repositoryOption",
                  defaultMessage: "Search or select a repository...",
                })}
                options={repositories}
                getOptionLabel={(opt) => opt.name}
                getOptionValue={(opt) => opt.id}
                isLoading={isLoadingNextRepository}
                onMenuScrollToBottom={onLoadMoreRepositoryOptions}
                onInputChange={(text) => setSearchRepositoryText(text)}
              />
            )}
          />
          <FormFeedback feedback={errors.repository?.id?.message as string} />
        </FormRow>

        <FormRow
          id="file"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.fileLabel"
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
                      value: value as { id: string; name: string },
                      invalid,
                      onChange: (e) => {
                        onChange(e);
                        onFileChange({ target: e });
                      },
                    }}
                  />
                )}
              />
              <FormFeedback feedback={errors.file?.id?.message as string} />
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="components.EditFileDownloadCampaignModal.selectRepositoryHint"
                defaultMessage="Select a repository before selecting a file..."
              />
            </div>
          )}
        </FormRow>

        <FormRow
          id="maxFailurePercentage"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.maxFailurePercentageLabel"
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
          <FormFeedback
            feedback={errors.maxFailurePercentage?.message as string}
          />
        </FormRow>

        <FormRow
          id="maxInProgressOperations"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.maxInProgressOperationsLabel"
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
          <FormFeedback
            feedback={errors.maxInProgressOperations?.message as string}
          />
        </FormRow>

        <FormRow
          id="requestTimeoutSeconds"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.requestTimeoutSecondsLabel"
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
          <FormFeedback
            feedback={errors.requestTimeoutSeconds?.message as string}
          />
        </FormRow>

        <FormRow
          id="requestRetries"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.requestRetriesLabel"
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
          <FormFeedback feedback={errors.requestRetries?.message as string} />
        </FormRow>

        <FormRow
          id="ttlSeconds"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.ttlLabel"
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
          <FormFeedback feedback={errors.ttlSeconds?.message as string} />
        </FormRow>

        <FormRow
          id="scheduledAt"
          label={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.scheduledAtTimestampLabel"
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
          <FormFeedback
            feedback={errors.scheduledAtTimestamp?.message as string}
          />
        </FormRow>

        <CollapseItem
          open={advancedOptionsOpen}
          onToggle={toggleAdvancedOptions}
          title={
            <FormattedMessage
              id="components.EditFileDownloadCampaignModal.advancedOptionsTitle"
              defaultMessage="Advanced Options"
            />
          }
          headerClassName="ps-0 border-0"
          style={{ backgroundColor: "transparent" }}
          caretPosition="right"
        >
          <Stack gap={3}>
            <FormRow
              id="fileMode"
              label={
                <FormattedMessage
                  id="components.EditFileDownloadCampaignModal.fileModeLabel"
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
              <FormFeedback feedback={errors.fileMode?.message as string} />
            </FormRow>

            <FormRow
              id="userId"
              label={
                <FormattedMessage
                  id="components.EditFileDownloadCampaignModal.userIdLabel"
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
              <FormFeedback feedback={errors.userId?.message as string} />
            </FormRow>

            <FormRow
              id="groupId"
              label={
                <FormattedMessage
                  id="components.EditFileDownloadCampaignModal.groupIdLabel"
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
              <FormFeedback feedback={errors.groupId?.message as string} />
            </FormRow>
          </Stack>
        </CollapseItem>
      </Stack>
    </EditModal>
  );
};

export default EditFileDownloadCampaignModal;
