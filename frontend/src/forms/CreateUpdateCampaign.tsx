/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import type { ReactNode } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { useForm } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";

import BaseImageSelect from "components/BaseImageSelect";
import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { numberSchema, yup } from "forms";
import FormFeedback from "forms/FormFeedback";

import type { CreateUpdateCampaign_OptionsFragment$key } from "api/__generated__/CreateUpdateCampaign_OptionsFragment.graphql";

const UPDATE_CAMPAIGN_OPTIONS_FRAGMENT = graphql`
  fragment CreateUpdateCampaign_OptionsFragment on RootQueryType {
    baseImageCollections {
      id
      name
    }
    updateChannels {
      id
      name
    }
  }
`;

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label?: ReactNode;
  children: ReactNode;
}) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

type UpdateCampaignData = {
  updateChannelId: string;
  baseImageId: string;
  name: string;
  rolloutMechanism: {
    push: {
      maxErrorsPercentage: number;
      maxInProgressUpdates: number;
      otaRequestRetries: number;
      otaRequestTimeoutSeconds: number;
      forceDowngrade: boolean;
    };
  };
};

type FormData = {
  name: string;
  updateChannelId: string;
  baseImageCollectionId: string;
  baseImageId: string;
  maxErrorsPercentage: number | string;
  maxInProgressUpdates: number | string;
  otaRequestRetries: number;
  otaRequestTimeoutSeconds: number;
  forceDowngrade: boolean;
};

const initialData: FormData = {
  name: "",
  updateChannelId: "",
  baseImageCollectionId: "",
  baseImageId: "",
  maxErrorsPercentage: "",
  maxInProgressUpdates: "",
  otaRequestRetries: 0,
  otaRequestTimeoutSeconds: 60,
  forceDowngrade: false,
};

const transformOutputData = (data: FormData): UpdateCampaignData => {
  const {
    name,
    baseImageId,
    updateChannelId,
    maxErrorsPercentage,
    maxInProgressUpdates,
    otaRequestRetries,
    otaRequestTimeoutSeconds,
    forceDowngrade,
  } = data;

  return {
    name,
    baseImageId,
    updateChannelId,
    rolloutMechanism: {
      push: {
        maxErrorsPercentage:
          typeof maxErrorsPercentage === "string"
            ? parseFloat(maxErrorsPercentage)
            : maxErrorsPercentage,
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
      updateChannelId: yup.string().required(),
      maxInProgressUpdates: numberSchema
        .integer()
        .positive()
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.maxInProgressUpdatesLabel",
            defaultMessage: "Max Pending Operations",
          })
        ),
      maxErrorsPercentage: numberSchema
        .min(0)
        .max(100)
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.maxErrorsPercentageValidationLabel",
            defaultMessage: "Max Errors",
          })
        ),
      otaRequestTimeoutSeconds: numberSchema
        .positive()
        .integer()
        .min(30)
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.otaRequestTimeoutSecondsValidationLabel",
            defaultMessage: "Request Timeout",
          })
        ),
      otaRequestRetries: numberSchema
        .integer()
        .min(0)
        .label(
          intl.formatMessage({
            id: "forms.CreateUpdateCampaign.otaRequestRetriesLabel",
            defaultMessage: "Request Retries",
          })
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

  const { baseImageCollections, updateChannels } = useFragment(
    UPDATE_CAMPAIGN_OPTIONS_FRAGMENT,
    updateCampaignOptionsRef
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
            {baseImageCollections.map((baseImageCollection) => (
              <option
                key={baseImageCollection.id}
                value={baseImageCollection.id}
              >
                {baseImageCollection.name}
              </option>
            ))}
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
          id="create-update-campaign-form-update-channel"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.updateChannelLabel"
              defaultMessage="Update Channel"
            />
          }
        >
          <Form.Select
            {...register("updateChannelId")}
            isInvalid={!!errors.updateChannelId}
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "forms.CreateUpdateCampaign.updateChannelOption",
                defaultMessage: "Select an Update Channel",
              })}
            </option>
            {updateChannels.map((updateChannel) => (
              <option key={updateChannel.id} value={updateChannel.id}>
                {updateChannel.name}
              </option>
            ))}
          </Form.Select>
          <FormFeedback feedback={errors.updateChannelId?.message} />
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
          id="create-update-campaign-form-max-errors-percentage"
          label={
            <FormattedMessage
              id="forms.CreateUpdateCampaign.maxErrorsPercentageLabel"
              defaultMessage="Max Errors <muted>(%)</muted>"
              values={{
                muted: (chunks: React.ReactNode) => (
                  <span className="small text-muted">{chunks}</span>
                ),
              }}
            />
          }
        >
          <Form.Control
            {...register("maxErrorsPercentage")}
            type="number"
            min="0"
            max="100"
            isInvalid={!!errors.maxErrorsPercentage}
          />
          <FormFeedback feedback={errors.maxErrorsPercentage?.message} />
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
        <FormRow id="create-update-campaign-form-force-downgrade">
          <Form.Check
            {...register("forceDowngrade")}
            label={
              <FormattedMessage
                id="forms.CreateUpdateCampaign.forceDowngradeLabel"
                defaultMessage="Force Downgrade"
              />
            }
          />
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
