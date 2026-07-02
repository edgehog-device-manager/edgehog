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

import type { EditUpdateCampaignModal_BaseImageCollOptionsFragment$key } from "@/api/__generated__/EditUpdateCampaignModal_BaseImageCollOptionsFragment.graphql";
import type { EditUpdateCampaignModal_BaseImageCollPaginationQuery } from "@/api/__generated__/EditUpdateCampaignModal_BaseImageCollPaginationQuery.graphql";
import type { EditUpdateCampaignModal_updateCampaign_Mutation } from "@/api/__generated__/EditUpdateCampaignModal_updateCampaign_Mutation.graphql";

import BaseImageSelect from "@/components/BaseImageSelect";
import EditModal from "@/components/EditModal";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Stack from "@/components/Stack";
import FormFeedback from "@/forms/FormFeedback";
import {
  editUpdateCampaignSchema,
  type EditUpdateCampaignFormData,
} from "@/forms/validation";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import DatePicker from "./DatePicker";
import Select from "@/components/Select";

const CAMPAIGN_BASE_IMAGE_COLL_OPTIONS_FRAGMENT = graphql`
  fragment EditUpdateCampaignModal_BaseImageCollOptionsFragment on RootQueryType
  @refetchable(
    queryName: "EditUpdateCampaignModal_BaseImageCollPaginationQuery"
  )
  @argumentDefinitions(filter: { type: "BaseImageCollectionFilterInput" }) {
    baseImageCollections(first: $first, after: $after, filter: $filter)
      @connection(key: "EditUpdateCampaignModal_baseImageCollections") {
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
  mutation EditUpdateCampaignModal_updateCampaign_Mutation(
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

type BaseImageCollectionRecord = { id: string; name: string };

type CampaignToUpdate = {
  id: string;
  name: string;
  campaignMechanism?: {
    __typename?: string;
    baseImage?: {
      id: string;
      name?: string | null;
      version?: string | null;
      baseImageCollection?: { id: string; name?: string | null } | null;
    } | null;
    maxFailurePercentage?: number | null;
    maxInProgressOperations?: number | null;
    requestRetries?: number | null;
    requestTimeoutSeconds?: number | null;
    forceDowngrade?: boolean | null;
  } | null;
  scheduledAtTimestamp?: string | null;
};

type EditUpdateCampaignModalProps = {
  campaignToUpdate: CampaignToUpdate;
  campaignOptionsRef: EditUpdateCampaignModal_BaseImageCollOptionsFragment$key;
  onCancel: () => void;
  onSuccess: () => void;
  setErrorFeedback: (msg: React.ReactNode) => void;
};

const EditUpdateCampaignModal = ({
  campaignToUpdate,
  campaignOptionsRef,
  onCancel,
  onSuccess,
  setErrorFeedback,
}: EditUpdateCampaignModalProps) => {
  const intl = useIntl();
  const mechanism = campaignToUpdate.campaignMechanism;

  const [updateCampaign, isUpdating] =
    useMutation<EditUpdateCampaignModal_updateCampaign_Mutation>(
      UPDATE_CAMPAIGN_MUTATION,
    );

  const {
    control,
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    resetField,
  } = useForm<EditUpdateCampaignFormData>({
    mode: "onTouched",
    resolver: zodResolver(editUpdateCampaignSchema),
    defaultValues: {
      name: campaignToUpdate.name,
      baseImageCollection: mechanism?.baseImage?.baseImageCollection
        ? {
            id: mechanism.baseImage.baseImageCollection.id,
            name: mechanism.baseImage.baseImageCollection.name ?? "",
          }
        : undefined,
      baseImage: mechanism?.baseImage
        ? {
            id: mechanism.baseImage.id,
            name: mechanism.baseImage.name ?? "",
            version: mechanism.baseImage.version ?? "",
          }
        : undefined,
      operationType: "FirmwareUpgrade",
      maxInProgressOperations: mechanism?.maxInProgressOperations ?? undefined,
      maxFailurePercentage: mechanism?.maxFailurePercentage ?? undefined,
      requestTimeoutSeconds: mechanism?.requestTimeoutSeconds ?? undefined,
      requestRetries: mechanism?.requestRetries ?? undefined,
      forceDowngrade: mechanism?.forceDowngrade ?? false,
      scheduledAtTimestamp: campaignToUpdate.scheduledAtTimestamp ?? undefined,
    },
  });

  const selectedBaseImageCollection = useWatch({
    control,
    name: "baseImageCollection",
  });

  const { onChange: onBaseImageCollectionChange } = register(
    "baseImageCollection",
  );

  const {
    data: baseImageCollPaginationData,
    loadNext: loadNextBaseImageColls,
    hasNext: hasNextBaseImageColl,
    isLoadingNext: isLoadingNextBaseImageColl,
    refetch: refetchBaseImageColls,
  } = usePaginationFragment<
    EditUpdateCampaignModal_BaseImageCollPaginationQuery,
    EditUpdateCampaignModal_BaseImageCollOptionsFragment$key
  >(CAMPAIGN_BASE_IMAGE_COLL_OPTIONS_FRAGMENT, campaignOptionsRef);

  const [searchBaseImageCollText, setSearchBaseImageCollText] = useState<
    string | null
  >(null);

  const { onLoadMore: onLoadMoreBaseImageCollOptions } =
    useRelayConnectionPagination({
      hasNext: hasNextBaseImageColl,
      isLoadingNext: isLoadingNextBaseImageColl,
      loadNext: loadNextBaseImageColls,
      refetch: refetchBaseImageColls,
      searchText: searchBaseImageCollText,
      buildFilter: (text) =>
        text === "" ? undefined : { name: { ilike: `%${text}%` } },
    });

  const baseImageCollections = useMemo(() => {
    return (
      (baseImageCollPaginationData as any)?.baseImageCollections?.edges
        ?.map((edge: any) => edge?.node)
        .filter(
          (node: any): node is BaseImageCollectionRecord => node != null,
        ) ?? []
    );
  }, [baseImageCollPaginationData]);

  const onSubmit = useCallback(
    (data: EditUpdateCampaignFormData) => {
      updateCampaign({
        variables: {
          id: campaignToUpdate.id,
          input: {
            name: data.name,
            baseImageId: data.baseImage.id,
            maxInProgressOperations: data.maxInProgressOperations,
            maxFailurePercentage: data.maxFailurePercentage,
            requestTimeoutSeconds: data.requestTimeoutSeconds,
            requestRetries: data.requestRetries,
            forceDowngrade: data.forceDowngrade,
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
              id="components.EditUpdateCampaignModal.error"
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
          id="components.EditUpdateCampaignModal.title"
          defaultMessage="Edit Update Campaign"
        />
      }
      onCancel={onCancel}
      onSubmit={handleSubmit(onSubmit)}
      isSubmitting={isSubmitting || isUpdating}
    >
      <Stack gap={3}>
        <FormRow
          id="name"
          label={
            <FormattedMessage
              id="components.EditUpdateCampaignModal.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message as string} />
        </FormRow>

        <FormRow
          id="baseImageCollection"
          label={
            <FormattedMessage
              id="components.EditUpdateCampaignModal.baseImageCollectionLabel"
              defaultMessage="Base Image Collection"
            />
          }
        >
          <Controller
            name="baseImageCollection"
            control={control}
            render={({
              field: { value, onChange },
              fieldState: { invalid },
            }) => (
              <Select
                value={value}
                onChange={(e) => {
                  onChange(e);
                  onBaseImageCollectionChange({ target: e });
                  resetField("baseImage");
                }}
                className={invalid ? "is-invalid" : ""}
                placeholder={intl.formatMessage({
                  id: "components.EditUpdateCampaignModal.baseImageCollectionOption",
                  defaultMessage: "Search or select a base image collection...",
                })}
                options={baseImageCollections}
                getOptionLabel={(opt) => opt.name}
                getOptionValue={(opt) => opt.id}
                isLoading={isLoadingNextBaseImageColl}
                onMenuScrollToBottom={onLoadMoreBaseImageCollOptions}
                onInputChange={(text) => setSearchBaseImageCollText(text)}
              />
            )}
          />
          <FormFeedback
            feedback={errors.baseImageCollection?.id?.message as string}
          />
        </FormRow>

        <FormRow
          id="baseImage"
          label={
            <FormattedMessage
              id="components.EditUpdateCampaignModal.baseImageLabel"
              defaultMessage="Base Image"
            />
          }
          valueColClassName="align-content-center"
        >
          {selectedBaseImageCollection?.id ? (
            <>
              <Controller
                name="baseImage"
                control={control}
                render={({
                  field: { value, onChange },
                  fieldState: { invalid },
                }) => (
                  <BaseImageSelect
                    selectedBaseImageCollection={selectedBaseImageCollection}
                    controllerProps={{
                      value: value as any,
                      invalid,
                      onChange,
                    }}
                  />
                )}
              />
              <FormFeedback
                feedback={errors.baseImage?.id?.message as string}
              />
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="components.EditUpdateCampaignModal.selectBaseImageCollection"
                defaultMessage="Select a base image collection..."
              />
            </div>
          )}
        </FormRow>

        <FormRow
          id="maxInProgressOperations"
          label={
            <FormattedMessage
              id="components.EditUpdateCampaignModal.maxInProgressOperationsLabel"
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
              id="components.EditUpdateCampaignModal.maxFailurePercentageLabel"
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
              id="components.EditUpdateCampaignModal.requestTimeoutSecondsLabel"
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
              id="components.EditUpdateCampaignModal.otaRequestRetriesLabel"
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

        <FormRow
          id="forceDowngrade"
          label={
            <FormattedMessage
              id="components.EditUpdateCampaignModal.forceDowngradeLabel"
              defaultMessage="Force Downgrade"
            />
          }
        >
          <Form.Check
            type="checkbox"
            {...register("forceDowngrade")}
            isInvalid={!!errors.forceDowngrade}
          />
          <FormFeedback feedback={errors.forceDowngrade?.message as string} />
        </FormRow>

        <FormRow
          id="scheduledAt"
          label={
            <FormattedMessage
              id="components.EditUpdateCampaignModal.scheduledAtTimestampLabel"
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
      </Stack>
    </EditModal>
  );
};

export default EditUpdateCampaignModal;
