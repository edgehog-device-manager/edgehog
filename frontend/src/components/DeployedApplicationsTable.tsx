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

import { defineMessages, FormattedMessage, useIntl } from "react-intl";
import { graphql, useMutation, usePaginationFragment } from "react-relay/hooks";
import { useCallback, useState, useMemo } from "react";
import semver from "semver";
import Select, { SingleValue } from "react-select";

import type { DeployedApplicationsTable_PaginationQuery } from "api/__generated__/DeployedApplicationsTable_PaginationQuery.graphql";
import type {
  ApplicationDeploymentResourcesState,
  ApplicationDeploymentState,
  DeployedApplicationsTable_deployedApplications$key,
} from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import type { DeployedApplicationsTable_startDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_startDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_stopDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_stopDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_deleteDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_deleteDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_upgradeDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_upgradeDeployment_Mutation.graphql";

import Icon from "components/Icon";
import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";
import Button from "./Button";
import ConfirmModal from "./ConfirmModal";
import DeleteModal from "./DeleteModal";

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
          resourcesState
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

type DeploymentState =
  | "DEPLOYING"
  | "PENDING"
  | "SENT"
  | "STARTING"
  | "STARTED"
  | "STOPPING"
  | "STOPPED"
  | "ERROR"
  | "DELETING";

type DeploymentResourcesState =
  | "INITIAL"
  | "CREATED_IMAGES"
  | "CREATED_NETWORKS"
  | "CREATED_VOLUMES"
  | "CREATED_DEVICE_MAPPINGS"
  | "CREATED_CONTAINERS"
  | "READY";

const parseDeploymentState = (
  apiState?: ApplicationDeploymentState,
): DeploymentState => {
  switch (apiState) {
    case "PENDING":
      return "PENDING";
    case "SENT":
      return "SENT";
    case "STARTED":
      return "STARTED";
    case "STARTING":
      return "STARTING";
    case "STOPPED":
      return "STOPPED";
    case "STOPPING":
      return "STOPPING";
    case "ERROR":
      return "ERROR";
    case "DELETING":
      return "DELETING";
    default:
      return "DEPLOYING";
  }
};

const parseDeploymentResourcesState = (
  apiState?: ApplicationDeploymentResourcesState,
): DeploymentResourcesState => {
  switch (apiState) {
    case "INITIAL":
      return "INITIAL";
    case "CREATED_IMAGES":
      return "CREATED_IMAGES";
    case "CREATED_NETWORKS":
      return "CREATED_NETWORKS";
    case "CREATED_VOLUMES":
      return "CREATED_VOLUMES";
    case "CREATED_DEVICE_MAPPINGS":
      return "CREATED_DEVICE_MAPPINGS";
    case "CREATED_CONTAINERS":
      return "CREATED_CONTAINERS";
    case "READY":
      return "READY";
    default:
      return "INITIAL";
  }
};

const stateColors: Record<DeploymentState, string> = {
  PENDING: "text-success",
  SENT: "text-success",
  STARTING: "text-success",
  STARTED: "text-success",
  STOPPING: "text-warning",
  STOPPED: "text-secondary",
  ERROR: "text-danger",
  DELETING: "text-danger",
  DEPLOYING: "text-muted",
};

const resourcesStateColors: Record<DeploymentResourcesState, string> = {
  INITIAL: "text-muted",
  CREATED_IMAGES: "text-muted",
  CREATED_NETWORKS: "text-muted",
  CREATED_VOLUMES: "text-muted",
  CREATED_DEVICE_MAPPINGS: "text-muted",
  CREATED_CONTAINERS: "text-muted",
  READY: "text-success",
};

// Define deployment state messages for localization
const stateMessages = defineMessages<DeploymentState>({
  PENDING: {
    id: "components.DeployedApplicationsTable.pending",
    defaultMessage: "Pending",
  },
  SENT: {
    id: "components.DeployedApplicationsTable.sent",
    defaultMessage: "Sent",
  },
  STARTING: {
    id: "components.DeployedApplicationsTable.starting",
    defaultMessage: "Starting",
  },
  STARTED: {
    id: "components.DeployedApplicationsTable.started",
    defaultMessage: "Started",
  },
  STOPPING: {
    id: "components.DeployedApplicationsTable.stopping",
    defaultMessage: "Stopping",
  },
  STOPPED: {
    id: "components.DeployedApplicationsTable.stopped",
    defaultMessage: "Stopped",
  },
  ERROR: {
    id: "components.DeployedApplicationsTable.error",
    defaultMessage: "Error",
  },
  DELETING: {
    id: "components.DeployedApplicationsTable.deleting",
    defaultMessage: "Deleting",
  },
  DEPLOYING: {
    id: "components.DeployedApplicationsTable.deploying",
    defaultMessage: "Deploying",
  },
});

// Define deployment resources state messages for localization
const resourcesStateMessages = defineMessages<DeploymentResourcesState>({
  INITIAL: {
    id: "components.DeployedApplicationsTable.initial",
    defaultMessage: "Initial",
  },
  CREATED_IMAGES: {
    id: "components.DeployedApplicationsTable.createdImages",
    defaultMessage: "Created images",
  },
  CREATED_NETWORKS: {
    id: "components.DeployedApplicationsTable.createdNetworks",
    defaultMessage: "Created networks",
  },
  CREATED_VOLUMES: {
    id: "components.DeployedApplicationsTable.createdVolumes",
    defaultMessage: "Created volumes",
  },
  CREATED_DEVICE_MAPPINGS: {
    id: "components.DeployedApplicationsTable.createdDeviceMappings",
    defaultMessage: "Created device mappings",
  },
  CREATED_CONTAINERS: {
    id: "components.DeployedApplicationsTable.createdContainers",
    defaultMessage: "Created containers",
  },
  READY: {
    id: "components.DeployedApplicationsTable.ready",
    defaultMessage: "Ready",
  },
});

// Component to render the deployment state with an icon and optional spin
const DeploymentStateComponent = ({ state }: { state: DeploymentState }) => (
  <div className="d-flex align-items-center">
    <Icon
      icon={
        ["STARTING", "STOPPING", "DEPLOYING", "DELETING"].includes(state)
          ? "spinner"
          : "circle"
      }
      className={`me-2 ${stateColors[state]} ${
        ["STARTING", "STOPPING", "DEPLOYING", "DELETING"].includes(state)
          ? "fa-spin"
          : ""
      }`}
    />
    <FormattedMessage id={stateMessages[state].id} />
  </div>
);

// Component to render the deployment resources state with an icon and optional spin
const DeploymentResourcesStateComponent = ({
  resourcesState,
}: {
  resourcesState: DeploymentResourcesState;
}) => (
  <div className="d-flex align-items-center">
    <Icon
      icon={resourcesState !== "READY" ? "spinner" : "circle"}
      className={`me-2 ${resourcesStateColors[resourcesState]} ${
        resourcesState !== "READY" ? "fa-spin" : ""
      }`}
    />
    <FormattedMessage id={resourcesStateMessages[resourcesState].id} />
  </div>
);

// Action buttons with play and stop icons
const ActionButtons = ({
  state,
  onStart,
  onStop,
}: {
  state: DeploymentState;
  onStart: () => void;
  onStop: () => void;
}) => (
  <div>
    {state === "STOPPED" || state === "ERROR" ? (
      <Button
        onClick={onStart}
        className="btn p-0 text-success border-0 bg-transparent"
      >
        <Icon icon="play" className="text-success" />
      </Button>
    ) : state === "STARTED" ? (
      <Button
        onClick={onStop}
        className="btn p-0 text-danger border-0 bg-transparent"
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
};

const DeployedApplicationsTable = ({
  className,
  deviceRef,
  isOnline,
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

  const upgradeReleaseOptions: SelectOption[] = useMemo(() => {
    if (!selectedDeployment?.upgradeTargetReleases) return [];

    return selectedDeployment.upgradeTargetReleases.map(({ node }) => ({
      value: node.id,
      label: node.version,
    }));
  }, [selectedDeployment?.upgradeTargetReleases]);

  const selectedUpgradeReleaseOption = useMemo(() => {
    return (
      upgradeReleaseOptions.find(
        (option) => option.value === upgradeTargetRelease?.id,
      ) || null
    );
  }, [upgradeReleaseOptions, upgradeTargetRelease?.id]);

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
      resources_state: parseDeploymentResourcesState(
        edge.node.resourcesState || undefined,
      ),
      upgradeTargetReleases:
        edge.node.release?.application?.releases?.edges?.filter((releaseEdge) =>
          semver.gt(
            releaseEdge.node.version,
            edge.node.release?.version || "0.0.0",
          ),
        ),
    })) || [];

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
    columnHelper.accessor("state", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.state"
          defaultMessage="State"
        />
      ),
      cell: ({ getValue }) => <DeploymentStateComponent state={getValue()} />,
    }),
    columnHelper.accessor("resources_state", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.resourcesState"
          defaultMessage="Resources State"
        />
      ),
      cell: ({ getValue }) => (
        <DeploymentResourcesStateComponent resourcesState={getValue()} />
      ),
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
            state={getValue().state}
            onStart={() => handleStartDeployedApplication(getValue().id)}
            onStop={() => handleStopDeployedApplication(getValue().id)}
          />

          <Button
            onClick={() => {
              setSelectedDeployment(row.original);
              handleShowUpgradeModal();
            }}
            disabled={getValue().state === "DELETING"}
            className="btn p-0 border-0 bg-transparent ms-4"
          >
            <Icon icon="upgrade" className="text-primary" />
          </Button>

          <Button
            disabled={getValue().state === "DELETING"}
            className="btn p-0 border-0 bg-transparent ms-4"
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

// TODO: Make dedicated files for these components
export { DeploymentStateComponent, DeploymentResourcesStateComponent };

export type { DeploymentTableProps, DeploymentState };
export default DeployedApplicationsTable;
