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

import { useCallback, useMemo, useState } from "react";
import { Card, Col, Row } from "react-bootstrap";
import Tree, { useTreeState } from "react-hyper-tree";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  useFragment,
  useMutation,
  usePaginationFragment,
} from "react-relay";
import { useParams } from "react-router-dom";
import Select, { SingleValue } from "react-select";
import semver from "semver";

import type { Deployment_getDeployment_Query$data } from "@/api/__generated__/Deployment_getDeployment_Query.graphql";
import type { DeploymentContainerDeploymentsPaginationQuery } from "@/api/__generated__/DeploymentContainerDeploymentsPaginationQuery.graphql";
import type { DeploymentDetails_containerDeployments$key } from "@/api/__generated__/DeploymentDetails_containerDeployments.graphql";
import type { DeploymentDetails_deleteDeployment_Mutation } from "@/api/__generated__/DeploymentDetails_deleteDeployment_Mutation.graphql";
import type { DeploymentDetails_deviceMappingDeployments$key } from "@/api/__generated__/DeploymentDetails_deviceMappingDeployments.graphql";
import type {
  DeploymentDetails_events$data,
  DeploymentDetails_events$key,
} from "@/api/__generated__/DeploymentDetails_events.graphql";
import type { DeploymentDetails_networkDeployments$key } from "@/api/__generated__/DeploymentDetails_networkDeployments.graphql";
import type { DeploymentDetails_sendDeployment_Mutation } from "@/api/__generated__/DeploymentDetails_sendDeployment_Mutation.graphql";
import type { DeploymentDetails_startDeployment_Mutation } from "@/api/__generated__/DeploymentDetails_startDeployment_Mutation.graphql";
import type { DeploymentDetails_stopDeployment_Mutation } from "@/api/__generated__/DeploymentDetails_stopDeployment_Mutation.graphql";
import type { DeploymentDetails_upgradeDeployment_Mutation } from "@/api/__generated__/DeploymentDetails_upgradeDeployment_Mutation.graphql";
import type { DeploymentDetails_volumeDeployments$key } from "@/api/__generated__/DeploymentDetails_volumeDeployments.graphql";
import type { DeploymentEventsPaginationQuery } from "@/api/__generated__/DeploymentEventsPaginationQuery.graphql";

import ConfirmModal from "@/components/ConfirmModal";
import DeleteModal from "@/components/DeleteModal";
import DeploymentActionButtons from "@/components/DeploymentActionButtons";
import DeploymentEventsCard from "@/components/DeploymentEventsCard";
import { parseDeploymentState } from "@/components/DeploymentState";
import Icon from "@/components/Icon";
import ResourceStateIcon from "@/components/ResourceStateIcon";
import { Link, Route, useNavigate } from "@/Navigation";
import FullHeightCard from "@/components/FullHeightCard";

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

const SEND_DEPLOYMENT_MUTATION = graphql`
  mutation DeploymentDetails_sendDeployment_Mutation($id: ID!) {
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
  mutation DeploymentDetails_startDeployment_Mutation($id: ID!) {
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
  mutation DeploymentDetails_stopDeployment_Mutation($id: ID!) {
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
  mutation DeploymentDetails_deleteDeployment_Mutation($id: ID!) {
    deleteDeployment(id: $id) {
      result {
        id
      }
    }
  }
`;

const UPGRADE_DEPLOYMENT_MUTATION = graphql`
  mutation DeploymentDetails_upgradeDeployment_Mutation(
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

type UpgradeTargetRelease = {
  id: string;
  version: string;
};

type SelectOption = {
  value: string;
  label: string;
  disabled: boolean;
};

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

type DeploymentDetailsProps = {
  deploymentRef: Deployment;
  isOnline: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

const DeploymentDetails = ({
  deploymentRef,
  isOnline,
  setErrorFeedback,
}: DeploymentDetailsProps) => {
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

  const {
    release,
    state,
    isReady = false,
    id: deploymentId,
  } = deploymentRef || {};

  const {
    application,
    version: releaseVersion,
    id: releaseId = "Unknown",
  } = release || {};

  const { name: applicationName = "Unknown", id: applicationId = "Unknown" } =
    application || {};

  const deploymentState = parseDeploymentState(state ?? undefined);

  const intl = useIntl();
  const navigate = useNavigate();
  const { deviceId } = useParams();

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);

  const [upgradeTargetRelease, setUpgradeTargetRelease] =
    useState<UpgradeTargetRelease | null>(null);

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

  const upgradeReleaseOptions: SelectOption[] = useMemo(() => {
    const releaseEdges = deploymentRef?.release?.application?.releases?.edges;
    const currentVersion = deploymentRef?.release?.version;

    if (!releaseEdges || !currentVersion) {
      return [];
    }

    return releaseEdges
      .flatMap((edge) => (edge?.node ? [edge.node] : []))
      .filter((release) => {
        if (release.version === currentVersion) {
          return false;
        }

        const parsedCurrentVersion = semver.valid(currentVersion);
        const parsedTargetVersion = semver.valid(release.version);

        if (!parsedCurrentVersion || !parsedTargetVersion) {
          return true;
        }

        return semver.gt(parsedTargetVersion, parsedCurrentVersion);
      })
      .map((release) => ({
        value: release.id,
        label: release.version,
        disabled: false,
      }));
  }, [
    deploymentRef?.release?.application?.releases?.edges,
    deploymentRef?.release?.version,
  ]);

  const selectedUpgradeReleaseOption = useMemo(() => {
    return (
      upgradeReleaseOptions.find(
        (option) => option.value === upgradeTargetRelease?.id,
      ) || null
    );
  }, [upgradeReleaseOptions, upgradeTargetRelease?.id]);

  const [sendDeployment] =
    useMutation<DeploymentDetails_sendDeployment_Mutation>(
      SEND_DEPLOYMENT_MUTATION,
    );
  const [startDeployment] =
    useMutation<DeploymentDetails_startDeployment_Mutation>(
      START_DEPLOYMENT_MUTATION,
    );
  const [stopDeployment] =
    useMutation<DeploymentDetails_stopDeployment_Mutation>(
      STOP_DEPLOYMENT_MUTATION,
    );

  const [deleteDeployment, isDeletingDeployment] =
    useMutation<DeploymentDetails_deleteDeployment_Mutation>(
      DELETE_DEPLOYMENT_MUTATION,
    );

  const [upgradeDeployment] =
    useMutation<DeploymentDetails_upgradeDeployment_Mutation>(
      UPGRADE_DEPLOYMENT_MUTATION,
    );

  const handleSendDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="components.DeploymentDetails.sendErrorOffline"
            defaultMessage="The device is disconnected. You cannot deploy an application while it is offline."
          />,
        );
      }

      sendDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="components.DeploymentDetails.sendErrorFeedback"
              defaultMessage="Could not send the Application to the device, please try again."
            />,
          );
        },
      });
    },
    [isOnline, sendDeployment, setErrorFeedback],
  );

  const handleStartDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="components.DeploymentDetails.startErrorOffline"
            defaultMessage="The device is disconnected. You cannot start an application while it is offline."
          />,
        );
      }

      startDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="components.DeploymentDetails.startErrorFeedback"
              defaultMessage="Could not Start the Deployed Application, please try again."
            />,
          );
        },
      });
    },
    [isOnline, startDeployment, setErrorFeedback],
  );

  const handleStopDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="components.DeploymentDetails.stopErrorOffline"
            defaultMessage="The device is disconnected. You cannot stop an application while it is offline."
          />,
        );
      }

      stopDeployment({
        variables: { id: deploymentId },
        onCompleted: (_data, errors) => {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError: () => {
          setErrorFeedback(
            <FormattedMessage
              id="components.DeploymentDetails.stopErrorFeedback"
              defaultMessage="Could not Stop the Deployed Application, please try again."
            />,
          );
        },
      });
    },
    [isOnline, stopDeployment, setErrorFeedback],
  );

  const handleDeleteDeployedApplication = useCallback(
    (deploymentId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="components.DeploymentDetails.deleteErrorOffline"
            defaultMessage="The device is disconnected. You cannot delete an application while it is offline."
          />,
        );
      }

      deleteDeployment({
        variables: { id: deploymentId },

        onCompleted(_data, errors) {
          if (
            !errors ||
            errors.length === 0 ||
            errors[0].code === "not_found"
          ) {
            setErrorFeedback(null);
            setShowDeleteModal(false);
            if (deviceId) {
              navigate({
                route: Route.devicesEdit,
                params: { deviceId },
              });
            }
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
              id="components.DeploymentDetails.deletionErrorFeedback"
              defaultMessage="Could not delete the deployment, please try again."
            />,
          );
          setShowDeleteModal(false);
        },
      });
    },
    [deleteDeployment, setErrorFeedback, navigate, deviceId, isOnline],
  );

  const handleUpgradeDeployedRelease = useCallback(
    (deploymentId: string, upgradeTargetReleaseId: string) => {
      if (!isOnline) {
        return setErrorFeedback(
          <FormattedMessage
            id="components.DeploymentDetails.upgradeErrorOffline"
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
            if (deviceId && data.upgradeDeployment?.result?.id) {
              navigate({
                route: Route.deploymentEdit,
                params: {
                  deviceId,
                  deploymentId: data.upgradeDeployment?.result?.id,
                },
              });
            }
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
              id="components.DeploymentDetails.upgradeErrorFeedback"
              defaultMessage="Could not upgrade the deployment, please try again."
            />,
          );
          setShowUpgradeModal(false);
        },
      });
    },
    [upgradeDeployment, setErrorFeedback, isOnline, deviceId, navigate],
  );

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const handleShowUpgradeModal = useCallback(() => {
    setShowUpgradeModal(true);
  }, [setShowUpgradeModal]);

  return (
    <div className="d-flex flex-column h-100">
      <Card className="mb-4 flex-shrink-0">
        <Card.Body>
          <Row className="d-flex align-items-center justify-content-between flex-wrap">
            <Col
              className="d-flex flex-column flex-md-row align-items-md-center gap-4 ms-2"
              xs="auto"
            >
              <Link route={Route.application} params={{ applicationId }}>
                {applicationName}
              </Link>

              <Link route={Route.release} params={{ applicationId, releaseId }}>
                <FormattedMessage
                  id="components.DeploymentDetails.releaseVersion"
                  defaultMessage="v.{version}"
                  values={{ version: releaseVersion }}
                />
              </Link>
            </Col>

            <Col
              xs="auto"
              className="d-flex justify-content-end me-2 mt-2 mt-md-0"
            >
              <DeploymentActionButtons
                state={deploymentState}
                isReady={isReady}
                isDeleting={deploymentState === "DELETING"}
                onStart={() =>
                  deploymentId && handleStartDeployedApplication(deploymentId)
                }
                onStop={() =>
                  deploymentId && handleStopDeployedApplication(deploymentId)
                }
                onRedeploy={() =>
                  deploymentId && handleSendDeployedApplication(deploymentId)
                }
                onUpgrade={() => {
                  setUpgradeTargetRelease(null);
                  handleShowUpgradeModal();
                }}
                onDelete={() => {
                  handleShowDeleteModal();
                }}
              />
            </Col>
          </Row>
        </Card.Body>
      </Card>
      {showDeleteModal && (
        <DeleteModal
          confirmText={applicationName || ""}
          onCancel={() => setShowDeleteModal(false)}
          onConfirm={() => {
            if (deploymentRef?.id) {
              handleDeleteDeployedApplication(deploymentRef.id);
            }
            setShowDeleteModal(false);
          }}
          isDeleting={isDeletingDeployment}
          title={
            <FormattedMessage
              id="components.DeploymentDetails.deleteModal.title"
              defaultMessage="Delete Deployment"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.DeploymentDetails.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete the deployment."
            />
          </p>
          <p className="text-muted small">
            <FormattedMessage
              id="components.DeploymentDetails.deleteModal.note"
              defaultMessage="Note: A deletion request will be sent to the device to start the deletion process. Please note that it may take some time for the request to be processed. This is expected behavior."
            />
          </p>
        </DeleteModal>
      )}
      {showUpgradeModal && (
        <ConfirmModal
          confirmLabel={
            <FormattedMessage
              id="components.DeploymentDetails.confirmLabel"
              defaultMessage="Confirm"
            />
          }
          disabled={!deploymentRef || !upgradeTargetRelease}
          onCancel={() => {
            setShowUpgradeModal(false);
            setUpgradeTargetRelease(null);
          }}
          onConfirm={() => {
            if (deploymentRef && upgradeTargetRelease) {
              handleUpgradeDeployedRelease(
                deploymentRef.id,
                upgradeTargetRelease.id,
              );
            }
            setShowUpgradeModal(false);
            setUpgradeTargetRelease(null);
          }}
          title={
            <FormattedMessage
              id="components.DeploymentDetails.confirmModal.title"
              defaultMessage="Upgrade Deployment"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.DeploymentDetails.confirmModal.description"
              defaultMessage="Are you sure you want to upgrade the deployment <bold>{application}</bold> from version <bold>{currentVersion}</bold> to version:"
              values={{
                application: applicationName,
                currentVersion: releaseVersion,
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
              id: "components.DeploymentDetails.selectOption",
              defaultMessage: "Select a Release Version",
            })}
            noOptionsMessage={({ inputValue }) =>
              inputValue
                ? intl.formatMessage(
                    {
                      id: "components.DeploymentDetails.noReleasesFoundMatching",
                      defaultMessage:
                        'No release versions found matching "{inputValue}"',
                    },
                    { inputValue },
                  )
                : upgradeReleaseOptions.length === 0
                  ? intl.formatMessage({
                      id: "components.DeploymentDetails.noReleasesAvailable",
                      defaultMessage: "No Release Versions Available",
                    })
                  : intl.formatMessage({
                      id: "components.DeploymentDetails.selectOption",
                      defaultMessage: "Select a Release Version",
                    })
            }
            filterOption={(option, inputValue) => {
              // Search by release version label only.
              return option.label
                .toLowerCase()
                .includes(inputValue.toLowerCase());
            }}
          />
        </ConfirmModal>
      )}
      <div
        className="flex-md-fill"
        style={{
          minHeight: 0,
        }}
      >
        <Row className="align-items-stretch h-100">
          <FullHeightCard md={4} xs={12} className="h-100">
            <Card.Body className="d-flex flex-column overflow-auto me-3">
              {containerNodes.length === 0 ? (
                <div className="p-2">
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
            </Card.Body>
          </FullHeightCard>

          <DeploymentEventsCard events={events} className="h-100" />
        </Row>
      </div>
    </div>
  );
};

export default DeploymentDetails;
