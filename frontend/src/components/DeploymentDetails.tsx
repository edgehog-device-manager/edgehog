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

import type { DeployedApplicationsTable_deployedApplications$data } from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";
import type {
  DeploymentDetails_events$key,
  DeploymentDetails_events$data,
} from "api/__generated__/DeploymentDetails_events.graphql";
import type {
  DeploymentDetails_networkDeployments$key,
  DeploymentDetails_networkDeployments$data,
} from "api/__generated__/DeploymentDetails_networkDeployments.graphql";
import type {
  DeploymentDetails_volumeDeployments$key,
  DeploymentDetails_volumeDeployments$data,
} from "api/__generated__/DeploymentDetails_volumeDeployments.graphql";
import type {
  DeploymentDetails_deviceMappingDeployments$key,
  DeploymentDetails_deviceMappingDeployments$data,
} from "api/__generated__/DeploymentDetails_deviceMappingDeployments.graphql";
import type {
  DeploymentDetails_containerDeployments$key,
  DeploymentDetails_containerDeployments$data,
} from "api/__generated__/DeploymentDetails_containerDeployments.graphql";
import type { DeploymentEventsPaginationQuery } from "api/__generated__/DeploymentEventsPaginationQuery.graphql";
import type { DeploymentContainerDeploymentsPaginationQuery } from "api/__generated__/DeploymentContainerDeploymentsPaginationQuery.graphql";

import Table, { createColumnHelper } from "components/Table";
import { Card, Col, Collapse, Row, Tab, Tabs } from "react-bootstrap";
import { FormattedMessage, useIntl } from "react-intl";
import Button from "./Button";
import Icon from "./Icon";
import { useState } from "react";
import { graphql, useFragment, usePaginationFragment } from "react-relay";
import ContainerStatus, {
  parseContainerState,
} from "components/ContainerStatus";
import { Link, Route } from "Navigation";
import DeploymentStateComponent, {
  parseDeploymentState,
} from "./DeploymentState";
import DeploymentReadiness from "./DeploymentReadiness";

const DEPLOYMENT_DETAILS_EVENTS_PAGINATION_FRAGMENT = graphql`
  fragment DeploymentDetails_events on Deployment
  @refetchable(queryName: "DeploymentEventsPaginationQuery") {
    id
    events(first: $first, after: $after)
      @connection(key: "DeploymentDetails_events") {
      edges {
        node {
          type
          message
          insertedAt
        }
      }
    }
  }
`;

const DEPLOYMENT_DETAILS_CONTAINER_DEPLOYMENTS_FRAGMENT = graphql`
  fragment DeploymentDetails_containerDeployments on Deployment
  @refetchable(queryName: "DeploymentContainerDeploymentsPaginationQuery") {
    containerDeployments(first: $first, after: $after)
      @connection(key: "DeploymentDetails_containerDeployments") {
      edges {
        node {
          id
          state
          container {
            image {
              reference
            }
          }
          imageDeployment {
            state
            image {
              id
              reference
            }
          }
          ...DeploymentDetails_deviceMappingDeployments
          ...DeploymentDetails_networkDeployments
          ...DeploymentDetails_volumeDeployments
        }
      }
    }
  }
`;
const DEPLOYMENT_DETAILS_NETWORK_DEPLOYMENTS_FRAGMENT = graphql`
  fragment DeploymentDetails_networkDeployments on ContainerDeployment {
    id
    networkDeployments(first: $first, after: $after) {
      edges {
        node {
          id
          state
          network {
            id
            label
          }
        }
      }
    }
  }
`;

const DEPLOYMENT_DETAILS_VOLUME_DEPLOYMENTS_FRAGMENT = graphql`
  fragment DeploymentDetails_volumeDeployments on ContainerDeployment {
    id
    volumeDeployments(first: $first, after: $after) {
      edges {
        node {
          id
          state
          volume {
            id
            label
          }
        }
      }
    }
  }
`;

const DEPLOYMENT_DETAILS_DEVICE_MAPPING_DEPLOYMENTS_FRAGMENT = graphql`
  fragment DeploymentDetails_deviceMappingDeployments on ContainerDeployment {
    id
    deviceMappingDeployments(first: $first, after: $after) {
      edges {
        node {
          id
          state
          deviceMapping {
            id
            pathOnHost
            pathInContainer
            cgroupPermissions
          }
        }
      }
    }
  }
`;

type Deployment = NonNullable<
  NonNullable<
    DeployedApplicationsTable_deployedApplications$data["applicationDeployments"]["edges"]
  >[number]["node"]
>;

type Event = NonNullable<
  NonNullable<DeploymentDetails_events$data["events"]["edges"]>[number]["node"]
>;

type ImageDeployment = NonNullable<
  NonNullable<
    DeploymentDetails_containerDeployments$data["containerDeployments"]["edges"]
  >[number]["node"]["imageDeployment"]
>;

type ContainerNetworkNode = NonNullable<
  NonNullable<
    DeploymentDetails_networkDeployments$data["networkDeployments"]["edges"]
  >[number]["node"]
>;

type ContainerVolumeNode = NonNullable<
  NonNullable<
    DeploymentDetails_volumeDeployments$data["volumeDeployments"]["edges"]
  >[number]["node"]
>;

type ContainerDeviceMappingNode = NonNullable<
  NonNullable<
    DeploymentDetails_deviceMappingDeployments$data["deviceMappingDeployments"]["edges"]
  >[number]["node"]
>;

const columnHelper = createColumnHelper<Event>();

const eventColumns = [
  columnHelper.accessor("type", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.eventType"
        defaultMessage="Type"
      />
    ),
    cell: ({ row }) => row.original.type ?? "",
  }),

  columnHelper.accessor("insertedAt", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.eventTimestamp"
        defaultMessage="Timestamp"
      />
    ),
    cell: ({ row }) => row.original.insertedAt ?? "",
  }),

  columnHelper.accessor("message", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.eventMessage"
        defaultMessage="Message"
      />
    ),
    cell: ({ row }) => {
      const msg = row.original.message ?? "";
      return (
        <span
          title={msg}
          className="d-inline-block text-truncate"
          style={{
            maxWidth: "300px",
            verticalAlign: "bottom",
          }}
        >
          {msg}
        </span>
      );
    },
  }),
];

function CollapsibleTable({
  title,
  columns,
  data,
}: {
  title: string;
  columns: any;
  data: any[];
}) {
  const [open, setOpen] = useState(true);

  return (
    <Card className="mb-2 shadow-sm">
      <Card.Header className="p-0">
        <Button
          variant="light"
          className="w-100 d-flex align-items-center fw-semibold p-2"
          onClick={() => setOpen(!open)}
          style={{ fontSize: "0.85rem" }}
        >
          {title}
          <span className="ms-auto">
            {open ? <Icon icon="caretUp" /> : <Icon icon="caretDown" />}
          </span>
        </Button>
      </Card.Header>

      <Collapse in={open}>
        <div className="p-2 border-top">
          <Table
            columns={columns}
            data={data}
            hideSearch
            headerStyle={{ fontSize: "0.8rem", width: "50%" }}
          />
        </div>
      </Collapse>
    </Card>
  );
}

function ContainerDeploymentItem({
  containerRef,
  imageDeployment,
  containerState,
}: {
  containerRef: DeploymentDetails_networkDeployments$key &
    DeploymentDetails_volumeDeployments$key &
    DeploymentDetails_deviceMappingDeployments$key;
  imageDeployment: ImageDeployment | null;
  containerState: string | null;
}) {
  const networkData = useFragment<DeploymentDetails_networkDeployments$key>(
    DEPLOYMENT_DETAILS_NETWORK_DEPLOYMENTS_FRAGMENT,
    containerRef,
  );

  const volumeData = useFragment<DeploymentDetails_volumeDeployments$key>(
    DEPLOYMENT_DETAILS_VOLUME_DEPLOYMENTS_FRAGMENT,
    containerRef,
  );

  const deviceMappingData =
    useFragment<DeploymentDetails_deviceMappingDeployments$key>(
      DEPLOYMENT_DETAILS_DEVICE_MAPPING_DEPLOYMENTS_FRAGMENT,
      containerRef,
    );

  const networkNodes: ContainerNetworkNode[] =
    networkData?.networkDeployments?.edges?.map((e) => e.node) ?? [];

  const volumeNodes: ContainerVolumeNode[] =
    volumeData?.volumeDeployments?.edges?.map((e) => e.node) ?? [];

  const deviceMapNodes: ContainerDeviceMappingNode[] =
    deviceMappingData?.deviceMappingDeployments?.edges?.map((e) => e.node) ??
    [];

  const [open, setOpen] = useState(true);

  return (
    <div className="mb-2 border rounded">
      <Button
        variant="light"
        className="w-100 d-flex align-items-center fw-semibold p-2"
        onClick={() => setOpen(!open)}
        style={{ fontSize: "0.9rem" }}
      >
        Container: {imageDeployment?.image?.reference}
        <span className="ms-auto">
          {open ? <Icon icon="caretUp" /> : <Icon icon="caretDown" />}
        </span>
      </Button>

      <Collapse in={open}>
        <div className="p-2 border-top">
          <Row className="mb-2 ">
            <span className="d-flex gap-2" style={{ fontSize: "0.85rem" }}>
              <strong>
                <FormattedMessage
                  id={"components.deploymentDetails.status"}
                  defaultMessage={"Status: "}
                />
              </strong>
              <ContainerStatus
                state={parseContainerState(containerState || undefined)}
              />
            </span>
          </Row>
          {imageDeployment && (
            <Row className="mb-3 ">
              <span className="d-flex gap-2" style={{ fontSize: "0.85rem" }}>
                <strong>
                  <FormattedMessage
                    id={"components.deploymentDetails.imageStatus"}
                    defaultMessage={" Image Deployment Status: "}
                  />
                </strong>
                {imageDeployment.state}
              </span>
            </Row>
          )}
          {networkNodes.length > 0 ? (
            <CollapsibleTable
              title={`Networks Deployments`}
              columns={[
                {
                  header: "Label",
                  accessorKey: "network.label",
                },
                {
                  header: "Status",
                  accessorKey: "state",
                },
              ]}
              data={networkNodes}
            />
          ) : (
            <p style={{ fontSize: "0.85rem", opacity: 0.7 }}>
              No Network Deployments
            </p>
          )}

          {volumeNodes.length > 0 ? (
            <CollapsibleTable
              title={`Volume Deployments`}
              columns={[
                {
                  header: "Label",
                  accessorKey: "volume.label",
                },
                {
                  header: "Status",
                  accessorKey: "state",
                },
              ]}
              data={volumeNodes}
            />
          ) : (
            <p style={{ fontSize: "0.85rem", opacity: 0.7 }}>
              No Volume Deployments
            </p>
          )}

          {deviceMapNodes.length > 0 ? (
            <CollapsibleTable
              title={`Device Mappings Deployments`}
              columns={[
                {
                  header: "Path On Host -> Path In Container",
                  accessorFn: (row: any) =>
                    `${row.deviceMapping.pathOnHost} → ${row.deviceMapping.pathInContainer}`,
                },
                {
                  header: "Status",
                  accessorKey: "state",
                },
              ]}
              data={deviceMapNodes}
            />
          ) : (
            <p style={{ fontSize: "0.85rem", opacity: 0.7 }}>
              No Device Mapping Deployments
            </p>
          )}
        </div>
      </Collapse>
    </div>
  );
}

interface DetailItemProps {
  label: React.ReactNode;
  children: React.ReactNode;
}
const DetailItem = ({ label, children }: DetailItemProps) => (
  <div className="d-flex flex-column mb-3">
    <div className="fw-semibold">{label}</div>
    <div>{children}</div>
  </div>
);

type DeploymentDetailsProps = {
  deploymentRef: Deployment;
};

const DeploymentDetails = ({ deploymentRef }: DeploymentDetailsProps) => {
  const { data: eventsData } = usePaginationFragment<
    DeploymentEventsPaginationQuery,
    DeploymentDetails_events$key
  >(DEPLOYMENT_DETAILS_EVENTS_PAGINATION_FRAGMENT, deploymentRef);

  const { data: containerDeploymentsData } = usePaginationFragment<
    DeploymentContainerDeploymentsPaginationQuery,
    DeploymentDetails_containerDeployments$key
  >(DEPLOYMENT_DETAILS_CONTAINER_DEPLOYMENTS_FRAGMENT, deploymentRef);

  const events: Event[] = eventsData?.events?.edges?.map((e) => e.node) ?? [];

  const containerRefs =
    containerDeploymentsData?.containerDeployments?.edges?.map((e) => e.node) ??
    [];
  const applicationName = deploymentRef.release?.application?.name || "Unknown";
  const applicationId = deploymentRef.release?.application?.id || "Unknown";
  const releaseVersion = deploymentRef.release?.version || "Unknown";
  const releaseId = deploymentRef.release?.id || "Unknown";
  const deploymentState = parseDeploymentState(
    deploymentRef.state || undefined,
  );
  const isReady = deploymentRef.isReady;

  const intl = useIntl();
  return (
    <div>
      <Card className="mb-4">
        <Card.Body>
          <Row className="d-flex flex-column flex-md-row flex-wrap">
            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.deploymentDetails.applicationName"
                    defaultMessage="Application Name"
                  />
                }
              >
                <Link route={Route.application} params={{ applicationId }}>
                  {applicationName}
                </Link>
              </DetailItem>
            </Col>

            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.deploymentDetails.releaseVersion"
                    defaultMessage="Release Version"
                  />
                }
              >
                <Link
                  route={Route.release}
                  params={{ applicationId, releaseId }}
                >
                  {releaseVersion}
                </Link>
              </DetailItem>
            </Col>

            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.deploymentDetails.deploymentStatus"
                    defaultMessage="Deployment Status"
                  />
                }
              >
                <DeploymentStateComponent
                  state={deploymentState}
                  isReady={isReady}
                />
              </DetailItem>
            </Col>

            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.deploymentDetails.readiness"
                    defaultMessage="Readiness"
                  />
                }
              >
                <DeploymentReadiness isReady={isReady} />
              </DetailItem>
            </Col>
          </Row>
        </Card.Body>
      </Card>

      <Tabs
        defaultActiveKey="container-deployments"
        id="deployment-details-tabs"
        className="mb-3"
      >
        <Tab
          eventKey="container-deployments"
          title={intl.formatMessage({
            id: "components.deploymentDetails.containerDeploymentsTab",
            defaultMessage: "Container Deployments",
          })}
        >
          <div>
            {containerRefs.length === 0 ? (
              <div className="p-2">No container deployments</div>
            ) : (
              containerRefs.map((ref, idx) => (
                <ContainerDeploymentItem
                  key={idx}
                  containerRef={ref}
                  imageDeployment={ref.imageDeployment}
                  containerState={ref.state}
                />
              ))
            )}
          </div>
        </Tab>

        <Tab
          eventKey="events"
          title={intl.formatMessage({
            id: "components.deploymentDetails.eventsTab",
            defaultMessage: "Events",
          })}
        >
          <Table
            columns={eventColumns}
            data={events}
            headerStyle={{ fontSize: "0.9rem", width: "33.3%" }}
          />
        </Tab>
      </Tabs>
    </div>
  );
};

export default DeploymentDetails;
