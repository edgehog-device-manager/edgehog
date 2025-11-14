/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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
import { graphql, useMutation, usePaginationFragment } from "react-relay/hooks";
import { useCallback, useState, useMemo } from "react";
import semver from "semver";
import Select, { SingleValue } from "react-select";

import type { DeployedApplicationsTable_PaginationQuery } from "api/__generated__/DeployedApplicationsTable_PaginationQuery.graphql";
import type { DeployedApplicationsTable_deployedApplications$key } from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import type { DeployedApplicationsTable_sendDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_sendDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_startDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_startDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_stopDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_stopDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_deleteDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_deleteDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_upgradeDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_upgradeDeployment_Mutation.graphql";

import Icon from "components/Icon";
import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";
import Button from "components/Button";
import ConfirmModal from "components/ConfirmModal";
import DeleteModal from "components/DeleteModal";
import DeploymentStateComponent, {
  type DeploymentState,
  parseDeploymentState,
} from "components/DeploymentState";
import DeploymentReadiness from "components/DeploymentReadiness";
import ContainerStatusList from "components/ContainerStatusList";
import "components/DeployedApplicationsTable.scss";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEPLOYED_APPLICATIONS_TABLE_FRAGMENT = graphql`
  fragment DeployedApplicationsTable_deployedApplications on Device
  @refetchable(queryName: "DeployedApplicationsTable_PaginationQuery") {
    applicationDeployments(first: $first, after: $after)
      @connection(key: "DeployedApplicationsTable_applicationDeployments") {
      edges {
        node {
          id
          state
          isReady
          release {
            id
            version
            application {
              id
              name
              releases {
                edges {
                  node {
                    id
                    version
                    systemModels {
                      name
                    }
                  }
                }
              }
            }
          }
          deploymentTarget {
            deploymentCampaign {
              id
              name
            }
          }
          containerDeployments {
            edges {
              node {
                id
                state
                container {
                  image {
                    reference
                  }
                }
              }
            }
          }
        }
      }
    }
  }
`;

const SEND_DEPLOYMENT_MUTATION = graphql`
  mutation DeployedApplicationsTable_sendDeployment_Mutation($id: ID!) {
    sendDeployment(id: $id) {
      result {
        id
        state
      }
      errors {
        message
      }
    }
  }
`;

const START_DEPLOYMENT_MUTATION = graphql`
  mutation DeployedApplicationsTable_startDeployment_Mutation($id: ID!) {
    startDeployment(id: $id) {
      result {
        id
      }
      errors {
        message
      }
    }
  }
`;

const STOP_DEPLOYMENT_MUTATION = graphql`
  mutation DeployedApplicationsTable_stopDeployment_Mutation($id: ID!) {
    stopDeployment(id: $id) {
      result {
        id
      }
      errors {
        message
      }
    }
  }
`;

const DELETE_DEPLOYMENT_MUTATION = graphql`
  mutation DeployedApplicationsTable_deleteDeployment_Mutation($id: ID!) {
    deleteDeployment(id: $id) {
      result {
        id
      }
    }
  }
`;

const UPGRADE_DEPLOYMENT_MUTATION = graphql`
  mutation DeployedApplicationsTable_upgradeDeployment_Mutation(
    $id: ID!
    $input: UpgradeDeploymentInput!
  ) {
    upgradeDeployment(id: $id, input: $input) {
      result {
        id
      }
    }
  }
`;

// Action buttons with play and stop icons
const ActionButtons = ({
  intl,
  state,
  onStart,
  onStop,
  onRedeploy,
  disabled,
}: {
  intl: ReturnType<typeof useIntl>;
  state: DeploymentState;
  onStart: () => void;
  onStop: () => void;
  onRedeploy: () => void;
  disabled: boolean;
}) => (
  <div>
    {disabled ? (
      <Button
        className={"btn p-0 border-0 bg-transparent ms-4 icon-click"}
        title={intl.formatMessage({
          id: "components.DeployedApplicationsTable.sendButtonTitle",
          defaultMessage: "Redeploy Application",
        })}
        onClick={onRedeploy}
      >
        <Icon className="text-dark" icon={"rotate"} />
      </Button>
    ) : state === "STOPPED" || state === "ERROR" ? (
      <Button
        onClick={onStart}
        className="btn p-0 text-success border-0 bg-transparent icon-click"
        title={intl.formatMessage({
          id: "components.DeployedApplicationsTable.startButtonTitle",
          defaultMessage: "Start Deployment",
        })}
      >
        <Icon icon="play" className="text-success" />
      </Button>
    ) : state === "STARTED" ? (
      <Button
        onClick={onStop}
        className="btn p-0 text-danger border-0 bg-transparent icon-click"
        title={intl.formatMessage({
          id: "components.DeployedApplicationsTable.stopButtonTitle",
          defaultMessage: "Stop Deployment",
        })}
      >
        <Icon icon="stop" className="text-danger" />
      </Button>
    ) : (
      <Button className="btn p-0 border-0 bg-transparent" disabled>
        <Icon
          icon={state === "STARTING" || state === "DEPLOYING" ? "play" : "stop"}
          className="text-muted"
        />
      </Button>
    )}
  </div>
);

type DeploymentTableProps = {
  className?: string;
  deviceRef: DeployedApplicationsTable_deployedApplications$key;
  isOnline: boolean;
  systemModelName: string | undefined;
  hideSearch?: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
  onDeploymentChange: () => void;
};

type UpgradeTargetRelease = {
  id: string;
  version: string;
};

type SelectOption = {
  value: string;
  label: string;
  disabled: boolean;
};

const DeployedApplicationsTable = ({
  className,
  deviceRef,
  isOnline,
  systemModelName,
  hideSearch = false,
  setErrorFeedback,
  onDeploymentChange,
}: DeploymentTableProps) => {
  const { data } = usePaginationFragment<
    DeployedApplicationsTable_PaginationQuery,
    DeployedApplicationsTable_deployedApplications$key
  >(DEPLOYED_APPLICATIONS_TABLE_FRAGMENT, deviceRef);

  const intl = useIntl();

  const [upgradeTargetRelease, setUpgradeTargetRelease] =
    useState<UpgradeTargetRelease | null>(null);

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);

  const [selectedDeployment, setSelectedDeployment] = useState<
    (typeof deployments)[0] | null
  >(null);

  // Track expanded state for container status lists
  const [expandedContainerLists, setExpandedContainerLists] = useState<
    Set<string>
  >(new Set());

  const upgradeReleaseOptions: SelectOption[] = useMemo(() => {
    if (!selectedDeployment?.upgradeTargetReleases) return [];
    return selectedDeployment?.upgradeTargetReleases.map(
      ({ node: release }) => {
        const systemModelNames =
          release.systemModels?.map((sm) => sm.name) ?? [];

        const hasSystemModel = !!systemModelName;
        const matchesSystemModel =
          hasSystemModel && systemModelNames.includes(systemModelName);
        const appliesToAll = systemModelNames.length === 0;

        const enabled = matchesSystemModel || appliesToAll;

        return {
          value: release.id,
          label: release.version,
          disabled: !enabled,
        };
      },
    );
  }, [selectedDeployment?.upgradeTargetReleases]);

  const selectedUpgradeReleaseOption = useMemo(() => {
    return (
      upgradeReleaseOptions.find(
        (option) => option.value === upgradeTargetRelease?.id,
      ) || null
    );
  }, [upgradeReleaseOptions, upgradeTargetRelease?.id]);

  const [sendDeployment] =
    useMutation<DeployedApplicationsTable_sendDeployment_Mutation>(
      SEND_DEPLOYMENT_MUTATION,
    );
  const [startDeployment] =
    useMutation<DeployedApplicationsTable_startDeployment_Mutation>(
      START_DEPLOYMENT_MUTATION,
    );
  const [stopDeployment] =
    useMutation<DeployedApplicationsTable_stopDeployment_Mutation>(
      STOP_DEPLOYMENT_MUTATION,
    );

  const [deleteDeployment, isDeletingDeployment] =
    useMutation<DeployedApplicationsTable_deleteDeployment_Mutation>(
      DELETE_DEPLOYMENT_MUTATION,
    );

  const [upgradeDeployment] =
    useMutation<DeployedApplicationsTable_upgradeDeployment_Mutation>(
      UPGRADE_DEPLOYMENT_MUTATION,
    );

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const handleShowUpgradeModal = useCallback(() => {
    setShowUpgradeModal(true);
  }, [setShowUpgradeModal]);

  const handleUpgradeReleaseChange = useCallback(
    (option: SingleValue<SelectOption>) => {
      if (option) {
        setUpgradeTargetRelease({
          id: option.value,
          version: option.label,
        });
      } else {
        setUpgradeTargetRelease(null);
      }
    },
    [],
  );

  const deployments =
    data.applicationDeployments?.edges?.map((edge) => ({
      id: edge.node.id,
      applicationId: edge.node.release?.application?.id || "Unknown",
      applicationName: edge.node.release?.application?.name || "Unknown",
      releaseId: edge.node.release?.id || "Unknown",
      releaseVersion: edge.node.release?.version || "N/A",
      state: parseDeploymentState(edge.node.state || undefined),
      isReady: edge.node.isReady,
      containerDeployments:
        edge.node.containerDeployments?.edges?.map((containerEdge) => ({
          id: containerEdge.node.id,
          state: containerEdge.node.state,
          container: containerEdge.node.container
            ? {
                image: {
                  reference:
                    containerEdge.node.container.image?.reference || "Unknown",
                },
              }
            : null,
        })) || [],
      deploymentTarget: edge.node.deploymentTarget,
      upgradeTargetReleases:
        edge.node.release?.application?.releases?.edges?.filter((releaseEdge) =>
          semver.gt(
            releaseEdge.node.version,
            edge.node.release?.version || "0.0.0",
          ),
        ),
    })) || [];

  const handleSendDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (isOnline) {
        sendDeployment({
          variables: { id: deploymentId },
          onCompleted: (data, errors) => {
            if (errors) {
              const errorFeedback = errors
                .map(({ fields, message }) =>
                  fields.length ? `${fields.join(" ")} ${message}` : message,
                )
                .join(". \n");
              return setErrorFeedback(errorFeedback);
            }
            onDeploymentChange(); // Trigger data refresh
            setErrorFeedback(null);
          },
          onError: () => {
            setErrorFeedback(
              <FormattedMessage
                id="components.DeployedApplicationsTable.sendErrorFeedback"
                defaultMessage="Could not send the Application to the device, please try again."
              />,
            );
          },
        });
      } else {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeployedApplicationsTable.sendErrorOffline"
            defaultMessage="The device is disconnected. You cannot deploy an application while it is offline."
          />,
        );
      }
    },
    [isOnline, sendDeployment, setErrorFeedback, onDeploymentChange],
  );

  const handleStartDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (isOnline) {
        startDeployment({
          variables: { id: deploymentId },
          onCompleted: (data, errors) => {
            if (errors) {
              const errorFeedback = errors
                .map(({ fields, message }) =>
                  fields.length ? `${fields.join(" ")} ${message}` : message,
                )
                .join(". \n");
              return setErrorFeedback(errorFeedback);
            }
            onDeploymentChange(); // Trigger data refresh
            setErrorFeedback(null);
          },
          onError: () => {
            setErrorFeedback(
              <FormattedMessage
                id="components.DeployedApplicationsTable.startErrorFeedback"
                defaultMessage="Could not Start the Deployed Application, please try again."
              />,
            );
          },
        });
      } else {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeployedApplicationsTable.startErrorOffline"
            defaultMessage="The device is disconnected. You cannot start an application while it is offline."
          />,
        );
      }
    },
    [isOnline, startDeployment, setErrorFeedback, onDeploymentChange],
  );

  const handleStopDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (isOnline) {
        stopDeployment({
          variables: { id: deploymentId },
          onCompleted: (data, errors) => {
            if (errors) {
              const errorFeedback = errors
                .map(({ fields, message }) =>
                  fields.length ? `${fields.join(" ")} ${message}` : message,
                )
                .join(". \n");
              return setErrorFeedback(errorFeedback);
            }
            onDeploymentChange(); // Trigger data refresh
            setErrorFeedback(null);
          },
          onError: () => {
            setErrorFeedback(
              <FormattedMessage
                id="components.DeployedApplicationsTable.stopErrorFeedback"
                defaultMessage="Could not Stop the Deployed Application, please try again."
              />,
            );
          },
        });
      } else {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeployedApplicationsTable.stopErrorOffline"
            defaultMessage="The device is disconnected. You cannot stop an application while it is offline."
          />,
        );
      }
    },
    [isOnline, stopDeployment, setErrorFeedback, onDeploymentChange],
  );

  const handleDeleteDeployedApplication = useCallback(
    (deploymentId: string) => {
      deleteDeployment({
        variables: { id: deploymentId },
        onCompleted(data, errors) {
          if (
            !errors ||
            errors.length === 0 ||
            errors[0].code === "not_found"
          ) {
            setErrorFeedback(null);
            setShowDeleteModal(false);
            return;
          }

          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          setErrorFeedback(errorFeedback);
          setShowDeleteModal(false);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="components.DeployedApplicationsTable.deletionErrorFeedback"
              defaultMessage="Could not delete the deployment, please try again."
            />,
          );
          setShowDeleteModal(false);
        },
      });
    },
    [deleteDeployment, setErrorFeedback],
  );

  const handleUpgradeDeployedRelease = useCallback(
    (deploymentId: string, upgradeTargetReleaseId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="components.DeployedApplicationsTable.upgradeErrorOffline"
            defaultMessage="The device is disconnected. You cannot upgrade an application while it is offline."
          />,
        );
      }

      upgradeDeployment({
        variables: {
          id: deploymentId,
          input: { target: upgradeTargetReleaseId },
        },
        onCompleted(data, errors) {
          if (
            !errors ||
            errors.length === 0 ||
            errors[0].code === "not_found"
          ) {
            setErrorFeedback(null);
            setShowUpgradeModal(false);
            return;
          }

          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          setErrorFeedback(errorFeedback);
          setShowUpgradeModal(false);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="components.DeployedApplicationsTable.upgradeErrorFeedback"
              defaultMessage="Could not upgrade the deployment, please try again."
            />,
          );
          setShowUpgradeModal(false);
        },
      });
    },
    [upgradeDeployment, setErrorFeedback, isOnline],
  );

  const columnHelper = createColumnHelper<(typeof deployments)[0]>();
  const columns = [
    columnHelper.accessor("applicationName", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.applicationName"
          defaultMessage="Application Name"
        />
      ),
      cell: ({ row, getValue }) => (
        <Link
          route={Route.application}
          params={{ applicationId: row.original.applicationId }}
        >
          {getValue()}
        </Link>
      ),
    }),
    columnHelper.accessor("releaseVersion", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.releaseVersion"
          defaultMessage="Release Version"
        />
      ),
      cell: ({ row, getValue }) => (
        <Link
          route={Route.release}
          params={{
            applicationId: row.original.applicationId,
            releaseId: row.original.releaseId,
          }}
        >
          {getValue()}
        </Link>
      ),
    }),
    columnHelper.accessor(
      (row) => row.deploymentTarget?.deploymentCampaign?.name,
      {
        id: "deploymentCampaignName",
        header: () => (
          <FormattedMessage
            id="components.DeployedApplicationsTable.deploymentCampaignNameTitle"
            defaultMessage="Deployment Campaign"
          />
        ),
        cell: ({ row, getValue }) => (
          <Link
            route={Route.deploymentCampaignsEdit}
            params={{
              deploymentCampaignId:
                row.original.deploymentTarget?.deploymentCampaign?.id ?? "",
            }}
          >
            {getValue()}
          </Link>
        ),
      },
    ),
    columnHelper.accessor("state", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.state"
          defaultMessage="State"
        />
      ),
      cell: ({ row, getValue }) => (
        <DeploymentStateComponent
          state={getValue()}
          isReady={row.original.isReady}
        />
      ),
    }),
    columnHelper.accessor("isReady", {
      id: "readiness",
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.readiness"
          defaultMessage="Readiness"
        />
      ),
      cell: ({ getValue }) => <DeploymentReadiness isReady={getValue()} />,
    }),
    columnHelper.accessor("containerDeployments", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.containerStatus"
          defaultMessage="Container Status"
        />
      ),
      cell: ({ getValue, row }) => {
        const deployment = row.original;
        const deploymentId = deployment.id;
        const isExpanded = expandedContainerLists.has(deploymentId);

        const handleToggleExpanded = () => {
          const newExpanded = new Set(expandedContainerLists);
          if (isExpanded) {
            newExpanded.delete(deploymentId);
          } else {
            newExpanded.add(deploymentId);
          }
          setExpandedContainerLists(newExpanded);
        };

        return (
          <ContainerStatusList
            containerDeployments={getValue()}
            isExpanded={isExpanded}
            onToggleExpanded={handleToggleExpanded}
          />
        );
      },
    }),
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.actions"
          defaultMessage="Actions"
        />
      ),
      cell: ({ row, getValue }) => (
        <div className="d-flex align-items-center">
          <ActionButtons
            disabled={!getValue().isReady}
            intl={intl}
            state={getValue().state}
            onStart={() => handleStartDeployedApplication(getValue().id)}
            onStop={() => handleStopDeployedApplication(getValue().id)}
            onRedeploy={() => handleSendDeployedApplication(getValue().id)}
          />

          <Button
            onClick={() => {
              setSelectedDeployment(row.original);
              handleShowUpgradeModal();
            }}
            disabled={getValue().state === "DELETING" || !getValue()?.isReady}
            className="btn p-0 border-0 bg-transparent ms-4 icon-click"
            title={intl.formatMessage({
              id: "components.DeployedApplicationsTable.upgradeButtonTitle",
              defaultMessage: "Upgrade Deployment",
            })}
          >
            <Icon icon="upgrade" className="text-primary" />
          </Button>

          <Button
            disabled={getValue().state === "DELETING" || !getValue()?.isReady}
            className="btn p-0 border-0 bg-transparent ms-4 icon-click"
            title={intl.formatMessage({
              id: "components.DeployedApplicationsTable.deleteButtonTitle",
              defaultMessage: "Delete Deployment",
            })}
            onClick={() => {
              setSelectedDeployment(getValue());
              handleShowDeleteModal();
            }}
          >
            <Icon className="text-danger" icon={"delete"} />
          </Button>
        </div>
      ),
    }),
  ];

  if (!deployments.length) {
    return (
      <div>
        <FormattedMessage
          id="components.DeployedApplicationsTable.noDeployedApplications"
          defaultMessage="No deployed applications"
        />
      </div>
    );
  }

  return (
    <div>
      <Table
        className={className}
        columns={columns}
        data={deployments}
        hideSearch={hideSearch}
      />

      {showDeleteModal && (
        <DeleteModal
          confirmText={selectedDeployment?.applicationName || ""}
          onCancel={() => setShowDeleteModal(false)}
          onConfirm={() => {
            if (selectedDeployment?.id) {
              handleDeleteDeployedApplication(selectedDeployment.id);
            }
          }}
          isDeleting={isDeletingDeployment}
          title={
            <FormattedMessage
              id="components.DeployedApplicationsTable.deleteModal.title"
              defaultMessage="Delete Deployment"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.DeployedApplicationsTable.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete the deployment."
            />
          </p>
          <p className="text-muted small">
            <FormattedMessage
              id="components.DeployedApplicationsTable.deleteModal.note"
              defaultMessage="Note: A deletion request will be sent to the device to start the deletion process. Please note that it may take some time for the request to be processed. This is expected behavior."
            />
          </p>
        </DeleteModal>
      )}
      {showUpgradeModal && (
        <ConfirmModal
          confirmLabel={
            <FormattedMessage
              id="components.DeployedApplicationsTable.confirmLabel"
              defaultMessage="Confirm"
            />
          }
          disabled={!selectedDeployment || !upgradeTargetRelease}
          onCancel={() => {
            setShowUpgradeModal(false);
            setUpgradeTargetRelease(null);
            setSelectedDeployment(null);
          }}
          onConfirm={() => {
            if (selectedDeployment && upgradeTargetRelease) {
              handleUpgradeDeployedRelease(
                selectedDeployment.id,
                upgradeTargetRelease.id,
              );
            }
            setShowUpgradeModal(false);
            setUpgradeTargetRelease(null);
            setSelectedDeployment(null);
          }}
          title={
            <FormattedMessage
              id="components.DeployedApplicationsTable.confirmModal.title"
              defaultMessage="Upgrade Deployment"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.DeployedApplicationsTable.confirmModal.description"
              defaultMessage="Are you sure you want to upgrade the deployment <bold>{application}</bold> from version <bold>{currentVersion}</bold> to version:"
              values={{
                application: selectedDeployment?.applicationName,
                currentVersion: selectedDeployment?.releaseVersion,
                bold: (chunks: React.ReactNode) => <strong>{chunks}</strong>,
              }}
            />
          </p>

          <Select
            value={selectedUpgradeReleaseOption}
            onChange={handleUpgradeReleaseChange}
            options={upgradeReleaseOptions}
            isOptionDisabled={(option) => option.disabled}
            isClearable
            placeholder={intl.formatMessage({
              id: "components.DeployedApplicationsTable.selectOption",
              defaultMessage: "Select a Release Version",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.DeployedApplicationsTable.noReleasesFoundMatching",
                      defaultMessage:
                        'No release versions found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : upgradeReleaseOptions.length === 0
                  ? intl.formatMessage({
                      id: "components.DeployedApplicationsTable.noReleasesAvailable",
                      defaultMessage: "No Release Versions Available",
                    })
                  : intl.formatMessage({
                      id: "components.DeployedApplicationsTable.selectOption",
                      defaultMessage: "Select a Release Version",
                    })
            }
            filterOption={(option, inputValue) => {
              // Only search by release version (label), not by ID (value)
              return option.label
                .toLowerCase()
                .includes(inputValue.toLowerCase());
            }}
          />
        </ConfirmModal>
      )}
    </div>
  );
};

export type { DeploymentTableProps };
export default DeployedApplicationsTable;
