/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { useState } from "react";
import { Card, Col, Collapse, Row, Tab, Tabs } from "react-bootstrap";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment, usePaginationFragment } from "react-relay";

import type { Deployment_getDeployment_Query$data } from "@/api/__generated__/Deployment_getDeployment_Query.graphql";
import type { DeploymentContainerDeploymentsPaginationQuery } from "@/api/__generated__/DeploymentContainerDeploymentsPaginationQuery.graphql";
import type {
  DeploymentDetails_containerDeployments$data,
  DeploymentDetails_containerDeployments$key,
} from "@/api/__generated__/DeploymentDetails_containerDeployments.graphql";
import type {
  DeploymentDetails_deviceMappingDeployments$data,
  DeploymentDetails_deviceMappingDeployments$key,
} from "@/api/__generated__/DeploymentDetails_deviceMappingDeployments.graphql";
import type {
  DeploymentDetails_events$data,
  DeploymentDetails_events$key,
} from "@/api/__generated__/DeploymentDetails_events.graphql";
import type {
  DeploymentDetails_networkDeployments$data,
  DeploymentDetails_networkDeployments$key,
} from "@/api/__generated__/DeploymentDetails_networkDeployments.graphql";
import type {
  DeploymentDetails_volumeDeployments$data,
  DeploymentDetails_volumeDeployments$key,
} from "@/api/__generated__/DeploymentDetails_volumeDeployments.graphql";
import type { DeploymentEventsPaginationQuery } from "@/api/__generated__/DeploymentEventsPaginationQuery.graphql";

import ContainerStatus, {
  parseContainerState,
} from "@/components/ContainerStatus";
import Table, { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";
import Button from "./Button";
import DeploymentReadiness from "./DeploymentReadiness";
import DeploymentStateComponent, {
  parseDeploymentState,
} from "./DeploymentState";
import Icon from "./Icon";

const DEPLOYMENT_DETAILS_EVENTS_PAGINATION_FRAGMENT = graphql`
  fragment DeploymentDetails_events on Deployment
  @refetchable(queryName: "DeploymentEventsPaginationQuery") {
    id
    events(
      first: $first
      after: $after
      sort: [{ field: INSERTED_AT, order: DESC }]
    ) @connection(key: "DeploymentDetails_events") {
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

type Deployment = Deployment_getDeployment_Query$data["deployment"];

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

const eventColumnHelper = createColumnHelper<Event>();

const eventColumns = [
  eventColumnHelper.accessor("type", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.eventType"
        defaultMessage="Type"
      />
    ),
    cell: ({ row }) => row.original.type ?? "",
  }),

  eventColumnHelper.accessor("insertedAt", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.eventTimestamp"
        defaultMessage="Timestamp"
      />
    ),
    cell: ({ row }) => {
      const date = new Date(row.original.insertedAt);

      return (
        <>
          {new Intl.DateTimeFormat("en-US", {
            year: "numeric",
            month: "long",
            day: "numeric",
            hour: "numeric",
            minute: "numeric",
            second: "numeric",
            fractionalSecondDigits: 3,
          }).format(date)}
        </>
      );
    },
  }),

  eventColumnHelper.accessor("message", {
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

const networkColumnHelper = createColumnHelper<ContainerNetworkNode>();

const networkColumns = [
  networkColumnHelper.accessor("network.label", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.networkLabel"
        defaultMessage="Label"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.networksEdit}
        params={{ networkId: row.original.network?.id || "" }}
      >
        {getValue()}
      </Link>
    ),
  }),
  networkColumnHelper.accessor("state", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.networkState"
        defaultMessage="State"
      />
    ),
    cell: ({ row }) => row.original.state ?? "",
  }),
];

const volumeColumnHelper = createColumnHelper<ContainerVolumeNode>();

const volumeColumns = [
  volumeColumnHelper.accessor("volume.label", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.volumeLabel"
        defaultMessage="Label"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.volumeEdit}
        params={{ volumeId: row.original.volume?.id || "" }}
      >
        {getValue()}
      </Link>
    ),
  }),
  volumeColumnHelper.accessor("state", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.volumeState"
        defaultMessage="State"
      />
    ),
    cell: ({ row }) => row.original.state ?? "",
  }),
];

const deviceMappingColumnHelper =
  createColumnHelper<ContainerDeviceMappingNode>();

const deviceMappingColumns = [
  deviceMappingColumnHelper.accessor((row) => row.deviceMapping, {
    id: "deviceMapping",
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.PathMappings"
        defaultMessage="Path On Host → Path In Container"
      />
    ),
    cell: ({ row }) => {
      const mapping = row.original.deviceMapping;
      if (!mapping) return null;
      return (
        <span className="font-mono text-sm text-gray-700">
          {mapping.pathOnHost} → {mapping.pathInContainer}
        </span>
      );
    },
  }),
  deviceMappingColumnHelper.accessor("state", {
    header: () => (
      <FormattedMessage
        id="components.DeploymentDetails.deviceMappingState"
        defaultMessage="State"
      />
    ),
    cell: ({ row }) => row.original.state ?? "",
  }),
];

interface CollapsibleTableProps {
  title: string;
  columns: any;
  data: any[];
  headerStyle?: React.CSSProperties;
}
const CollapsibleTable = ({
  title,
  columns,
  data,
  headerStyle,
}: CollapsibleTableProps) => {
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
            headerStyle={headerStyle}
          />
        </div>
      </Collapse>
    </Card>
  );
};

interface ContainerDeploymentItemProps {
  containerRef: DeploymentDetails_networkDeployments$key &
    DeploymentDetails_volumeDeployments$key &
    DeploymentDetails_deviceMappingDeployments$key;
  imageDeployment: ImageDeployment | null;
  containerState: string | null;
}
const ContainerDeploymentItem = ({
  containerRef,
  imageDeployment,
  containerState,
}: ContainerDeploymentItemProps) => {
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
        <span>{imageDeployment?.image?.reference}</span>

        <span className="ms-auto d-inline-flex gap-2 justify-content-center align-items-center">
          <ContainerStatus
            state={parseContainerState(containerState || undefined)}
          />
          {open ? <Icon icon="caretUp" /> : <Icon icon="caretDown" />}
        </span>
      </Button>

      <Collapse in={open}>
        <div className="p-2 border-top">
          {imageDeployment && (
            <Row className="mb-3 ">
              <span className="d-flex gap-2 small">
                <strong>
                  <FormattedMessage
                    id={"components.deploymentDetails.imageStatus"}
                    defaultMessage={" Image Status: "}
                  />
                </strong>
                {imageDeployment.state}
              </span>
            </Row>
          )}
          {networkNodes.length > 0 ? (
            <CollapsibleTable
              title={`Networks`}
              columns={networkColumns}
              data={networkNodes}
              headerStyle={{ fontSize: "0.8rem", width: "50%" }}
            />
          ) : (
            <p
              className="fst-italic ms-1"
              style={{ fontSize: "0.85rem", opacity: 0.7 }}
            >
              <FormattedMessage
                id={"components.deploymentDetails.noNetworksMessage"}
                defaultMessage={"No Networks"}
              />
            </p>
          )}

          {volumeNodes.length > 0 ? (
            <CollapsibleTable
              title={`Volumes`}
              columns={volumeColumns}
              data={volumeNodes}
              headerStyle={{ fontSize: "0.8rem", width: "50%" }}
            />
          ) : (
            <p
              className="fst-italic ms-1"
              style={{ fontSize: "0.85rem", opacity: 0.7 }}
            >
              <FormattedMessage
                id={"components.deploymentDetails.noVolumesMessage"}
                defaultMessage={"No Volumes"}
              />
            </p>
          )}

          {deviceMapNodes.length > 0 ? (
            <CollapsibleTable
              title={`Device Mappings`}
              columns={deviceMappingColumns}
              data={deviceMapNodes}
              headerStyle={{ fontSize: "0.8rem", width: "50%" }}
            />
          ) : (
            <p
              className="fst-italic ms-1"
              style={{ fontSize: "0.85rem", opacity: 0.7 }}
            >
              <FormattedMessage
                id={"components.deploymentDetails.noDeviceMappingsMessage"}
                defaultMessage={"No Device Mappings"}
              />
            </p>
          )}
        </div>
      </Collapse>
    </div>
  );
};

interface DetailItemProps {
  label: React.ReactNode;
  children: React.ReactNode;
}
const DetailItem = ({ label, children }: DetailItemProps) => (
  <div className="d-flex flex-sm-column flex-md-row flex-wrap mb-3 gap-2">
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
  const applicationName =
    deploymentRef?.release?.application?.name || "Unknown";
  const applicationId = deploymentRef?.release?.application?.id || "Unknown";
  const releaseVersion = deploymentRef?.release?.version || "Unknown";
  const releaseId = deploymentRef?.release?.id || "Unknown";
  const deploymentState = parseDeploymentState(
    deploymentRef?.state || undefined,
  );
  const isReady = deploymentRef?.isReady;

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
                    defaultMessage="Application Name: "
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
                    defaultMessage="Release Version: "
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
                    id="components.deploymentDetails.Status"
                    defaultMessage="Status: "
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
                    defaultMessage="Readiness: "
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
        defaultActiveKey="containers"
        id="deployment-details-tabs"
        className="mb-3"
      >
        <Tab
          eventKey="containers"
          title={intl.formatMessage({
            id: "components.deploymentDetails.containersTab",
            defaultMessage: "Containers",
          })}
        >
          <div>
            {containerRefs.length === 0 ? (
              <div className="p-2">No containers</div>
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
