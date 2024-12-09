/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import { defineMessages, FormattedMessage } from "react-intl";
import { graphql, useFragment, useMutation } from "react-relay/hooks";
import { useCallback, useState } from "react";

import type {
  ApplicationDeploymentStatus,
  DeployedApplicationsTable_deployedApplications$key,
} from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import type { DeployedApplicationsTable_startDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_startDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_stopDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_stopDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_deleteDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_deleteDeployment_Mutation.graphql";

import Icon from "components/Icon";
import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";
import Button from "./Button";
import DeleteModal from "./DeleteModal";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEPLOYED_APPLICATIONS_TABLE_FRAGMENT = graphql`
  fragment DeployedApplicationsTable_deployedApplications on Device {
    applicationDeployments {
      edges {
        node {
          id
          status
          release {
            id
            version
            application {
              id
              name
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

type DeploymentStatus =
  | "DEPLOYING"
  | "STARTING"
  | "STARTED"
  | "STOPPING"
  | "STOPPED"
  | "ERROR"
  | "DELETING";

const parseDeploymentStatus = (
  apiStatus?: ApplicationDeploymentStatus,
): DeploymentStatus => {
  switch (apiStatus) {
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

const statusColors: Record<DeploymentStatus, string> = {
  STARTING: "text-success",
  STARTED: "text-success",
  STOPPING: "text-warning",
  STOPPED: "text-secondary",
  ERROR: "text-danger",
  DELETING: "text-danger",
  DEPLOYING: "text-muted",
};

// Define status messages for localization
const statusMessages = defineMessages<DeploymentStatus>({
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

// Component to render the status with an icon and optional spin
const DeploymentStatusComponent = ({
  status,
}: {
  status: DeploymentStatus;
}) => (
  <div className="d-flex align-items-center">
    <Icon
      icon={
        ["STARTING", "STOPPING", "DEPLOYING", "DELETING"].includes(status)
          ? "spinner"
          : "circle"
      }
      className={`me-2 ${statusColors[status]} ${
        ["STARTING", "STOPPING", "DEPLOYING", "DELETING"].includes(status)
          ? "fa-spin"
          : ""
      }`}
    />
    <FormattedMessage id={statusMessages[status].id} />
  </div>
);

// Action buttons with play and stop icons
const ActionButtons = ({
  status,
  onStart,
  onStop,
}: {
  status: DeploymentStatus;
  onStart: () => void;
  onStop: () => void;
}) => (
  <div>
    {status === "STOPPED" || status === "ERROR" ? (
      <Button
        onClick={onStart}
        className="btn p-0 text-success border-0 bg-transparent"
      >
        <Icon icon="play" className="text-success" />
      </Button>
    ) : status === "STARTED" ? (
      <Button
        onClick={onStop}
        className="btn p-0 text-danger border-0 bg-transparent"
      >
        <Icon icon="stop" className="text-danger" />
      </Button>
    ) : (
      <Button className="btn p-0 border-0 bg-transparent" disabled>
        <Icon
          icon={
            status === "STARTING" || status === "DEPLOYING" ? "play" : "stop"
          }
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

const DeployedApplicationsTable = ({
  className,
  deviceRef,
  isOnline,
  hideSearch = false,
  setErrorFeedback,
  onDeploymentChange,
}: DeploymentTableProps) => {
  const data = useFragment(DEPLOYED_APPLICATIONS_TABLE_FRAGMENT, deviceRef);

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [selectedDeployment, setSelectedDeployment] = useState<
    (typeof deployments)[0] | null
  >(null);

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

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const deployments =
    data.applicationDeployments?.edges?.map((edge) => ({
      id: edge.node.id,
      applicationId: edge.node.release?.application?.id || "Unknown",
      applicationName: edge.node.release?.application?.name || "Unknown",
      releaseId: edge.node.release?.id || "Unknown",
      releaseVersion: edge.node.release?.version || "N/A",
      status: parseDeploymentStatus(edge.node.status),
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
    columnHelper.accessor("status", {
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.status"
          defaultMessage="Status"
        />
      ),
      cell: ({ getValue }) => <DeploymentStatusComponent status={getValue()} />,
    }),
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.actions"
          defaultMessage="Actions"
        />
      ),
      cell: ({ getValue }) => (
        <div className="d-flex align-items-center">
          <ActionButtons
            status={getValue().status}
            onStart={() => handleStartDeployedApplication(getValue().id)}
            onStop={() => handleStopDeployedApplication(getValue().id)}
          />
          <Button
            disabled={getValue().status === "DELETING"}
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
    </div>
  );
};

export type { DeploymentTableProps };
export default DeployedApplicationsTable;
