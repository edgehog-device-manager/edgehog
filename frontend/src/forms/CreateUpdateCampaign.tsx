/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2025 SECO Mind Srl
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

import {
  CreateUpdateCampaign_BaseImageCollOptionsFragment$data,
  CreateUpdateCampaign_BaseImageCollOptionsFragment$key,
} from "@/api/__generated__/CreateUpdateCampaign_BaseImageCollOptionsFragment.graphql";
import type { CreateUpdateCampaign_BaseImageCollPaginationQuery } from "@/api/__generated__/CreateUpdateCampaign_BaseImageCollPaginationQuery.graphql";
import {
  CreateUpdateCampaign_ChannelOptionsFragment$data,
  CreateUpdateCampaign_ChannelOptionsFragment$key,
} from "@/api/__generated__/CreateUpdateCampaign_ChannelOptionsFragment.graphql";
import type { CreateUpdateCampaign_ChannelPaginationQuery } from "@/api/__generated__/CreateUpdateCampaign_ChannelPaginationQuery.graphql";

import BaseImageSelect, { BaseImageRecord } from "@/components/BaseImageSelect";
import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { numberSchema, yup } from "@/forms";
import FormFeedback from "@/forms/FormFeedback";

const UPDATE_CAMPAIGN_BASE_IMAGE_COLL_OPTIONS_FRAGMENT = graphql`
  fragment CreateUpdateCampaign_BaseImageCollOptionsFragment on RootQueryType
  @refetchable(queryName: "CreateUpdateCampaign_BaseImageCollPaginationQuery")
  @argumentDefinitions(filter: { type: "BaseImageCollectionFilterInput" }) {
    baseImageCollections(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateUpdateCampaign_baseImageCollections") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

const UPDATE_CAMPAIGN_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment CreateUpdateCampaign_ChannelOptionsFragment on RootQueryType
  @refetchable(queryName: "CreateUpdateCampaign_ChannelPaginationQuery")
  @argumentDefinitions(filter: { type: "ChannelFilterInput" }) {
    channels(first: $first, after: $after, filter: $filter)
      @connection(key: "CreateUpdateCampaign_channels") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type BaseImageCollectionRecord = NonNullable<
  NonNullable<
    CreateUpdateCampaign_BaseImageCollOptionsFragment$data["baseImageCollections"]
  >["edges"]
>[number]["node"];

type ChannelRecord = NonNullable<
  NonNullable<
    CreateUpdateCampaign_ChannelOptionsFragment$data["channels"]
  >["edges"]
>[number]["node"];

type UpdateCampaignData = {
  channelId: string;
  baseImageId: string;
  name: string;
  rolloutMechanism: {
    push: {
      maxFailurePercentage: number;
      maxInProgressUpdates: number;
      otaRequestRetries: number;
      otaRequestTimeoutSeconds: number;
      forceDowngrade: boolean;
    };
  };
};

type FormData = {
  name: string;
  channel: ChannelRecord;
  baseImageCollection: BaseImageCollectionRecord;
  baseImage: BaseImageRecord;
  maxFailurePercentage: number | string;
  maxInProgressUpdates: number | string;
  otaRequestRetries: number;
  otaRequestTimeoutSeconds: number;
  forceDowngrade: boolean;
};

const initialData: FormData = {
  name: "",
  channel: { id: "", name: "" },
  baseImageCollection: { id: "", name: "" },
  baseImage: { id: "", name: "", version: "" },
  maxFailurePercentage: "",
  maxInProgressUpdates: "",
  otaRequestRetries: 3,
  otaRequestTimeoutSeconds: 300,
  forceDowngrade: false,
};

const updateCampaignSchema = (intl: any) =>
  yup
    .object({
      name: yup.string().required(),
      baseImageCollection: yup
        .object({ id: yup.string().required(), name: yup.string().required() })
        .required(),
      baseImage: yup
        .object({ id: yup.string().required(), name: yup.string() })
        .required(),
      channel: yup
        .object({ id: yup.string().required(), name: yup.string().required() })
        .required(),
      maxInProgressUpdates: numberSchema
        .integer()
        .positive()
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.maxInProgressUpdatesLabel",
            defaultMessage: "Max Pending Operations",
          }),
        ),
      maxFailurePercentage: numberSchema
        .min(0)
        .max(100)
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.maxFailurePercentageValidationLabel",
            defaultMessage: "Max Failures",
          }),
        ),
      otaRequestTimeoutSeconds: numberSchema
        .positive()
        .integer()
        .min(30)
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.otaRequestTimeoutSecondsValidationLabel",
            defaultMessage: "Request Timeout",
          }),
        ),
      otaRequestRetries: numberSchema
        .integer()
        .min(0)
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.otaRequestRetriesLabel",
            defaultMessage: "Request Retries",
          }),
        ),
    })
    .required();

const transformOutputData = (data: FormData): UpdateCampaignData => {
  const {
    name,
    baseImage,
    channel,
    maxFailurePercentage,
    maxInProgressUpdates,
    otaRequestRetries,
    otaRequestTimeoutSeconds,
    forceDowngrade,
  } = data;

  return {
    name,
    baseImageId: baseImage.id,
    channelId: channel.id,
    rolloutMechanism: {
      push: {
        maxFailurePercentage:
          typeof maxFailurePercentage === "string"
            ? parseFloat(maxFailurePercentage)
            : maxFailurePercentage,
        maxInProgressUpdates:
          typeof maxInProgressUpdates === "string"
            ? parseInt(maxInProgressUpdates)
            : maxInProgressUpdates,
        otaRequestRetries,
        otaRequestTimeoutSeconds,
        forceDowngrade,
      },
    },
  };
};

type Props = {
  updateCampaignOptionsRef: CreateUpdateCampaign_BaseImageCollOptionsFragment$key &
    CreateUpdateCampaign_ChannelOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: UpdateCampaignData) => void;
};

const CreateUpdateCampaignForm = ({
  updateCampaignOptionsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();

  const {
    control,
    register,
    handleSubmit,
    formState: { errors },
    watch,
    resetField,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(updateCampaignSchema(intl)),
  });

  const selectedBaseImageCollection = watch("baseImageCollection");

  const {
    data: baseImageCollPaginationData,
    loadNext: loadNextBaseImageColls,
    hasNext: hasNextBaseImageColl,
    isLoadingNext: isLoadingNextBaseImageColl,
    refetch: refetchBaseImageColls,
  } = usePaginationFragment<
    CreateUpdateCampaign_BaseImageCollPaginationQuery,
    CreateUpdateCampaign_BaseImageCollOptionsFragment$key
  >(UPDATE_CAMPAIGN_BASE_IMAGE_COLL_OPTIONS_FRAGMENT, updateCampaignOptionsRef);

  const [searchBaseImageCollText, setSearchBaseImageCollText] = useState<
    string | null
  >(null);

  const debounceBaseImageCollRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetchBaseImageColls(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetchBaseImageColls(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetchBaseImageColls],
  );

  useEffect(() => {
    if (searchBaseImageCollText !== null) {
      debounceBaseImageCollRefetch(searchBaseImageCollText);
    }
  }, [debounceBaseImageCollRefetch, searchBaseImageCollText]);

  const loadNextBaseImageCollOptions = useCallback(() => {
    if (hasNextBaseImageColl && !isLoadingNextBaseImageColl) {
      loadNextBaseImageColls(RECORDS_TO_LOAD_NEXT);
    }
  }, [
    hasNextBaseImageColl,
    isLoadingNextBaseImageColl,
    loadNextBaseImageColls,
  ]);

  const baseImageCollections = useMemo(() => {
    return (
      baseImageCollPaginationData.baseImageCollections?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is BaseImageCollectionRecord => node != null) ?? []
    );
  }, [baseImageCollPaginationData]);

  const getBaseImageCollLabel = (
    baseImageCollection: BaseImageCollectionRecord,
  ) => baseImageCollection.name;
  const getBaseImageCollValue = (
    baseImageCollection: BaseImageCollectionRecord,
  ) => baseImageCollection.id;
  const noBaseImageCollOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.CreateUpdateCampaign.noBaseImageCollsFoundMatching",
            defaultMessage:
              'No base image collections found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.CreateUpdateCampaign.noBaseImageCollsAvailable",
          defaultMessage: "No base image collections available",
        });

  const {
    data: channelPaginationData,
    loadNext: loadNextChannels,
    hasNext: hasNextChannel,
    isLoadingNext: isLoadingNextChannel,
    refetch: refetchChannels,
  } = usePaginationFragment<
    CreateUpdateCampaign_ChannelPaginationQuery,
    CreateUpdateCampaign_ChannelOptionsFragment$key
  >(UPDATE_CAMPAIGN_CHANNEL_OPTIONS_FRAGMENT, updateCampaignOptionsRef);

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
            id: "forms.CreateUpdateCampaign.noChannelsFoundMatching",
            defaultMessage: 'No channels found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.CreateUpdateCampaign.noChannelsAvailable",
          defaultMessage: "No channels available",
        });

  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

  const { onChange: onBaseImageCollectionChange } = register(
    "baseImageCollection",
  );

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="create-update-campaign-form-name"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.nameLabel"
              defaultMessage="Name"
            />
          }
        >
          <Form.Control {...register("name")} isInvalid={!!errors.name} />
          <FormFeedback feedback={errors.name?.message} />
        </FormRow>
        <FormRow
          id="create-update-campaign-form-base-image-collection"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.baseImageCollectionLabel"
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
                  id: "forms.CreateUpdateCampaign.baseImageCollectionOption",
                  defaultMessage: "Search or select a base image collection...",
                })}
                options={baseImageCollections}
                getOptionLabel={getBaseImageCollLabel}
                getOptionValue={getBaseImageCollValue}
                noOptionsMessage={({ inputValue }) =>
                  noBaseImageCollOptionsMessage(inputValue)
                }
                isLoading={isLoadingNextBaseImageColl}
                onMenuScrollToBottom={
                  hasNextBaseImageColl
                    ? loadNextBaseImageCollOptions
                    : undefined
                }
                onInputChange={(text) => setSearchBaseImageCollText(text)}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.baseImageCollection && (
              <FormattedMessage id={errors.baseImageCollection?.id?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-update-campaign-form-base-image"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.baseImageLabel"
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
                      value: value,
                      invalid: invalid,
                      onChange: onChange,
                    }}
                  />
                )}
              />
              <Form.Control.Feedback type="invalid">
                {errors.baseImage && (
                  <FormattedMessage id={errors.baseImage?.id?.message} />
                )}
              </Form.Control.Feedback>
            </>
          ) : (
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.CreateUpdateCampaign.selectBaseImageCollection"
                defaultMessage="Select a base image collection..."
              />
            </div>
          )}
        </FormRow>
        <FormRow
          id="create-update-campaign-form-channel"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.channelLabel"
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
                  id: "forms.CreateUpdateCampaign.channelOption",
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
          id="create-update-campaign-form-max-in-progress-updates"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.maxInProgressUpdatesLabel"
              defaultMessage="Max Pending Operations"
            />
          }
        >
          <Form.Control
            {...register("maxInProgressUpdates")}
            type="number"
            min="1"
            isInvalid={!!errors.maxInProgressUpdates}
          />
          <FormFeedback feedback={errors.maxInProgressUpdates?.message} />
        </FormRow>
        <FormRow
          id="create-update-campaign-form-max-failure-percentage"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.maxFailurePercentageLabel"
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
          id="create-update-campaign-form-ota-request-timeout"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.otaRequestTimeoutSecondsLabel"
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
            {...register("otaRequestTimeoutSeconds")}
            type="number"
            min="30"
            isInvalid={!!errors.otaRequestTimeoutSeconds}
          />
          <FormFeedback feedback={errors.otaRequestTimeoutSeconds?.message} />
        </FormRow>
        <FormRow
          id="create-update-campaign-form-ota-request-retries"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.otaRequestRetriesLabel"
              defaultMessage="Request Retries"
            />
          }
        >
          <Form.Control
            {...register("otaRequestRetries")}
            type="number"
            min="0"
            isInvalid={!!errors.otaRequestRetries}
          />
          <FormFeedback feedback={errors.otaRequestRetries?.message} />
        </FormRow>
        <FormRow
          id="create-update-campaign-form-force-downgrade"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.forceDowngradeLabel"
              defaultMessage="Force Downgrade"
            />
          }
        >
          <Form.Check
            type="checkbox"
            {...register("forceDowngrade")}
            isInvalid={!!errors.forceDowngrade}
          />
          <Form.Control.Feedback type="invalid">
            {errors.forceDowngrade?.message && (
              <FormattedMessage id={errors.forceDowngrade.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateUpdateCampaign.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { UpdateCampaignData, BaseImageCollectionRecord };

export default CreateUpdateCampaignForm;
