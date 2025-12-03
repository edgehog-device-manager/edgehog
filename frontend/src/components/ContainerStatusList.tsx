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

import { FormattedMessage, useIntl } from "react-intl";
import { useState } from "react";
import { Col, Collapse, Container, Row } from "react-bootstrap";

import ContainerStatus, {
  parseContainerState,
} from "@/components/ContainerStatus";
import Icon from "@/components/Icon";
import Tag from "@/components/Tag";

interface ContainerDeployment {
  id: string;
  state: string | null;
  container: {
    image: {
      reference: string;
    };
  } | null;
}

interface Props {
  containerDeployments: ContainerDeployment[];
  isExpanded?: boolean;
  onToggleExpanded?: () => void;
}

const ContainerStatusList = ({
  containerDeployments,
  isExpanded: externalIsExpanded,
  onToggleExpanded,
}: Props) => {
  const intl = useIntl();

  const [internalIsExpanded, setInternalIsExpanded] = useState(false);

  const isExpanded =
    externalIsExpanded !== undefined ? externalIsExpanded : internalIsExpanded;

  const toggleExpanded =
    onToggleExpanded || (() => setInternalIsExpanded(!internalIsExpanded));

  if (!containerDeployments || containerDeployments.length === 0) {
    return (
      <div className="text-muted fst-italic">
        <FormattedMessage
          id="components.ContainerStatusList.noContainers"
          defaultMessage="No containers"
        />
      </div>
    );
  }

  const statusCounts = containerDeployments.reduce(
    (acc, containerDeployment) => {
      const state = parseContainerState(containerDeployment.state || undefined);
      acc[state] = (acc[state] || 0) + 1;
      return acc;
    },
    {} as Record<string, number>,
  );

  const totalContainers = containerDeployments.length;
  const runningCount = statusCounts.RUNNING || 0;
  const exitedCount = statusCounts.EXITED || 0;
  const deadCount = statusCounts.DEAD || 0;
  const restartingCount = statusCounts.RESTARTING || 0;
  const removingCount = statusCounts.REMOVING || 0;

  return (
    <div>
      <div
        className="d-flex align-items-center cursor-pointer user-select-none"
        onClick={toggleExpanded}
        style={{ cursor: "pointer" }}
        role="button"
        aria-expanded={isExpanded}
        title={
          isExpanded
            ? intl.formatMessage({
                id: "components.ContainerStatusList.collapseContainerList",
                defaultMessage: "Collapse container list",
              })
            : intl.formatMessage({
                id: "components.ContainerStatusList.expandContainerList",
                defaultMessage: "Expand container list",
              })
        }
      >
        <Tag className="bg-secondary me-1 small">{totalContainers}</Tag>

        {runningCount > 0 && (
          <Tag className="bg-success me-1 small">
            <FormattedMessage
              id="components.ContainerStatusList.runningCount"
              defaultMessage="{count} running"
              values={{ count: runningCount }}
            />
          </Tag>
        )}

        {exitedCount > 0 && (
          <Tag className="bg-secondary me-1 small">
            <FormattedMessage
              id="components.ContainerStatusList.exitedCount"
              defaultMessage="{count} exited"
              values={{ count: exitedCount }}
            />
          </Tag>
        )}

        {deadCount > 0 && (
          <Tag className="bg-danger me-1 small">
            <FormattedMessage
              id="components.ContainerStatusList.deadCount"
              defaultMessage="{count} dead"
              values={{ count: deadCount }}
            />
          </Tag>
        )}

        {(restartingCount > 0 || removingCount > 0) && (
          <Tag className="bg-warning me-1 small">
            <FormattedMessage
              id="components.ContainerStatusList.processingCount"
              defaultMessage="{count} processing"
              values={{ count: restartingCount + removingCount }}
            />
          </Tag>
        )}

        <Icon
          icon={isExpanded ? "caretUp" : "caretDown"}
          className="text-secondary ms-2"
          size="sm"
        />
      </div>

      <Collapse in={isExpanded}>
        <div className="mt-2">
          {containerDeployments.map((containerDeployment) => (
            <Container key={containerDeployment.id}>
              <Row className="justify-content-between align-items-center">
                <Col>
                  <small className="text-muted">
                    <FormattedMessage
                      id="components.ContainerStatusList.containerReference"
                      defaultMessage="{reference}"
                      values={{
                        reference:
                          containerDeployment.container?.image?.reference ||
                          "Unknown",
                      }}
                    />
                  </small>
                </Col>

                <Col>
                  <ContainerStatus
                    state={parseContainerState(
                      containerDeployment.state || undefined,
                    )}
                  />
                </Col>
              </Row>
            </Container>
          ))}
        </div>
      </Collapse>
    </div>
  );
};

export default ContainerStatusList;
