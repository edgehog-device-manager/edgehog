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
import { useCallback } from "react";

import type {
  ApplicationDeploymentStatus,
  DeployedApplicationsTable_deployedApplications$key,
} from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import type { DeployedApplicationsTable_startDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_startDeployment_Mutation.graphql";
import type { DeployedApplicationsTable_stopDeployment_Mutation } from "api/__generated__/DeployedApplicationsTable_stopDeployment_Mutation.graphql";

import Icon from "components/Icon";
import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";

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

// Define colors for each ApplicationDeploymentStatus
const statusColors: Record<ApplicationDeploymentStatus, string> = {
  STARTING: "text-muted",
  STARTED: "text-success",
  STOPPING: "text-muted",
  STOPPED: "text-secondary",
  ERROR: "text-danger",
  DELETING: "text-warning",
};

// Define status messages for localization
const statusMessages = defineMessages<ApplicationDeploymentStatus>({
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
});

// Component to render the status with an icon and optional spin
const DeploymentStatusComponent = ({
  status,
}: {
  status: ApplicationDeploymentStatus;
}) => (
  <div className="d-flex align-items-center">
    <Icon
      icon={
        status === "STARTING" || status === "STOPPING" ? "spinner" : "circle"
      }
      className={`me-2 ${statusColors[status]} ${
        status === "STARTING" || status === "STOPPING" ? "fa-spin" : ""
      }`}
    />
    <span>
      <FormattedMessage id={statusMessages[status].id} />
    </span>
  </div>
);

// Action buttons with play and stop icons
const ActionButtons = ({
  status,
  onStart,
  onStop,
}: {
  status: ApplicationDeploymentStatus;
  onStart: () => void;
  onStop: () => void;
}) => (
  <div>
    {status === "STOPPED" || status === "ERROR" ? (
      <button
        onClick={onStart}
        className="btn p-0 text-success border-0 bg-transparent"
      >
        <Icon icon="play" className="text-success" />
      </button>
    ) : status === "STARTED" ? (
      <button
        onClick={onStop}
        className="btn p-0 text-danger border-0 bg-transparent"
      >
        <Icon icon="stop" className="text-danger" />
      </button>
    ) : (
      <button className="btn p-0 border-0 bg-transparent" disabled>
        <Icon
          icon={status === "STARTING" ? "play" : "stop"}
          className="text-muted"
        />
      </button>
    )}
  </div>
);

type DeploymentTableProps = {
  className?: string;
  deviceRef: DeployedApplicationsTable_deployedApplications$key;
  hideSearch?: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
  onDeploymentChange: () => void;
};

const DeployedApplicationsTable = ({
  className,
  deviceRef,
  hideSearch = false,
  setErrorFeedback,
  onDeploymentChange,
}: DeploymentTableProps) => {
  const data = useFragment(DEPLOYED_APPLICATIONS_TABLE_FRAGMENT, deviceRef);

  const [startDeployment] =
    useMutation<DeployedApplicationsTable_startDeployment_Mutation>(
      START_DEPLOYMENT_MUTATION,
    );
  const [stopDeployment] =
    useMutation<DeployedApplicationsTable_stopDeployment_Mutation>(
      STOP_DEPLOYMENT_MUTATION,
    );

  const deployments =
    data.applicationDeployments?.edges?.map((edge) => ({
      id: edge.node.id,
      applicationId: edge.node.release?.application?.id || "Unknown",
      applicationName: edge.node.release?.application?.name || "Unknown",
      releaseId: edge.node.release?.id || "Unknown",
      releaseVersion: edge.node.release?.version || "N/A",
      status: edge.node.status,
    })) || [];

  const handleStartDeployedApplication = useCallback(
    (deploymentId: string) => {
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
              id="components.AddAvailableApplications.startErrorFeedback"
              defaultMessage="Could not Start the Deployed Application, please try again."
            />,
          );
        },
      });
    },
    [startDeployment, setErrorFeedback, onDeploymentChange],
  );

  const handleStopDeployedApplication = useCallback(
    (deploymentId: string) => {
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
              id="components.AddAvailableApplications.stopErrorFeedback"
              defaultMessage="Could not Stop the Deployed Application, please try again."
            />,
          );
        },
      });
    },
    [stopDeployment, setErrorFeedback, onDeploymentChange],
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
          params={{ releaseId: row.original.releaseId }}
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
      cell: ({ getValue }) => (
        <DeploymentStatusComponent status={getValue() || "ERROR"} />
      ),
    }),
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.action"
          defaultMessage="Action"
        />
      ),
      cell: ({ getValue }) => (
        <ActionButtons
          status={getValue().status || "ERROR"}
          onStart={() => handleStartDeployedApplication(getValue().id)}
          onStop={() => handleStopDeployedApplication(getValue().id)}
        />
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
    <Table
      className={className}
      columns={columns}
      data={deployments}
      hideSearch={hideSearch}
    />
  );
};

export type { DeploymentTableProps };
export default DeployedApplicationsTable;
