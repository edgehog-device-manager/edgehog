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

import { ReactNode, useCallback, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment, useMutation } from "react-relay/hooks";

import type {
  DeploymentCampaignForm_CampaignFragment$data,
  DeploymentCampaignForm_CampaignFragment$key,
} from "@/api/__generated__/DeploymentCampaignForm_CampaignFragment.graphql";
import { DeploymentCampaignForm_IncreaseMaxInProgressOperations_Mutation } from "@/api/__generated__/DeploymentCampaignForm_IncreaseMaxInProgressOperations_Mutation.graphql";

import Col from "@/components/Col";
import Row from "@/components/Row";
import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import { SimpleFormRow as FormRow } from "@/components/FormRow";
import Form from "@/components/Form";
import Button from "@/components/Button";
import Icon from "@/components/Icon";
import { campaignUpdateSchema, messages } from "@/forms/validation";
import { Link, Route } from "@/Navigation";
import { OperationType } from "./CreateDeploymentCampaign";
import FormFeedback from "./FormFeedback";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment DeploymentCampaignForm_CampaignFragment on Campaign {
    id
    ...CampaignStatus_CampaignStatusFragment
    ...CampaignOutcome_CampaignOutcomeFragment
    channel {
      id
      name
    }
    campaignMechanism {
      __typename
      ... on DeploymentDeploy {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentStart {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentStop {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentDelete {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentUpgrade {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
        targetRelease {
          id
          version
        }
      }
    }
  }
`;

const INCREASE_MAX_IN_PROGRESS_OPERATIONS_MUTATION = graphql`
  mutation DeploymentCampaignForm_IncreaseMaxInProgressOperations_Mutation(
    $campaignId: ID!
    $input: IncreaseMaxInProgressOperationsInput!
  ) {
    increaseMaxInProgressOperations(id: $campaignId, input: $input) {
      result {
        id
        ...CampaignStatus_CampaignStatusFragment
        ...CampaignOutcome_CampaignOutcomeFragment
        channel {
          id
          name
        }
        campaignMechanism {
          __typename
          ... on DeploymentDeploy {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentStart {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentStop {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentDelete {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentUpgrade {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
              application {
                id
                name
              }
            }
            targetRelease {
              id
              version
            }
          }
        }
      }
    }
  }
`;

const MECHANISM_TO_OPERATION: Record<string, OperationType> = {
  DeploymentDeploy: "Deploy",
  DeploymentStart: "Start",
  DeploymentStop: "Stop",
  DeploymentUpgrade: "Upgrade",
  DeploymentDelete: "Delete",
};

type CampaignMechanism = {
  __typename:
    | "DeploymentDeploy"
    | "DeploymentStart"
    | "DeploymentStop"
    | "DeploymentUpgrade"
    | "DeploymentDelete";
  maxFailurePercentage: number;
  maxInProgressOperations: number;
  release: {
    application: {
      id: string;
      name: string;
    } | null;
    id: string;
    version: string;
  } | null;
  requestRetries: number;
  requestTimeoutSeconds: number;
  targetRelease?: {
    id: string;
    version: string;
  };
};

type CampaignMechanismColContentProps = {
  campaignId: string;
  campaignMechanism: CampaignMechanism;
  setErrorFeedback: (e: ReactNode) => void;
};

const CampaignMechanismColContent = ({
  campaignId,
  campaignMechanism,
  setErrorFeedback,
}: CampaignMechanismColContentProps) => {
  const intl = useIntl();

  const [increaseMaxInProgressOperations, isIncreasingMaxInProgressOperations] =
    useMutation<DeploymentCampaignForm_IncreaseMaxInProgressOperations_Mutation>(
      INCREASE_MAX_IN_PROGRESS_OPERATIONS_MUTATION,
    );

  const [originalMaxInProgOperations, setOriginalMaxInProgOperations] =
    useState(campaignMechanism.maxInProgressOperations);

  const [maxInProgOperations, setMaxInProgOperations] = useState(
    campaignMechanism.maxInProgressOperations,
  );

  const [isEditingValue, setIsEditingValue] = useState(false);

  const [validationError, setValidationError] = useState<string | null>(null);

  const [isValidMaxInProgOpsInput, setIsValidMaxInProgOpsInput] =
    useState(true);

  const handleMaxInProgOperationsChange = (
    e: React.ChangeEvent<HTMLInputElement>,
  ) => {
    const input = Number(e.target.value);

    validateMaxInProgOpsInput(input);
    setMaxInProgOperations(input);
  };

  const validateMaxInProgOpsInput = (maxInProgOperations: number) => {
    const parseResult = campaignUpdateSchema.safeParse(maxInProgOperations);
    if (parseResult.success) {
      if (
        originalMaxInProgOperations &&
        maxInProgOperations >= originalMaxInProgOperations
      ) {
        setIsValidMaxInProgOpsInput(true);
        setValidationError("");
      } else {
        setIsValidMaxInProgOpsInput(false);
        setValidationError(messages.numberMin.id);
      }
    } else {
      setIsValidMaxInProgOpsInput(false);
      setValidationError(parseResult.error.issues[0].message);
    }
  };

  const handleUpdateMaxInProgOperations = useCallback(() => {
    setIsEditingValue(false);
    increaseMaxInProgressOperations({
      variables: {
        campaignId: campaignId,
        input: { maxInProgressOperations: maxInProgOperations },
      },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          return setErrorFeedback(errorFeedback);
        }
        setOriginalMaxInProgOperations(maxInProgOperations);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="forms.DeploymentCampaignForm.increaseMaxPendOpsErrorFeedback"
            defaultMessage="Could not increase Max Pending Operations, please try again."
          />,
        );
      },
    });
  }, [increaseMaxInProgressOperations, campaignId, maxInProgOperations]);

  const handleCancelEditMaxInProgOperations = () => {
    setMaxInProgOperations(originalMaxInProgOperations);
    setIsValidMaxInProgOpsInput(true);
    setValidationError(null);
    setIsEditingValue(false);
  };

  return (
    <Col lg>
      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.maxInProgressOperations"
            defaultMessage="Max Pending Operations"
          />
        }
      >
        <div
          className={`d-flex align-items-center ${isIncreasingMaxInProgressOperations ? "pe-none" : ""}`}
        >
          <div>
            <Form.Control
              type="text"
              value={maxInProgOperations}
              readOnly={!isEditingValue}
              min={originalMaxInProgOperations}
              isInvalid={!isValidMaxInProgOpsInput}
              onChange={handleMaxInProgOperationsChange}
              className="p-0"
              style={{ width: "4em" }}
            />
            {validationError && (
              <FormFeedback
                feedback={{
                  messageId: validationError,
                  values: { min: originalMaxInProgOperations },
                }}
              />
            )}
          </div>

          {isEditingValue ? (
            <>
              <Button
                type="submit"
                className="border-0 bg-transparent p-0 px-2"
                disabled={!isValidMaxInProgOpsInput}
                onClick={handleUpdateMaxInProgOperations}
              >
                <Icon icon="check" className="text-success" />
              </Button>
              <Icon
                icon="xMark"
                className="text-danger"
                role="button"
                onClick={handleCancelEditMaxInProgOperations}
              />
            </>
          ) : (
            <Icon
              icon="edit"
              className="text-secondary px-2"
              role="button"
              onClick={() => setIsEditingValue(true)}
              title={intl.formatMessage({
                id: "forms.DeploymentCampaignForm.increaseMaxInProgressOperations",
                defaultMessage: "Increase Max Pending Operations",
              })}
            />
          )}
        </div>
      </FormRow>

      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.campaignMechanism.maxFailurePercentageLabel"
            defaultMessage="Max Failures <muted>(%)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {campaignMechanism.maxFailurePercentage}
      </FormRow>

      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.campaignMechanism.requestTimeoutSeconds"
            defaultMessage="Request Timeout <muted>(seconds)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {campaignMechanism.requestTimeoutSeconds}
      </FormRow>

      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.requestRetries"
            defaultMessage="Request Retries"
          />
        }
      >
        {campaignMechanism.requestRetries}
      </FormRow>
    </Col>
  );
};

type CampaignMechanismColProps = {
  campaignId: string;
  campaignMechanismData: DeploymentCampaignForm_CampaignFragment$data["campaignMechanism"];
  setErrorFeedback: (e: ReactNode) => void;
};

const CampaignMechanismCol = ({
  campaignId,
  campaignMechanismData,
  setErrorFeedback,
}: CampaignMechanismColProps) => {
  if (campaignMechanismData.__typename === "%other") {
    return null;
  }

  // TODO: handle readonly type without mapping to mutable type
  const campaignMechanism =
    campaignMechanismData &&
    ({
      ...campaignMechanismData,
      release: {
        ...campaignMechanismData.release,
        application: { ...campaignMechanismData.release?.application },
      },
      targetRelease: campaignMechanismData.__typename ===
        "DeploymentUpgrade" && { ...campaignMechanismData.targetRelease },
    } as CampaignMechanism);

  return (
    <CampaignMechanismColContent
      campaignId={campaignId}
      campaignMechanism={campaignMechanism}
      setErrorFeedback={setErrorFeedback}
    ></CampaignMechanismColContent>
  );
};

type DeploymentCampaignProps = {
  campaignRef: DeploymentCampaignForm_CampaignFragment$key;
  setErrorFeedback: (e: ReactNode) => void;
};

const DeploymentCampaign = ({
  campaignRef,
  setErrorFeedback,
}: DeploymentCampaignProps) => {
  const campaign = useFragment(CAMPAIGN_FORM_FRAGMENT, campaignRef);

  const { channel, campaignMechanism } = campaign;

  const operationType = MECHANISM_TO_OPERATION[campaignMechanism.__typename];

  const release =
    "release" in campaignMechanism ? campaignMechanism.release : null;

  const targetRelease =
    campaignMechanism.__typename === "DeploymentUpgrade"
      ? campaignMechanism.targetRelease
      : null;

  return (
    <Row>
      <Col lg>
        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.operationTypeLabel"
              defaultMessage="Operation Type"
            />
          }
        >
          {operationType}
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.statusLabel"
              defaultMessage="Status"
            />
          }
        >
          <CampaignStatus campaignRef={campaign} />
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.outcomeLabel"
              defaultMessage="Outcome"
            />
          }
        >
          <CampaignOutcome campaignRef={campaign} />
        </FormRow>

        {release?.application && (
          <>
            <FormRow
              label={
                <FormattedMessage
                  id="forms.DeploymentCampaignForm.applicationLabel"
                  defaultMessage="Application"
                />
              }
            >
              <Link
                route={Route.application}
                params={{ applicationId: release.application.id }}
              >
                {release.application.name}
              </Link>
            </FormRow>

            <FormRow
              label={
                <FormattedMessage
                  id="forms.DeploymentCampaignForm.releaseLabel"
                  defaultMessage="Release"
                />
              }
            >
              <Link
                route={Route.release}
                params={{
                  applicationId: release.application.id,
                  releaseId: release.id,
                }}
              >
                {release.version}
              </Link>
            </FormRow>
          </>
        )}

        {campaignMechanism.__typename === "DeploymentUpgrade" &&
          targetRelease &&
          release?.application && (
            <FormRow
              label={
                <FormattedMessage
                  id="forms.DeploymentCampaignForm.targetReleaseLabel"
                  defaultMessage="Target Release"
                />
              }
            >
              <Link
                route={Route.release}
                params={{
                  applicationId: release?.application.id ?? "",
                  releaseId: targetRelease.id,
                }}
              >
                {targetRelease.version}
              </Link>
            </FormRow>
          )}

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.channelLabel"
              defaultMessage="Channel"
            />
          }
        >
          <Link route={Route.channelsEdit} params={{ channelId: channel.id }}>
            {channel.name}
          </Link>
        </FormRow>
      </Col>

      <CampaignMechanismCol
        campaignId={campaign.id}
        campaignMechanismData={campaignMechanism}
        setErrorFeedback={setErrorFeedback}
      />
    </Row>
  );
};

export default DeploymentCampaign;
