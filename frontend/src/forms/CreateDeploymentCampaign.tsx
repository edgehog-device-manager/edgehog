/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { useMemo, type ReactNode } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { Controller, useForm } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";
import Select from "react-select";

import type { CreateDeploymentCampaign_OptionsFragment$key } from "api/__generated__/CreateDeploymentCampaign_OptionsFragment.graphql";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { numberSchema, yup } from "forms";
import FormFeedback from "forms/FormFeedback";

const DEPLOYMENT_CAMPAIGN_OPTIONS_FRAGMENT = graphql`
  fragment CreateDeploymentCampaign_OptionsFragment on RootQueryType {
    applications {
      edges {
        node {
          id
          name
          releases {
            edges {
              node {
                id
                version
              }
            }
          }
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

type DeploymentCampaignData = {
  channelId: string;
  releaseId: string;
  name: string;
  deploymentMechanism: {
    lazy: {
      maxFailurePercentage: number;
      maxInProgressDeployments: number;
      createRequestRetries: number;
      requestTimeoutSeconds: number;
    };
  };
};

type FormData = {
  name: string;
  channelId: string;
  applicationId: string;
  releaseId: string;
  maxFailurePercentage: number | string;
  maxInProgressDeployments: number | string;
  createRequestRetries: number;
  requestTimeoutSeconds: number;
};

type SelectOption = {
  value: string;
  label: string;
  disabled?: boolean;
};

const initialData: FormData = {
  name: "",
  channelId: "",
  applicationId: "",
  releaseId: "",
  maxFailurePercentage: "",
  maxInProgressDeployments: "",
  createRequestRetries: 3,
  requestTimeoutSeconds: 300,
};

const transformOutputData = (data: FormData): DeploymentCampaignData => {
  const {
    name,
    channelId,
    releaseId,
    maxFailurePercentage,
    maxInProgressDeployments,
    createRequestRetries,
    requestTimeoutSeconds,
  } = data;

  return {
    name,
    channelId,
    releaseId,
    deploymentMechanism: {
      lazy: {
        maxFailurePercentage:
          typeof maxFailurePercentage === "string"
            ? parseFloat(maxFailurePercentage)
            : maxFailurePercentage,
        maxInProgressDeployments:
          typeof maxInProgressDeployments === "string"
            ? parseInt(maxInProgressDeployments)
            : maxInProgressDeployments,
        createRequestRetries,
        requestTimeoutSeconds,
      },
    },
  };
};

type Props = {
  deploymentCampaignOptionsRef: CreateDeploymentCampaign_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: DeploymentCampaignData) => void;
};

const CreateDeploymentCampaignForm = ({
  deploymentCampaignOptionsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const intl = useIntl();

  const deploymentCampaignSchema = yup
    .object({
      name: yup.string().required(),
      applicationId: yup.string().required(),
      releaseId: yup.string().required(),
      channelId: yup.string().required(),
      maxInProgressDeployments: numberSchema
        .integer()
        .positive()
        .label(
          intl.formatMessage({
            id: "forms.CreateDeploymentCampaign.maxInProgressDeploymentsLabel",
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
      createRequestRetries: numberSchema
        .integer()
        .min(0)
        .label(
          intl.formatMessage({
            id: "forms.CreateDeploymentCampaign.createRequestRetriesLabel",
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
    control,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(deploymentCampaignSchema),
  });

  const { applications, channels } = useFragment(
    DEPLOYMENT_CAMPAIGN_OPTIONS_FRAGMENT,
    deploymentCampaignOptionsRef,
  );

  const onFormSubmit = (data: FormData) => onSubmit(transformOutputData(data));

  const selectedApp = watch("applicationId");

  const applicationOptions: SelectOption[] = useMemo(() => {
    return (
      applications?.edges?.map((app) => ({
        value: app.node.id,
        label: app.node.name,
      })) ?? []
    );
  }, [applications?.edges]);

  const releaseOptions: SelectOption[] = useMemo(() => {
    if (!selectedApp) return [];
    const app = applications?.edges?.find((a) => a.node.id === selectedApp);
    return (
      app?.node?.releases?.edges?.map(({ node }) => ({
        value: node.id,
        label: node.version,
      })) ?? []
    );
  }, [selectedApp, applications?.edges]);

  const channelOptions: SelectOption[] = useMemo(() => {
    return (
      channels?.edges?.map(({ node }) => ({
        value: node.id,
        label: node.name,
      })) ?? []
    );
  }, [channels?.edges]);

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
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
            name="applicationId"
            control={control}
            render={({ field }) => (
              <>
                <Select
                  {...field}
                  value={
                    applicationOptions.find(
                      (opt) => opt.value === field.value,
                    ) || null
                  }
                  onChange={(option) => field.onChange(option?.value || "")}
                  options={applicationOptions}
                  isClearable
                  placeholder={intl.formatMessage({
                    id: "forms.CreateDeploymentCampaign.applicationOption",
                    defaultMessage: "Search or select an application...",
                  })}
                  noOptionsMessage={({ inputValue }) =>
                    inputValue
                      ? intl.formatMessage(
                          {
                            id: "forms.CreateDeploymentCampaign.noApplicationsFoundMatching",
                            defaultMessage:
                              'No applications found matching "{inputValue}"',
                          },
                          { inputValue },
                        )
                      : intl.formatMessage({
                          id: "forms.CreateDeploymentCampaign.noApplicationsAvailable",
                          defaultMessage: "No applications available",
                        })
                  }
                  className={errors.applicationId && "is-invalid"}
                />

                <FormFeedback feedback={errors.applicationId?.message} />
              </>
            )}
          />
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
          <Controller
            name="releaseId"
            control={control}
            render={({ field }) => (
              <>
                <Select
                  {...field}
                  value={
                    releaseOptions.find((opt) => opt.value === field.value) ||
                    null
                  }
                  onChange={(option) => field.onChange(option?.value || "")}
                  options={releaseOptions}
                  isClearable
                  isDisabled={!selectedApp}
                  placeholder={intl.formatMessage({
                    id: "forms.CreateDeploymentCampaign.releaseOption",
                    defaultMessage: "Search or select a release...",
                  })}
                  noOptionsMessage={({ inputValue }) =>
                    inputValue
                      ? intl.formatMessage(
                          {
                            id: "forms.CreateDeploymentCampaign.noReleasesFoundMatching",
                            defaultMessage:
                              'No releases found matching "{inputValue}"',
                          },
                          { inputValue },
                        )
                      : intl.formatMessage({
                          id: "forms.CreateDeploymentCampaign.noReleasesAvailable",
                          defaultMessage: "No releases available",
                        })
                  }
                  className={errors.releaseId && "is-invalid"}
                />

                <FormFeedback feedback={errors.releaseId?.message} />
              </>
            )}
          />
        </FormRow>
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
            name="channelId"
            control={control}
            render={({ field }) => (
              <>
                <Select
                  {...field}
                  value={
                    channelOptions.find((opt) => opt.value === field.value) ||
                    null
                  }
                  onChange={(option) => field.onChange(option?.value || "")}
                  options={channelOptions}
                  isClearable
                  placeholder={intl.formatMessage({
                    id: "forms.CreateDeploymentCampaign.channelOption",
                    defaultMessage: "Search or select a channel...",
                  })}
                  noOptionsMessage={({ inputValue }) =>
                    inputValue
                      ? intl.formatMessage(
                          {
                            id: "forms.CreateDeploymentCampaign.noChannelsFoundMatching",
                            defaultMessage:
                              'No channels found matching "{inputValue}"',
                          },
                          { inputValue },
                        )
                      : intl.formatMessage({
                          id: "forms.CreateDeploymentCampaign.noChannelsAvailable",
                          defaultMessage: "No channels available",
                        })
                  }
                  className={errors.channelId && "is-invalid"}
                />

                <FormFeedback feedback={errors.channelId?.message} />
              </>
            )}
          />
        </FormRow>
        <FormRow
          id="create-deployment-campaign-form-max-in-progress-updates"
          label={
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.maxInProgressDeploymentsLabel"
              defaultMessage="Max Pending Operations"
            />
          }
        >
          <Form.Control
            {...register("maxInProgressDeployments")}
            type="number"
            min="1"
            isInvalid={!!errors.maxInProgressDeployments}
          />
          <FormFeedback feedback={errors.maxInProgressDeployments?.message} />
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
              id="forms.CreateDeploymentCampaign.createRequestRetriesLabel"
              defaultMessage="Request Retries"
            />
          }
        >
          <Form.Control
            {...register("createRequestRetries")}
            type="number"
            min="0"
            isInvalid={!!errors.createRequestRetries}
          />
          <FormFeedback feedback={errors.createRequestRetries?.message} />
        </FormRow>

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateDeploymentCampaign.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { DeploymentCampaignData };

export default CreateDeploymentCampaignForm;
