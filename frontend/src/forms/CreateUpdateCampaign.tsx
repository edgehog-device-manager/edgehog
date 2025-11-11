/*
  This file is part of Edgehog.

  Copyright 2023 - 2025 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { useForm } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";

import BaseImageSelect from "components/BaseImageSelect";
import Button from "components/Button";
import Form from "components/Form";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { FormRow } from "components/FormRow";
import { numberSchema, yup } from "forms";
import FormFeedback from "forms/FormFeedback";

import type { CreateUpdateCampaign_OptionsFragment$key } from "api/__generated__/CreateUpdateCampaign_OptionsFragment.graphql";

const UPDATE_CAMPAIGN_OPTIONS_FRAGMENT = graphql`
  fragment CreateUpdateCampaign_OptionsFragment on RootQueryType {
    baseImageCollections {
      edges {
        node {
          id
          name
        }
      }
    }
    channels {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

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
  channelId: string;
  baseImageCollectionId: string;
  baseImageId: string;
  maxFailurePercentage: number | string;
  maxInProgressUpdates: number | string;
  otaRequestRetries: number;
  otaRequestTimeoutSeconds: number;
  forceDowngrade: boolean;
};

const initialData: FormData = {
  name: "",
  channelId: "",
  baseImageCollectionId: "",
  baseImageId: "",
  maxFailurePercentage: "",
  maxInProgressUpdates: "",
  otaRequestRetries: 3,
  otaRequestTimeoutSeconds: 300,
  forceDowngrade: false,
};

const transformOutputData = (data: FormData): UpdateCampaignData => {
  const {
    name,
    baseImageId,
    channelId,
    maxFailurePercentage,
    maxInProgressUpdates,
    otaRequestRetries,
    otaRequestTimeoutSeconds,
    forceDowngrade,
  } = data;

  return {
    name,
    baseImageId,
    channelId,
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
  updateCampaignOptionsRef: CreateUpdateCampaign_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: UpdateCampaignData) => void;
};

const CreateBaseImageCollectionForm = ({
  updateCampaignOptionsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();

  const updateCampaignSchema = yup
    .object({
      name: yup.string().required(),
      baseImageCollectionId: yup.string().required(),
      baseImageId: yup.string().required(),
      channelId: yup.string().required(),
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

  const {
    register,
    handleSubmit,
    formState: { errors },
    watch,
    resetField,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(updateCampaignSchema),
  });

  const baseImageCollectionId = watch("baseImageCollectionId");

  const { baseImageCollections, channels } = useFragment(
    UPDATE_CAMPAIGN_OPTIONS_FRAGMENT,
    updateCampaignOptionsRef,
  );

  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

  const {
    onChange: onBaseImageCollectionChange,
    ...baseImageCollectionFieldProps
  } = register("baseImageCollectionId");

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
          <Form.Select
            {...baseImageCollectionFieldProps}
            onChange={(e) => {
              onBaseImageCollectionChange(e);
              resetField("baseImageId");
            }}
            isInvalid={!!errors.baseImageCollectionId}
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "forms.CreateUpdateCampaign.baseImageCollectionOption",
                defaultMessage: "Select a Base Image Collection",
              })}
            </option>
            {baseImageCollections?.edges?.map(
              ({ node: baseImageCollection }) => (
                <option
                  key={baseImageCollection.id}
                  value={baseImageCollection.id}
                >
                  {baseImageCollection.name}
                </option>
              ),
            )}
          </Form.Select>
          <FormFeedback feedback={errors.baseImageCollectionId?.message} />
        </FormRow>
        <FormRow
          id="create-update-campaign-form-base-image"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.baseImageLabel"
              defaultMessage="Base Image"
            />
          }
        >
          <BaseImageSelect
            baseImageCollectionId={baseImageCollectionId}
            {...register("baseImageId")}
            isInvalid={!!errors.baseImageId}
          />
          <FormFeedback feedback={errors.baseImageId?.message} />
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
          <Form.Select
            {...register("channelId")}
            isInvalid={!!errors.channelId}
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "forms.CreateUpdateCampaign.channelOption",
                defaultMessage: "Select a Channel",
              })}
            </option>
            {channels?.edges?.map(({ node: channel }) => (
              <option key={channel.id} value={channel.id}>
                {channel.name}
              </option>
            ))}
          </Form.Select>
          <FormFeedback feedback={errors.channelId?.message} />
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
              id="froms.CreateUpdateCampaign.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { UpdateCampaignData };

export default CreateBaseImageCollectionForm;
