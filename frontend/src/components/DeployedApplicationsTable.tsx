/*
 * This file is part of Edgehog.
 *
 * Copyright 2024 - 2026 SECO Mind Srl
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

import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { DeployedApplicationsTable_PaginationQuery } from "@/api/__generated__/DeployedApplicationsTable_PaginationQuery.graphql";
import type { DeployedApplicationsTable_deployedApplications$key } from "@/api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import Icon from "@/components/Icon";
import { Link, Route, useNavigate } from "@/Navigation";
import Table, { createColumnHelper } from "@/components/Table";
import Button from "@/components/Button";
import DeploymentStateComponent, {
  parseDeploymentState,
} from "@/components/DeploymentState";
import DeploymentReadiness from "@/components/DeploymentReadiness";

// We use graphql fields below in columns configuration

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
          device {
            id
            name
          }
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
          campaignTarget {
            campaign {
              id
              name
            }
          }
          ...DeploymentDetails_events
          ...DeploymentDetails_containerDeployments
          containerDeployments(first: $first, after: $after) {
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

type DeploymentTableProps = {
  className?: string;
  deviceRef: DeployedApplicationsTable_deployedApplications$key;
  hideSearch?: boolean;
};

const DeployedApplicationsTable = ({
  className,
  deviceRef,
  hideSearch = false,
}: DeploymentTableProps) => {
  const { data } = usePaginationFragment<
    DeployedApplicationsTable_PaginationQuery,
    DeployedApplicationsTable_deployedApplications$key
  >(DEPLOYED_APPLICATIONS_TABLE_FRAGMENT, deviceRef);

  const intl = useIntl();
  const navigate = useNavigate();

  const deployments =
    data.applicationDeployments?.edges?.map((edge) => ({
      id: edge.node.id,
      applicationId: edge.node.release?.application?.id || "Unknown",
      applicationName: edge.node.release?.application?.name || "Unknown",
      releaseId: edge.node.release?.id || "Unknown",
      releaseVersion: edge.node.release?.version || "N/A",
      deviceId: edge.node.device?.id || "Unknown",
      state: parseDeploymentState(edge.node.state || undefined),
      isReady: edge.node.isReady,
      campaignTarget: edge.node.campaignTarget,
    })) || [];

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
    columnHelper.accessor((row) => row.campaignTarget?.campaign?.name, {
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
              row.original.campaignTarget?.campaign?.id ?? "",
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
    columnHelper.accessor((row) => row, {
      id: "details",
      header: () => (
        <FormattedMessage
          id="components.DeployedApplicationsTable.details"
          defaultMessage="Details"
        />
      ),
      cell: ({ row }) => (
        <div className="d-flex align-items-center">
          <Button
            className="btn btn-link border-0 bg-transparent p-0 text-decoration-none d-inline-flex align-items-center"
            title={intl.formatMessage({
              id: "components.DeployedApplicationsTable.deploymentDetailsButtonTitle",
              defaultMessage: "Deployment Details",
            })}
            onClick={() => {
              navigate({
                route: Route.deploymentEdit,
                params: {
                  deploymentId: row.original.id,
                  deviceId: row.original.deviceId,
                },
              });
            }}
          >
            <Icon
              icon="faCircleInfo"
              style={{
                color: "white",
                backgroundColor: "gray",
                borderRadius: "50%",
                padding: "1px",
                cursor: "pointer",
                boxShadow: "0 2px 5px rgba(0,0,0,0.2)",
                transition: "transform 0.3s, box-shadow 0.3s",
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = "scale(1.2)";
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = "scale(1)";
              }}
            />
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
    </div>
  );
};

export type { DeploymentTableProps };
export default DeployedApplicationsTable;
