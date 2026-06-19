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
import React, { useCallback, useMemo, useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useMutation, usePaginationFragment } from "react-relay";
import Select from "react-select";

import type { EditDeploymentCampaignModal_ApplicationOptionsFragment$key } from "@/api/__generated__/EditDeploymentCampaignModal_ApplicationOptionsFragment.graphql";
import type { EditDeploymentCampaignModal_ApplicationPaginationQuery } from "@/api/__generated__/EditDeploymentCampaignModal_ApplicationPaginationQuery.graphql";
import type { EditDeploymentCampaignModal_updateCampaign_Mutation } from "@/api/__generated__/EditDeploymentCampaignModal_updateCampaign_Mutation.graphql";

import EditModal from "@/components/EditModal";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import ReleaseSelectWrapper from "@/components/ReleaseSelect";
import Stack from "@/components/Stack";
import FormFeedback from "@/forms/FormFeedback";
import {
  editDeploymentCampaignSchema,
  type EditDeploymentCampaignFormData,
} from "@/forms/validation";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";

const CAMPAIGN_APPLICATION_OPTIONS_FRAGMENT = graphql`
  fragment EditDeploymentCampaignModal_ApplicationOptionsFragment on RootQueryType
  @refetchable(
    queryName: "EditDeploymentCampaignModal_ApplicationPaginationQuery"
  )
  @argumentDefinitions(filter: { type: "ApplicationFilterInput" }) {
    applications(first: $first, after: $after, filter: $filter)
      @connection(key: "EditDeploymentCampaignModal_applications") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

const UPDATE_CAMPAIGN_MUTATION = graphql`
  mutation EditDeploymentCampaignModal_updateCampaign_Mutation(
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

type ApplicationRecord = { id: string; name: string };
type OperationType = "Deploy" | "Start" | "Stop" | "Upgrade" | "Delete";

const TYPENAME_TO_OPERATION: Record<string, OperationType> = {
  DeploymentDeploy: "Deploy",
  DeploymentStart: "Start",
  DeploymentStop: "Stop",
  DeploymentUpgrade: "Upgrade",
  DeploymentDelete: "Delete",
};

type CampaignToUpdate = {
  id: string;
  campaignMechanism?: {
    __typename?: string;
    release?: {
      id: string;
      version: string;
      application?: { id: string; name: string } | null;
    } | null;
    targetRelease?: {
      id: string;
      version: string;
    } | null;
    maxFailurePercentage?: number | null;
    maxInProgressOperations?: number | null;
    requestRetries?: number | null;
    requestTimeoutSeconds?: number | null;
  } | null;
  scheduledAtTimestamp?: string | null;
};

type EditDeploymentCampaignModalProps = {
  campaignToUpdate: CampaignToUpdate;
  campaignOptionsRef: EditDeploymentCampaignModal_ApplicationOptionsFragment$key;
  onCancel: () => void;
  onSuccess: () => void;
  setErrorFeedback: (msg: React.ReactNode) => void;
};

const EditDeploymentCampaignModal = ({
  campaignToUpdate,
  campaignOptionsRef,
  onCancel,
  onSuccess,
  setErrorFeedback,
}: EditDeploymentCampaignModalProps) => {
  const intl = useIntl();
  const mechanism = campaignToUpdate.campaignMechanism;

  const derivedOperationType = mechanism?.__typename
    ? TYPENAME_TO_OPERATION[mechanism.__typename] || "Deploy"
    : "Deploy";

  const [updateCampaign, isUpdating] =
    useMutation<EditDeploymentCampaignModal_updateCampaign_Mutation>(
      UPDATE_CAMPAIGN_MUTATION,
    );

  const {
    control,
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    resetField,
  } = useForm<EditDeploymentCampaignFormData>({
    mode: "onTouched",
    resolver: zodResolver(editDeploymentCampaignSchema),
    defaultValues: {
      operationType: derivedOperationType,
      application: mechanism?.release?.application
        ? {
            id: mechanism.release.application.id,
            name: mechanism.release.application.name,
          }
        : undefined,
      release: mechanism?.release
        ? {
            id: mechanism.release.id,
            version: mechanism.release.version,
          }
        : undefined,
      targetRelease: mechanism?.targetRelease
        ? {
            id: mechanism.targetRelease.id,
            version: mechanism.targetRelease.version,
          }
        : undefined,
      maxInProgressOperations: mechanism?.maxInProgressOperations ?? undefined,
      maxFailurePercentage: mechanism?.maxFailurePercentage ?? undefined,
      requestTimeoutSeconds: mechanism?.requestTimeoutSeconds ?? undefined,
      requestRetries: mechanism?.requestRetries ?? undefined,
      scheduledAtTimestamp: campaignToUpdate.scheduledAtTimestamp ?? undefined,
    },
  });

  const selectedApp = useWatch({ control, name: "application" });
  const selectedRelease = useWatch({ control, name: "release" });
  const selectedOperationType = useWatch({ control, name: "operationType" });

  const { onChange: onApplicationChange } = register("application");

  const {
    data: applicationPaginationData,
    loadNext: loadNextApplications,
    hasNext: hasNextApplication,
    isLoadingNext: isLoadingNextApplication,
    refetch: refetchApplications,
  } = usePaginationFragment<
    EditDeploymentCampaignModal_ApplicationPaginationQuery,
    EditDeploymentCampaignModal_ApplicationOptionsFragment$key
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
      buildFilter: (text) =>
        text === "" ? undefined : { name: { ilike: `%${text}%` } },
    });

  const applicationOptions = useMemo(() => {
    return (
      (applicationPaginationData as any)?.applications?.edges
        ?.map((edge: any) => edge?.node)
        .filter((node: any): node is ApplicationRecord => node != null) ?? []
    );
  }, [applicationPaginationData]);

  const onSubmit = useCallback(
    (data: EditDeploymentCampaignFormData) => {
      updateCampaign({
        variables: {
          id: campaignToUpdate.id,
          input: {
            releaseId: data.release.id,
            ...(data.targetRelease && {
              targetReleaseId: data.targetRelease.id,
            }),
            maxInProgressOperations: data.maxInProgressOperations,
            maxFailurePercentage: data.maxFailurePercentage,
            requestTimeoutSeconds: data.requestTimeoutSeconds,
            requestRetries: data.requestRetries,
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
              id="components.EditDeploymentCampaignModal.error"
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
          id="components.EditDeploymentCampaignModal.title"
          defaultMessage="Edit Deployment Campaign"
        />
      }
      onCancel={onCancel}
      onSubmit={handleSubmit(onSubmit)}
      isSubmitting={isSubmitting || isUpdating}
    >
      <Stack gap={3}>
        <FormRow
          id="edit-deployment-campaign-form-application"
          label={
            <FormattedMessage
              id="components.EditDeploymentCampaignModal.applicationLabel"
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
                  resetField("targetRelease");
                }}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "components.EditDeploymentCampaignModal.applicationOption",
                  defaultMessage: "Search or select an application...",
                })}
                options={applicationOptions}
                getOptionLabel={(opt) => opt.name}
                getOptionValue={(opt) => opt.id}
                isLoading={isLoadingNextApplication}
                onMenuScrollToBottom={onLoadMoreApplicationOptions}
                onInputChange={(text) => setSearchApplicationText(text)}
              />
            )}
          />
          <FormFeedback
            feedback={
              (errors.application?.message ||
                (errors.application as any)?.id?.message) as string
            }
          />
        </FormRow>

        <FormRow
          id="release"
          label={
            <FormattedMessage
              id="components.EditDeploymentCampaignModal.releaseLabel"
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
                      value: value as any,
                      invalid,
                      onChange,
                    }}
                  />
                )}
              />
              <FormFeedback
                feedback={
                  (errors.release?.message ||
                    (errors.release as any)?.id?.message) as string
                }
              />
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="components.EditDeploymentCampaignModal.selectApplication"
                defaultMessage="Select an application..."
              />
            </div>
          )}
        </FormRow>

        {selectedOperationType === "Upgrade" && (
          <FormRow
            id="targetRelease"
            label={
              <FormattedMessage
                id="components.EditDeploymentCampaignModal.targetReleaseLabel"
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
                      selectedRelease={selectedRelease as any}
                      controllerProps={{
                        value: value as any,
                        invalid,
                        onChange,
                      }}
                    />
                  )}
                />
                <FormFeedback
                  feedback={
                    (errors.targetRelease?.message ||
                      (errors.targetRelease as any)?.id?.message) as string
                  }
                />
              </>
            ) : (
              <div className="d-flex align-content-center fst-italic text-muted">
                <FormattedMessage
                  id="components.EditDeploymentCampaignModal.selectApplicationAndRelease"
                  defaultMessage="Select an application and a release..."
                />
              </div>
            )}
          </FormRow>
        )}

        <FormRow
          id="maxInProgressOperations"
          label={
            <FormattedMessage
              id="components.EditDeploymentCampaignModal.maxInProgressOperationsLabel"
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
          <FormFeedback
            feedback={errors.maxInProgressOperations?.message as string}
          />
        </FormRow>

        <FormRow
          id="maxFailurePercentage"
          label={
            <FormattedMessage
              id="components.EditDeploymentCampaignModal.maxFailurePercentageLabel"
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
          <FormFeedback
            feedback={errors.maxFailurePercentage?.message as string}
          />
        </FormRow>

        <FormRow
          id="requestTimeout"
          label={
            <FormattedMessage
              id="components.EditDeploymentCampaignModal.requestTimeoutSecondsLabel"
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
          <FormFeedback
            feedback={errors.requestTimeoutSeconds?.message as string}
          />
        </FormRow>

        <FormRow
          id="requestRetries"
          label={
            <FormattedMessage
              id="components.EditDeploymentCampaignModal.requestRetriesLabel"
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
          <FormFeedback feedback={errors.requestRetries?.message as string} />
        </FormRow>

        {/* TODO: Enable editing for scheduledAt field after backend issue is resolved */}
      </Stack>
    </EditModal>
  );
};

export default EditDeploymentCampaignModal;
