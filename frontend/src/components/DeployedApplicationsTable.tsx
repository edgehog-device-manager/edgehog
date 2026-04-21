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

import { FormattedMessage, MessageDescriptor, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import { useMemo, useState, MouseEvent } from "react";
import semver from "semver";
import { Badge, Table } from "react-bootstrap";

import type { DeployedApplicationsTable_PaginationQuery } from "@/api/__generated__/DeployedApplicationsTable_PaginationQuery.graphql";
import type {
  DeployedApplicationsTable_deployedApplications$key,
  DeployedApplicationsTable_deployedApplications$data,
} from "@/api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import Icon from "@/components/Icon";
import { Route, useNavigate } from "@/Navigation";
import Button from "@/components/Button";
import {
  DeploymentState,
  parseDeploymentState,
  stateMessages,
} from "@/components/DeploymentState";
import CollapseItem from "./CollapseItem";

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
          }
          release {
            id
            version
            application {
              id
              name
            }
          }
          ...DeploymentDetails_events
          ...DeploymentDetails_containerDeployments
        }
      }
    }
  }
`;
type DeploymentNode = NonNullable<
  NonNullable<
    NonNullable<
      DeployedApplicationsTable_deployedApplications$data["applicationDeployments"]
    >["edges"]
  >[number]
>["node"];

const statusConfig: Record<
  string,
  { message: MessageDescriptor; color: string }
> = {
  STARTED: { message: stateMessages.STARTED, color: "bg-success" },
  STOPPED: { message: stateMessages.STOPPED, color: "bg-secondary" },
  DEFAULT: { message: stateMessages.DEPLOYING, color: "bg-light text-muted" },
};

type DeploymentsByApp = {
  applicationId: string;
  applicationName: string;
  releases: ReturnType<typeof mapDeploymentNode>[];
};

const mapDeploymentNode = (node: DeploymentNode) => ({
  id: node.id,
  applicationId: node.release?.application?.id ?? "Unknown",
  applicationName: node.release?.application?.name ?? "Unknown",
  releaseId: node.release?.id ?? "Unknown",
  releaseVersion: node.release?.version ?? "0.0.0",
  deviceId: node.device?.id ?? "Unknown",
  state: parseDeploymentState(node.state ?? undefined),
});

const DeployedApplicationsTable = ({
  deviceRef,
}: {
  deviceRef: DeployedApplicationsTable_deployedApplications$key;
}) => {
  const { data } = usePaginationFragment<
    DeployedApplicationsTable_PaginationQuery,
    DeployedApplicationsTable_deployedApplications$key
  >(DEPLOYED_APPLICATIONS_TABLE_FRAGMENT, deviceRef);

  const navigate = useNavigate();
  const intl = useIntl();

  const [expandedApps, setExpandedApps] = useState<Set<string>>(new Set());

  const toggleApp = (id: string) => {
    const next = new Set(expandedApps);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    setExpandedApps(next);
  };

  const groupedDeployments = useMemo(() => {
    const deploymentsByApp = new Map<string, DeploymentsByApp>();
    const edges = data.applicationDeployments?.edges ?? [];

    for (const edge of edges) {
      if (!edge?.node) continue;

      const deployment = mapDeploymentNode(edge.node);

      if (!deploymentsByApp.has(deployment.applicationId)) {
        deploymentsByApp.set(deployment.applicationId, {
          applicationId: deployment.applicationId,
          applicationName: deployment.applicationName,
          releases: [],
        });
      }

      deploymentsByApp.get(deployment.applicationId)!.releases.push(deployment);
    }

    return Array.from(deploymentsByApp.values()).map((group) => ({
      ...group,
      releases: group.releases.sort((a, b) =>
        semver.rcompare(a.releaseVersion, b.releaseVersion),
      ),
    }));
  }, [data.applicationDeployments?.edges]);

  const getStatusBadge = (state: DeploymentState) => {
    const config = statusConfig[state] ?? statusConfig.DEFAULT;
    return (
      <Badge
        className={`${config.color} d-inline-flex justify-content-center`}
        style={{ minWidth: "10ch" }}
      >
        {intl.formatMessage(config.message)}
      </Badge>
    );
  };

  const handleNavigate = (
    e: MouseEvent,
    deploymentId: string,
    deviceId: string,
  ) => {
    e.stopPropagation();
    navigate({
      route: Route.deploymentEdit,
      params: { deploymentId, deviceId },
    });
  };

  if (!groupedDeployments.length) {
    return (
      <FormattedMessage
        id="components.DeployedApplicationsTable.noDeployedApplications"
        defaultMessage="No deployed applications"
      />
    );
  }

  return (
    <div className="d-flex flex-column gap-2">
      {groupedDeployments.map((app) => {
        const latest = app.releases[0];
        const isOpen = expandedApps.has(app.applicationId);
        return (
          <CollapseItem
            key={app.applicationId}
            open={isOpen}
            onToggle={() => toggleApp(app.applicationId)}
            title={app.applicationName}
            caretPosition="left"
            headerClassName="fw-bold border rounded"
            contentClassName="border rounded"
            rightContent={
              !isOpen && (
                <div className="d-flex align-items-center">
                  <strong className="me-2">v{latest.releaseVersion}</strong>
                  {getStatusBadge(latest.state)}
                  <Button
                    variant="link"
                    className="p-0 ms-2 hover-scale"
                    onClick={(e: MouseEvent) =>
                      handleNavigate(e, latest.id, latest.deviceId)
                    }
                  >
                    <Icon icon="arrowUpRightFromSquare" />
                  </Button>
                </div>
              )
            }
          >
            <div className="ps-3">
              <Table hover borderless size="sm" className="mb-0">
                <tbody>
                  {app.releases.map((rel, index) => (
                    <tr
                      key={rel.id}
                      className={
                        index !== app.releases.length - 1 ? "border-bottom" : ""
                      }
                    >
                      <td className="align-middle text-secondary">
                        v{rel.releaseVersion}
                      </td>
                      <td className="text-end align-middle">
                        <div className="d-flex justify-content-end align-items-center gap-2">
                          {rel.id === latest.id && (
                            <Badge bg="primary">Latest</Badge>
                          )}
                          {getStatusBadge(rel.state)}
                          <Button
                            variant="link"
                            className="p-0"
                            onClick={(e: MouseEvent) =>
                              handleNavigate(e, rel.id, rel.deviceId)
                            }
                          >
                            <Icon icon="arrowUpRightFromSquare" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </div>
          </CollapseItem>
        );
      })}
    </div>
  );
};

export default DeployedApplicationsTable;
