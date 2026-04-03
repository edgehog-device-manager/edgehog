// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
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

import { useMemo } from "react";
import { Card, Col, Row, Tab, Tabs } from "react-bootstrap";
import Tree, { useTreeState } from "react-hyper-tree";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment, usePaginationFragment } from "react-relay";

import type { Deployment_getDeployment_Query$data } from "@/api/__generated__/Deployment_getDeployment_Query.graphql";
import type { DeploymentContainerDeploymentsPaginationQuery } from "@/api/__generated__/DeploymentContainerDeploymentsPaginationQuery.graphql";
import type { DeploymentDetails_containerDeployments$key } from "@/api/__generated__/DeploymentDetails_containerDeployments.graphql";
import type { DeploymentDetails_deviceMappingDeployments$key } from "@/api/__generated__/DeploymentDetails_deviceMappingDeployments.graphql";
import type {
  DeploymentDetails_events$data,
  DeploymentDetails_events$key,
} from "@/api/__generated__/DeploymentDetails_events.graphql";
import type { DeploymentDetails_networkDeployments$key } from "@/api/__generated__/DeploymentDetails_networkDeployments.graphql";
import type { DeploymentDetails_volumeDeployments$key } from "@/api/__generated__/DeploymentDetails_volumeDeployments.graphql";
import type { DeploymentEventsPaginationQuery } from "@/api/__generated__/DeploymentEventsPaginationQuery.graphql";

import { Link, Route } from "@/Navigation";
import DeploymentEventsCard from "./DeploymentEventsCard";
import DeploymentReadiness from "./DeploymentReadiness";
import DeploymentStateComponent, {
  parseDeploymentState,
} from "./DeploymentState";
import Icon from "./Icon";
import ResourceStateIcon from "./ResourceStateIcon";

/* eslint-disable relay/unused-fields */
const DEPLOYMENT_DETAILS_EVENTS_FRAGMENT = graphql`
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
          addInfo
          insertedAt
        }
      }
    }
  }
`;

/* eslint-disable relay/unused-fields */
const DEPLOYMENT_DETAILS_CONTAINER_DEPLOYMENTS_FRAGMENT = graphql`
  fragment DeploymentDetails_containerDeployments on Deployment
  @refetchable(queryName: "DeploymentContainerDeploymentsPaginationQuery") {
    containerDeployments(first: $first, after: $after)
      @connection(key: "DeploymentDetails_containerDeployments") {
      edges {
        node {
          id
          state
          isReady
          container {
            image {
              reference
            }
          }
          imageDeployment {
            state
            isReady
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
          isReady
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
          isReady
          volume {
            id
            label
          }
        }
      }
    }
  }
`;

/* eslint-disable relay/unused-fields */
const DEPLOYMENT_DETAILS_DEVICE_MAPPING_DEPLOYMENTS_FRAGMENT = graphql`
  fragment DeploymentDetails_deviceMappingDeployments on ContainerDeployment {
    id
    deviceMappingDeployments(first: $first, after: $after) {
      edges {
        node {
          id
          state
          isReady
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
export type Event = NonNullable<
  NonNullable<DeploymentDetails_events$data["events"]["edges"]>[number]["node"]
>;

type TreeNode = {
  id: string;
  name: string;
  type?: "node" | "leaf";
  state?: string | null;
  isReady?: boolean | null;
  children?: TreeNode[];
};

const buildSubTree = (
  prefix: string,
  category: string,
  nodes: any[],
  labelExtractor: (node: any) => string,
  intlLabels: { title: string; empty: string; unnamed: string },
): TreeNode => {
  const children: TreeNode[] =
    nodes.length > 0
      ? nodes.map((n) => ({
          id: `${prefix}-${category}-${n.id}`,
          name: labelExtractor(n) || intlLabels.unnamed,
          type: "leaf",
          state: n.state,
          isReady: n.isReady,
          children: [],
        }))
      : [
          {
            id: `${prefix}-${category}-none`,
            name: intlLabels.empty,
            type: "leaf",
            state: undefined,
            isReady: null,
            children: [],
          },
        ];

  return {
    id: `${prefix}-${category}-root`,
    name: intlLabels.title,
    type: "node",
    children,
  };
};

interface ContainerDeploymentItemProps {
  index: number;
  containerFragmentKey: DeploymentDetails_networkDeployments$key &
    DeploymentDetails_volumeDeployments$key &
    DeploymentDetails_deviceMappingDeployments$key;
  imageDeployment: any;
  containerState: string;
  isReady: boolean | null;
}

const ContainerDeploymentItem = ({
  index,
  containerFragmentKey,
  imageDeployment,
  containerState,
  isReady,
}: ContainerDeploymentItemProps) => {
  const intl = useIntl();
  const prefix = `container-${index}`;

  const networkData = useFragment<DeploymentDetails_networkDeployments$key>(
    DEPLOYMENT_DETAILS_NETWORK_DEPLOYMENTS_FRAGMENT,
    containerFragmentKey,
  );

  const volumeData = useFragment<DeploymentDetails_volumeDeployments$key>(
    DEPLOYMENT_DETAILS_VOLUME_DEPLOYMENTS_FRAGMENT,
    containerFragmentKey,
  );

  const deviceMappingData =
    useFragment<DeploymentDetails_deviceMappingDeployments$key>(
      DEPLOYMENT_DETAILS_DEVICE_MAPPING_DEPLOYMENTS_FRAGMENT,
      containerFragmentKey,
    );

  const treeData: TreeNode[] = useMemo(() => {
    const unnamed = intl.formatMessage({
      id: "components.DeploymentDetails.unnamed",
      defaultMessage: "Unnamed",
    });
    const empty = intl.formatMessage({
      id: "components.DeploymentDetails.none",
      defaultMessage: "None",
    });

    const networkSubTree = buildSubTree(
      prefix,
      "network",
      networkData?.networkDeployments?.edges?.map((e) => e.node) ?? [],
      (n) => n.network?.label,
      {
        title: intl.formatMessage({
          id: "components.DeploymentDetails.networks",
          defaultMessage: "Networks",
        }),
        empty,
        unnamed,
      },
    );

    const volumeSubTree = buildSubTree(
      prefix,
      "volume",
      volumeData?.volumeDeployments?.edges?.map((e) => e.node) ?? [],
      (v) => v.volume?.label,
      {
        title: intl.formatMessage({
          id: "components.DeploymentDetails.volumes",
          defaultMessage: "Volumes",
        }),
        empty,
        unnamed,
      },
    );

    const deviceMappingsSubTree = buildSubTree(
      prefix,
      "device-mapping",
      deviceMappingData?.deviceMappingDeployments?.edges?.map((e) => e.node) ??
        [],
      (d) =>
        `${d.deviceMapping?.pathOnHost}->${d.deviceMapping.pathInContainer}`,
      {
        title: intl.formatMessage({
          id: "components.DeploymentDetails.deviceMappings",
          defaultMessage: "Device Mappings",
        }),
        empty,
        unnamed,
      },
    );

    const imageTreeNode: TreeNode = {
      id: `${prefix}-image-${imageDeployment?.image?.id}`,
      name:
        imageDeployment?.image?.reference ||
        intl.formatMessage({
          id: "components.DeploymentDetails.unnamedImage",
          defaultMessage: "Unnamed image",
        }),
      type: "leaf",
      state: imageDeployment?.state,
      isReady: imageDeployment?.isReady ?? null,
      children: [],
    };

    return [
      {
        id: `${prefix}-root`,
        name: intl.formatMessage(
          {
            id: "components.DeploymentDetails.containerWithIndex",
            defaultMessage: "Container {index}",
          },
          { index: index + 1 },
        ),
        type: "node",
        state: containerState,
        isReady,
        children: [
          imageTreeNode,
          deviceMappingsSubTree,
          volumeSubTree,
          networkSubTree,
        ],
      },
    ];
  }, [
    networkData,
    volumeData,
    deviceMappingData,
    imageDeployment,
    containerState,
    isReady,
    index,
    prefix,
    intl,
  ]);

  const { required, handlers } = useTreeState({
    data: treeData,
    defaultOpened: true,
    id: prefix,
  });

  return (
    <Tree
      {...required}
      {...handlers}
      renderNode={({ node, onToggle }) => {
        const { state, isReady, name, type } = node.data ?? {};
        const isNode = type === "node";

        return (
          <div
            className="d-flex align-items-center gap-2 py-1 px-1"
            style={{ cursor: isNode ? "pointer" : "default" }}
            onClick={(e) => isNode && onToggle(e)}
          >
            {isNode && (
              <span
                style={{
                  display: "inline-flex",
                  transition: "transform 0.2s ease-in-out",
                  transform: node.isOpened()
                    ? "rotate(0deg)"
                    : "rotate(-90deg)",
                }}
              >
                <Icon icon="caretDown" />
              </span>
            )}
            <span className={`node-name ${isNode ? "fw-bold" : ""}`}>
              {name}
            </span>

            <ResourceStateIcon state={state} isReady={isReady} />
          </div>
        );
      }}
    />
  );
};

const DetailItem = ({
  label,
  children,
}: {
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <div className="d-flex flex-sm-column flex-md-row flex-wrap mb-3 gap-2">
    <div className="fw-semibold text-muted">{label}</div>
    <div>{children}</div>
  </div>
);

const DeploymentDetails = ({
  deploymentRef,
}: {
  deploymentRef: Deployment;
}) => {
  const intl = useIntl();

  const { data: eventsData } = usePaginationFragment<
    DeploymentEventsPaginationQuery,
    DeploymentDetails_events$key
  >(DEPLOYMENT_DETAILS_EVENTS_FRAGMENT, deploymentRef);

  const { data: containersData } = usePaginationFragment<
    DeploymentContainerDeploymentsPaginationQuery,
    DeploymentDetails_containerDeployments$key
  >(DEPLOYMENT_DETAILS_CONTAINER_DEPLOYMENTS_FRAGMENT, deploymentRef);

  const events = eventsData?.events?.edges?.map((e) => e.node) ?? [];
  const containerNodes =
    containersData?.containerDeployments?.edges?.map((e) => e.node) ?? [];

  const { release, state, isReady } = deploymentRef || {};
  const { application, version: releaseVersion, id: releaseId } = release || {};

  return (
    <div>
      <Card className="mb-4">
        <Card.Body>
          <Row className="d-flex flex-column flex-md-row flex-wrap">
            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.DeploymentDetails.applicationName"
                    defaultMessage="Application Name: "
                  />
                }
              >
                <Link
                  route={Route.application}
                  params={{ applicationId: application?.id || "unknown" }}
                >
                  {application?.name || "Unknown"}
                </Link>
              </DetailItem>
            </Col>
            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.DeploymentDetails.releaseVersion"
                    defaultMessage="Release Version: "
                  />
                }
              >
                <Link
                  route={Route.release}
                  params={{
                    applicationId: application?.id || "unknown",
                    releaseId: releaseId || "unknown",
                  }}
                >
                  {releaseVersion || "Unknown"}
                </Link>
              </DetailItem>
            </Col>
            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.DeploymentDetails.status"
                    defaultMessage="Status: "
                  />
                }
              >
                <DeploymentStateComponent
                  state={parseDeploymentState(state || undefined)}
                  isReady={isReady}
                />
              </DetailItem>
            </Col>
            <Col sm={12} lg={3}>
              <DetailItem
                label={
                  <FormattedMessage
                    id="components.DeploymentDetails.readiness"
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
            id: "components.DeploymentDetails.containersTab",
            defaultMessage: "Containers",
          })}
        >
          <div className="px-3 d-flex flex-column gap-3">
            {containerNodes.length === 0 ? (
              <div className="p-3 text-muted italic">
                <FormattedMessage
                  id="components.DeploymentDetails.noContainers"
                  defaultMessage="No containers"
                />
              </div>
            ) : (
              containerNodes.map((node, idx) => (
                <ContainerDeploymentItem
                  key={node.id || idx}
                  index={idx}
                  containerFragmentKey={node}
                  imageDeployment={node.imageDeployment}
                  containerState={node.state || ""}
                  isReady={node.isReady}
                />
              ))
            )}
          </div>
        </Tab>

        <Tab
          eventKey="events"
          title={intl.formatMessage({
            id: "components.DeploymentDetails.eventsTab",
            defaultMessage: "Events",
          })}
        >
          <DeploymentEventsCard events={events} />
        </Tab>
      </Tabs>
    </div>
  );
};

export default DeploymentDetails;
