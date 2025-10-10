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

import { useState, useMemo, useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";

import type { DeploymentTargetStatus as DeploymentTargetStatusType } from "api/__generated__/DeploymentTargetsTabs_SuccessfulFragment.graphql";
import type { DeploymentTargetsTabs_SuccessfulFragment$key } from "api/__generated__/DeploymentTargetsTabs_SuccessfulFragment.graphql";
import type { DeploymentTargetsTabs_FailedFragment$key } from "api/__generated__/DeploymentTargetsTabs_FailedFragment.graphql";
import type { DeploymentTargetsTabs_InProgressFragment$key } from "api/__generated__/DeploymentTargetsTabs_InProgressFragment.graphql";
import type { DeploymentTargetsTabs_IdleFragment$key } from "api/__generated__/DeploymentTargetsTabs_IdleFragment.graphql";

import DeploymentTargetsTable, {
  columnIds,
} from "components/DeploymentTargetsTable";
import type { ColumnId } from "components/DeploymentTargetsTable";
import DeploymentTargetStatus from "components/DeploymentTargetStatus";

const DEPLOYMENT_TARGETS_TO_LOAD_NEXT = 10;

const DEPLOYMENT_TARGETS_SUCCESSFUL_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_SuccessfulFragment on DeploymentCampaign
  @refetchable(queryName: "DeploymentTargetsTabs_SuccessfulPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    successfulDeploymentTargets: deploymentTargets(
      first: $first
      after: $after
      filter: { status: { eq: SUCCESSFUL } }
    ) @connection(key: "DeploymentTargetsTabs_successfulDeploymentTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_DeploymentTargetsFragment
        }
      }
    }
  }
`;

const DEPLOYMENT_TARGETS_FAILED_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_FailedFragment on DeploymentCampaign
  @refetchable(queryName: "DeploymentTargetsTabs_FailedPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    failedDeploymentTargets: deploymentTargets(
      first: $first
      after: $after
      filter: { status: { eq: FAILED } }
    ) @connection(key: "DeploymentTargetsTabs_failedDeploymentTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_DeploymentTargetsFragment
        }
      }
    }
  }
`;

const DEPLOYMENT_TARGETS_IN_PROGRESS_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_InProgressFragment on DeploymentCampaign
  @refetchable(queryName: "DeploymentTargetsTabs_InProgressPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    inProgressDeploymentTargets: deploymentTargets(
      first: $first
      after: $after
      filter: { status: { eq: IN_PROGRESS } }
    ) @connection(key: "DeploymentTargetsTabs_inProgressDeploymentTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_DeploymentTargetsFragment
        }
      }
    }
  }
`;

const DEPLOYMENT_TARGETS_IDLE_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_IdleFragment on DeploymentCampaign
  @refetchable(queryName: "DeploymentTargetsTabs_IdlePaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    idleDeploymentTargets: deploymentTargets(
      first: $first
      after: $after
      filter: { status: { eq: IDLE } }
    ) @connection(key: "DeploymentTargetsTabs_idleDeploymentTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_DeploymentTargetsFragment
        }
      }
    }
  }
`;

const columnMap: Record<DeploymentTargetStatusType, ColumnId[]> = {
  IDLE: ["deviceName"],
  IN_PROGRESS: ["deviceName", "state", "readiness", "latestAttempt"],
  SUCCESSFUL: ["deviceName", "completionTimestamp"],
  FAILED: ["deviceName", "lastErrorMessage", "completionTimestamp"],
};

const deploymentTargetTabs: DeploymentTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

const tabConfig = {
  SUCCESSFUL: {
    fragment: DEPLOYMENT_TARGETS_SUCCESSFUL_FRAGMENT,
    dataField: "successfulDeploymentTargets",
  },
  FAILED: {
    fragment: DEPLOYMENT_TARGETS_FAILED_FRAGMENT,
    dataField: "failedDeploymentTargets",
  },
  IN_PROGRESS: {
    fragment: DEPLOYMENT_TARGETS_IN_PROGRESS_FRAGMENT,
    dataField: "inProgressDeploymentTargets",
  },
  IDLE: {
    fragment: DEPLOYMENT_TARGETS_IDLE_FRAGMENT,
    dataField: "idleDeploymentTargets",
  },
} as const;

const useActiveStatusPaginationFragment = (
  activeTab: DeploymentTargetStatusType,
  deploymentCampaignRef: any,
  isVisited: boolean,
) => {
  const config = tabConfig[activeTab];
  return usePaginationFragment(
    config.fragment,
    isVisited ? deploymentCampaignRef : null,
  );
};

type Props = {
  deploymentCampaignRef: DeploymentTargetsTabs_SuccessfulFragment$key &
    DeploymentTargetsTabs_FailedFragment$key &
    DeploymentTargetsTabs_InProgressFragment$key &
    DeploymentTargetsTabs_IdleFragment$key;
};

const DeploymentTargetsTabs = ({ deploymentCampaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<DeploymentTargetStatusType>("SUCCESSFUL");

  const [visitedTabs, setVisitedTabs] = useState<
    Set<DeploymentTargetStatusType>
  >(new Set(["SUCCESSFUL"]));

  const handleTabChange = useCallback((newTab: DeploymentTargetStatusType) => {
    setActiveTab(newTab);
    setVisitedTabs((prev) => new Set([...prev, newTab]));
  }, []);

  // Only runs one fragment hook (for the active tab)
  const currentTabFragment = useActiveStatusPaginationFragment(
    activeTab,
    deploymentCampaignRef,
    visitedTabs.has(activeTab),
  );

  const isTabDataLoading =
    !visitedTabs.has(activeTab) ||
    (visitedTabs.has(activeTab) && !currentTabFragment?.data);

  const visibleTargets = useMemo(() => {
    const config = tabConfig[activeTab];
    const deploymentTargetsField = currentTabFragment?.data?.[config.dataField];

    if (!deploymentTargetsField?.edges) return [];
    return deploymentTargetsField.edges
      .map((edge: any) => edge?.node)
      .filter(Boolean);
  }, [currentTabFragment?.data, activeTab]);

  const loadNextDeploymentTargets = useCallback(() => {
    if (currentTabFragment?.hasNext && !currentTabFragment?.isLoadingNext) {
      currentTabFragment.loadNext(DEPLOYMENT_TARGETS_TO_LOAD_NEXT);
    }
  }, [currentTabFragment]);

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[activeTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [activeTab]);

  if (!deploymentCampaignRef) return null;

  return (
    <div>
      <h3>
        <FormattedMessage
          id="components.DeploymentTargetsTabs.deploymentTargetsLabel"
          defaultMessage="Devices"
        />
      </h3>
      <div>
        <Nav role="tablist" as="ul" className="nav-tabs">
          {deploymentTargetTabs.map((tab) => (
            <NavItem key={tab} as="li" role="presentation">
              <NavLink
                as="button"
                type="button"
                active={activeTab === tab}
                onClick={() => handleTabChange(tab)}
              >
                <DeploymentTargetStatus status={tab} />
              </NavLink>
            </NavItem>
          ))}
        </Nav>

        {isTabDataLoading ? (
          <div className="d-flex justify-content-center p-4">
            <div className="spinner-border" role="status"></div>
          </div>
        ) : (
          <DeploymentTargetsTable
            deploymentTargetsRef={visibleTargets}
            hiddenColumns={hiddenColumns}
            isLoadingNext={currentTabFragment?.isLoadingNext ?? false}
            hasNext={currentTabFragment?.hasNext ?? false}
            loadNextDeploymentTargets={loadNextDeploymentTargets}
          />
        )}
      </div>
    </div>
  );
};

export default DeploymentTargetsTabs;
