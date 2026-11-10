// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { Suspense, useEffect, useMemo } from "react";
import { Button, Card, Spinner } from "react-bootstrap";
import { defineMessages, FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery, useSubscription } from "react-relay";

import type { UpgradeProgressBanner_getDeployment_Query } from "@/api/__generated__/UpgradeProgressBanner_getDeployment_Query.graphql";
import type { UpgradeProgressBanner_deployment_updated_Subscription } from "@/api/__generated__/UpgradeProgressBanner_deployment_updated_Subscription.graphql";

import Icon from "@/components/ui/icon/Icon";
import Alert from "@/components/ui/alert/Alert";
import { Route, useNavigate } from "@/Navigation";

import "@/components/apps/deployments/upgrade-progress-banner/UpgradeProgressBanner.scss";

/* eslint-disable relay/unused-fields */
const UPGRADE_PROGRESS_BANNER_QUERY = graphql`
  query UpgradeProgressBanner_getDeployment_Query($id: ID!) {
    deployment(id: $id) {
      id
      state
      isReady
      timedOut
      release {
        version
      }
      events(first: 5, sort: [{ field: INSERTED_AT, order: DESC }]) {
        edges {
          node {
            type
            message
          }
        }
      }
    }
  }
`;

const UPGRADE_PROGRESS_BANNER_SUBSCRIPTION = graphql`
  subscription UpgradeProgressBanner_deployment_updated_Subscription(
    $deploymentId: ID!
  ) {
    deploymentById(deploymentId: $deploymentId) {
      updated {
        id
        state
        isReady
        timedOut
        events(first: 5, sort: [{ field: INSERTED_AT, order: DESC }]) {
          edges {
            node {
              type
              message
            }
          }
        }
      }
    }
  }
`;

const messages = defineMessages({
  upgradingTitle: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.upgradingTitle",
    defaultMessage: "Upgrading application: v{fromVersion} → v{toVersion}",
  },
  stepPreparing: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.stepPreparing",
    defaultMessage: "Preparing new deployment",
  },
  stepStopping: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.stepStopping",
    defaultMessage: "Stopping previous deployment",
  },
  stepStarting: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.stepStarting",
    defaultMessage: "Starting new deployment",
  },
  pleaseWait: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.pleaseWait",
    defaultMessage: "Please wait while the upgrade completes...",
  },
  successTitle: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.successTitle",
    defaultMessage: "Upgrade completed successfully!",
  },
  runningVersionNotice: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.runningVersionNotice",
    defaultMessage: "Your application is now running v{toVersion}.",
  },
  summaryPreviousStopped: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.summaryPreviousStopped",
    defaultMessage: "Previous deployment stopped",
  },
  summaryNewStarted: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.summaryNewStarted",
    defaultMessage: "New deployment started",
  },
  summaryUpgradeCompleted: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.summaryUpgradeCompleted",
    defaultMessage: "Upgrade completed",
  },
  viewNewDeployment: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.viewNewDeployment",
    defaultMessage: "View new deployment",
  },
  upgradeFailedTitle: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.upgradeFailedTitle",
    defaultMessage: "Upgrade failed",
  },
  targetNotFoundTitle: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.targetNotFoundTitle",
    defaultMessage: "Upgrade target deployment not found",
  },
  targetNotFoundDescription: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.targetNotFoundDescription",
    defaultMessage:
      "The new deployment for this upgrade was deleted or could not be found.",
  },
  dismiss: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.dismiss",
    defaultMessage: "Dismiss",
  },
  upgradeAvailableInfo: {
    id: "components.apps.deployments.upgrade-progress-banner.UpgradeProgressBanner.upgradeAvailableInfo",
    defaultMessage:
      "This application has been upgraded to version {toVersion}.",
  },
});

type UpgradeProgressBannerContentProps = {
  targetDeployment: NonNullable<
    UpgradeProgressBanner_getDeployment_Query["response"]["deployment"]
  > | null;
  targetDeploymentId: string;
  currentDeploymentState: string | null | undefined;
  fromVersion: string;
  toVersion: string;
  deviceId: string;
  isInfoOnly?: boolean;
  onDismiss?: () => void;
  onViewNewDeployment?: () => void;
  onUpgradeComplete?: () => void;
  onUpgradeFailed?: () => void;
  onTargetNotFound?: () => void;
};

const UpgradeProgressBannerContent = ({
  targetDeployment,
  targetDeploymentId,
  currentDeploymentState,
  fromVersion,
  toVersion,
  deviceId,
  isInfoOnly,
  onDismiss,
  onViewNewDeployment,
  onUpgradeComplete,
  onUpgradeFailed,
  onTargetNotFound,
}: UpgradeProgressBannerContentProps) => {
  const intl = useIntl();
  const navigate = useNavigate();

  const effectiveToVersion =
    targetDeployment?.release?.version ?? toVersion ?? "";

  const isFailed =
    Boolean(targetDeployment?.timedOut) ||
    Boolean(
      targetDeployment?.events?.edges?.some((e) => e?.node?.type === "ERROR"),
    );

  const latestErrorMessage =
    targetDeployment?.events?.edges?.find((e) => e?.node?.type === "ERROR")
      ?.node?.message ?? null;

  const isPreparingCompleted = targetDeployment?.isReady === true;

  const isPreviousStopped = currentDeploymentState === "STOPPED";
  const isStoppingCompleted = isPreparingCompleted && isPreviousStopped;
  const isStoppingInProgress =
    isPreparingCompleted && !isPreviousStopped && !isFailed;

  const isNewStarted = targetDeployment?.state === "STARTED";
  const isStartingCompleted = isStoppingCompleted && isNewStarted;
  const isStartingInProgress =
    isStoppingCompleted && !isNewStarted && !isFailed;

  const isCompleted =
    isPreparingCompleted && isStoppingCompleted && isStartingCompleted;

  useEffect(() => {
    if (!targetDeployment) {
      onTargetNotFound?.();
    } else if (isCompleted) {
      onUpgradeComplete?.();
    } else if (isFailed) {
      onUpgradeFailed?.();
    }
  }, [
    targetDeployment,
    isCompleted,
    isFailed,
    onTargetNotFound,
    onUpgradeComplete,
    onUpgradeFailed,
  ]);

  if (!targetDeployment) {
    return (
      <Card className="upgrade-progress-banner is-failed mb-4 shadow-sm">
        <Card.Body>
          <div className="d-flex align-items-center justify-content-between mb-2">
            <div className="d-flex align-items-center gap-2">
              <Icon icon="warning" className="text-danger" />
              <h5 className="mb-0 text-danger fw-semibold">
                <FormattedMessage {...messages.targetNotFoundTitle} />
              </h5>
            </div>
            {onDismiss && (
              <Button
                variant="link"
                className="p-0 text-muted"
                onClick={onDismiss}
                title={intl.formatMessage(messages.dismiss)}
              >
                <Icon icon="xMark" />
              </Button>
            )}
          </div>
          <p className="text-muted small mb-3">
            <FormattedMessage {...messages.targetNotFoundDescription} />
          </p>
        </Card.Body>
      </Card>
    );
  }

  if (isFailed) {
    return (
      <Card className="upgrade-progress-banner is-failed mb-4 shadow-sm">
        <Card.Body>
          <div className="d-flex align-items-center justify-content-between mb-2">
            <div className="d-flex align-items-center gap-2">
              <Icon icon="warning" className="text-danger" />
              <h5 className="mb-0 text-danger fw-semibold">
                <FormattedMessage {...messages.upgradeFailedTitle} />
              </h5>
            </div>
            {onDismiss && (
              <Button
                variant="link"
                className="p-0 text-muted"
                onClick={onDismiss}
                title={intl.formatMessage(messages.dismiss)}
              >
                <Icon icon="xMark" />
              </Button>
            )}
          </div>
          {latestErrorMessage && (
            <p className="text-danger small mb-3">{latestErrorMessage}</p>
          )}
          {onDismiss && (
            <Button variant="outline-danger" size="sm" onClick={onDismiss}>
              <FormattedMessage {...messages.dismiss} />
            </Button>
          )}
        </Card.Body>
      </Card>
    );
  }

  if (isInfoOnly) {
    return (
      <Alert
        variant="success"
        dismissible={Boolean(onDismiss)}
        onClose={onDismiss}
        className="upgrade-info-banner mb-4 shadow-sm"
        data-testid="upgrade-info-banner"
      >
        <div className="d-flex align-items-center gap-2">
          <Icon
            icon="info"
            size="1.25em"
            className="text-success flex-shrink-0"
          />
          <span>
            <FormattedMessage
              {...messages.upgradeAvailableInfo}
              values={{
                toVersion: (
                  <span
                    role="link"
                    tabIndex={0}
                    className="text-primary text-decoration-underline"
                    style={{ cursor: "pointer" }}
                    onClick={() =>
                      navigate({
                        route: Route.deploymentEdit,
                        params: { deviceId, deploymentId: targetDeploymentId },
                      })
                    }
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        navigate({
                          route: Route.deploymentEdit,
                          params: {
                            deviceId,
                            deploymentId: targetDeploymentId,
                          },
                        });
                      }
                    }}
                  >
                    {effectiveToVersion}
                  </span>
                ),
              }}
            />
          </span>
        </div>
      </Alert>
    );
  }

  if (isCompleted) {
    return (
      <Card className="upgrade-progress-banner is-completed mb-4 shadow-sm">
        <Card.Body>
          <div className="d-flex align-items-center justify-content-between mb-2">
            <div className="d-flex align-items-center gap-2">
              <Icon icon="check" className="text-success" />
              <h5 className="mb-0 text-success fw-semibold">
                <FormattedMessage {...messages.successTitle} />
              </h5>
            </div>
            {onDismiss && (
              <Button
                variant="link"
                className="p-0 text-muted"
                onClick={onDismiss}
                title={intl.formatMessage(messages.dismiss)}
              >
                <Icon icon="xMark" />
              </Button>
            )}
          </div>

          <p className="text-muted mb-3">
            <FormattedMessage
              {...messages.runningVersionNotice}
              values={{ toVersion }}
            />
          </p>

          <div className="version-transition-badge text-muted mb-3">
            <span>{`v${fromVersion}`}</span>
            <Icon icon="arrowRight" size="0.9em" />
            <span className="text-dark">{`v${toVersion}`}</span>
          </div>

          <div className="upgrade-steps-list mb-3">
            <div className="upgrade-step-item is-completed">
              <span className="step-icon-wrapper">
                <Icon icon="check" className="text-success" />
              </span>
              <span>
                <FormattedMessage {...messages.summaryPreviousStopped} />
              </span>
            </div>
            <div className="upgrade-step-item is-completed">
              <span className="step-icon-wrapper">
                <Icon icon="check" className="text-success" />
              </span>
              <span>
                <FormattedMessage {...messages.summaryNewStarted} />
              </span>
            </div>
            <div className="upgrade-step-item is-completed">
              <span className="step-icon-wrapper">
                <Icon icon="check" className="text-success" />
              </span>
              <span>
                <FormattedMessage {...messages.summaryUpgradeCompleted} />
              </span>
            </div>
          </div>

          <div>
            <Button
              variant="primary"
              className="d-inline-flex align-items-center gap-2"
              onClick={() => {
                onViewNewDeployment?.();
                navigate({
                  route: Route.deploymentEdit,
                  params: { deviceId, deploymentId: targetDeploymentId },
                });
              }}
            >
              <FormattedMessage {...messages.viewNewDeployment} />
            </Button>
          </div>
        </Card.Body>
      </Card>
    );
  }

  return (
    <Card className="upgrade-progress-banner mb-4 shadow-sm">
      <Card.Body>
        <div className="d-flex align-items-center justify-content-between mb-3">
          <div className="d-flex align-items-center gap-2">
            <Icon icon="spinner" className="text-primary spin-animation" />
            <h5 className="mb-0 fw-semibold">
              <FormattedMessage
                {...messages.upgradingTitle}
                values={{ fromVersion, toVersion }}
              />
            </h5>
          </div>
          {onDismiss && (
            <Button
              variant="link"
              className="p-0 text-muted"
              onClick={onDismiss}
              title={intl.formatMessage(messages.dismiss)}
            >
              <Icon icon="xMark" />
            </Button>
          )}
        </div>

        <div className="upgrade-steps-list mb-3">
          <div
            data-testid="step-preparing"
            className={`upgrade-step-item ${
              isPreparingCompleted ? "is-completed" : "is-in-progress"
            }`}
          >
            <span className="step-icon-wrapper">
              {isPreparingCompleted ? (
                <Icon icon="check" className="text-success" />
              ) : (
                <Icon icon="spinner" className="text-primary spin-animation" />
              )}
            </span>
            <span>
              <FormattedMessage {...messages.stepPreparing} />
            </span>
          </div>

          <div
            data-testid="step-stopping"
            className={`upgrade-step-item ${
              isStoppingCompleted
                ? "is-completed"
                : isStoppingInProgress
                  ? "is-in-progress"
                  : "is-pending"
            }`}
          >
            <span className="step-icon-wrapper">
              {isStoppingCompleted ? (
                <Icon icon="check" className="text-success" />
              ) : isStoppingInProgress ? (
                <Icon icon="spinner" className="text-primary spin-animation" />
              ) : (
                <Icon icon="empty" className="text-muted" />
              )}
            </span>
            <span>
              <FormattedMessage {...messages.stepStopping} />
            </span>
          </div>

          <div
            data-testid="step-starting"
            className={`upgrade-step-item ${
              isStartingCompleted
                ? "is-completed"
                : isStartingInProgress
                  ? "is-in-progress"
                  : "is-pending"
            }`}
          >
            <span className="step-icon-wrapper">
              {isStartingCompleted ? (
                <Icon icon="check" className="text-success" />
              ) : isStartingInProgress ? (
                <Icon icon="spinner" className="text-primary spin-animation" />
              ) : (
                <Icon icon="empty" className="text-muted" />
              )}
            </span>
            <span>
              <FormattedMessage {...messages.stepStarting} />
            </span>
          </div>
        </div>

        <div className="text-muted small">
          <FormattedMessage {...messages.pleaseWait} />
        </div>
      </Card.Body>
    </Card>
  );
};

type UpgradeProgressBannerProps = {
  targetDeploymentId: string;
  currentDeploymentState: string | null | undefined;
  fromVersion: string;
  toVersion: string;
  deviceId: string;
  isInfoOnly?: boolean;
  onDismiss?: () => void;
  onViewNewDeployment?: () => void;
  onUpgradeComplete?: () => void;
  onUpgradeFailed?: () => void;
  onTargetNotFound?: () => void;
};

const UpgradeProgressBannerQueryLoader = (
  props: UpgradeProgressBannerProps,
) => {
  const data = useLazyLoadQuery<UpgradeProgressBanner_getDeployment_Query>(
    UPGRADE_PROGRESS_BANNER_QUERY,
    { id: props.targetDeploymentId },
    { fetchPolicy: "store-and-network" },
  );

  useSubscription<UpgradeProgressBanner_deployment_updated_Subscription>(
    useMemo(
      () => ({
        subscription: UPGRADE_PROGRESS_BANNER_SUBSCRIPTION,
        variables: { deploymentId: props.targetDeploymentId },
      }),
      [props.targetDeploymentId],
    ),
  );

  return (
    <UpgradeProgressBannerContent
      targetDeployment={data?.deployment ?? null}
      targetDeploymentId={props.targetDeploymentId}
      currentDeploymentState={props.currentDeploymentState}
      fromVersion={props.fromVersion}
      toVersion={props.toVersion}
      deviceId={props.deviceId}
      isInfoOnly={props.isInfoOnly}
      onDismiss={props.onDismiss}
      onViewNewDeployment={props.onViewNewDeployment}
      onUpgradeComplete={props.onUpgradeComplete}
      onUpgradeFailed={props.onUpgradeFailed}
      onTargetNotFound={props.onTargetNotFound}
    />
  );
};

const UpgradeProgressBanner = (props: UpgradeProgressBannerProps) => {
  return (
    <Suspense
      fallback={
        <Card className="upgrade-progress-banner mb-4 shadow-sm">
          <Card.Body className="d-flex align-items-center gap-2">
            <Spinner animation="border" size="sm" variant="primary" />
            <span className="text-muted small">
              <FormattedMessage {...messages.pleaseWait} />
            </span>
          </Card.Body>
        </Card>
      }
    >
      <UpgradeProgressBannerQueryLoader {...props} />
    </Suspense>
  );
};

export default UpgradeProgressBanner;
export { UpgradeProgressBannerContent };
