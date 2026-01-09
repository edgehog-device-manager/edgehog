/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

import { useState, useMemo, useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";

import type { CampaignTargetStatus as CampaignTargetStatusType } from "@/api/__generated__/DeploymentTargetsTabs_SuccessfulFragment.graphql";
import type { DeploymentTargetsTabs_SuccessfulFragment$key } from "@/api/__generated__/DeploymentTargetsTabs_SuccessfulFragment.graphql";
import type { DeploymentTargetsTabs_FailedFragment$key } from "@/api/__generated__/DeploymentTargetsTabs_FailedFragment.graphql";
import type { DeploymentTargetsTabs_InProgressFragment$key } from "@/api/__generated__/DeploymentTargetsTabs_InProgressFragment.graphql";
import type { DeploymentTargetsTabs_IdleFragment$key } from "@/api/__generated__/DeploymentTargetsTabs_IdleFragment.graphql";

import DeploymentTargetsTable, {
  columnIds,
} from "@/components/DeploymentTargetsTable";
import type { ColumnId } from "@/components/DeploymentTargetsTable";
import CampaignTargetStatus from "@/components/CampaignTargetStatus";
import { RECORDS_TO_LOAD_NEXT } from "@/constants";

const CAMPAIGN_TARGETS_SUCCESSFUL_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_SuccessfulFragment on Campaign
  @refetchable(queryName: "DeploymentTargetsTabs_SuccessfulPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    successfulCampaignsTargets: campaignTargets(
      first: $first
      after: $after
      filter: { status: { eq: SUCCESSFUL } }
    ) @connection(key: "DeploymentTargetsTabs_successfulCampaignsTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_CampaignTargetsFragment
        }
      }
    }
  }
`;

const CAMPAIGN_TARGETS_FAILED_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_FailedFragment on Campaign
  @refetchable(queryName: "DeploymentTargetsTabs_FailedPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    failedCampaignTargets: campaignTargets(
      first: $first
      after: $after
      filter: { status: { eq: FAILED } }
    ) @connection(key: "DeploymentTargetsTabs_failedCampaignTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_CampaignTargetsFragment
        }
      }
    }
  }
`;

const CAMPAIGN_TARGETS_IN_PROGRESS_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_InProgressFragment on Campaign
  @refetchable(queryName: "DeploymentTargetsTabs_InProgressPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    inProgressCampaignTargets: campaignTargets(
      first: $first
      after: $after
      filter: { status: { eq: IN_PROGRESS } }
    ) @connection(key: "DeploymentTargetsTabs_inProgressCampaignTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_CampaignTargetsFragment
        }
      }
    }
  }
`;

const CAMPAIGN_TARGETS_IDLE_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_IdleFragment on Campaign
  @refetchable(queryName: "DeploymentTargetsTabs_IdlePaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    idleCampaignTargets: campaignTargets(
      first: $first
      after: $after
      filter: { status: { eq: IDLE } }
    ) @connection(key: "DeploymentTargetsTabs_idleCampaignTargets") {
      edges {
        node {
          status
          ...DeploymentTargetsTable_CampaignTargetsFragment
        }
      }
    }
  }
`;

const columnMap: Record<CampaignTargetStatusType, ColumnId[]> = {
  IDLE: ["deviceName"],
  IN_PROGRESS: ["deviceName", "state", "readiness", "latestAttempt"],
  SUCCESSFUL: ["deviceName", "completionTimestamp"],
  FAILED: ["deviceName", "lastErrorMessage", "completionTimestamp"],
};

const campaignTargetTabs: CampaignTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

const tabConfig = {
  SUCCESSFUL: {
    fragment: CAMPAIGN_TARGETS_SUCCESSFUL_FRAGMENT,
    dataField: "successfulCampaignsTargets",
  },
  FAILED: {
    fragment: CAMPAIGN_TARGETS_FAILED_FRAGMENT,
    dataField: "failedCampaignTargets",
  },
  IN_PROGRESS: {
    fragment: CAMPAIGN_TARGETS_IN_PROGRESS_FRAGMENT,
    dataField: "inProgressCampaignTargets",
  },
  IDLE: {
    fragment: CAMPAIGN_TARGETS_IDLE_FRAGMENT,
    dataField: "idleCampaignTargets",
  },
} as const;

const useActiveStatusPaginationFragment = (
  activeTab: CampaignTargetStatusType,
  campaignRef: any,
  isVisited: boolean,
) => {
  const config = tabConfig[activeTab];
  return usePaginationFragment(config.fragment, isVisited ? campaignRef : null);
};

type Props = {
  campaignRef: DeploymentTargetsTabs_SuccessfulFragment$key &
    DeploymentTargetsTabs_FailedFragment$key &
    DeploymentTargetsTabs_InProgressFragment$key &
    DeploymentTargetsTabs_IdleFragment$key;
};

const DeploymentTargetsTabs = ({ campaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<CampaignTargetStatusType>("SUCCESSFUL");

  const [visitedTabs, setVisitedTabs] = useState<Set<CampaignTargetStatusType>>(
    new Set(["SUCCESSFUL"]),
  );

  const handleTabChange = useCallback((newTab: CampaignTargetStatusType) => {
    setActiveTab(newTab);
    setVisitedTabs((prev) => new Set([...prev, newTab]));
  }, []);

  // Only runs one fragment hook (for the active tab)
  const currentTabFragment = useActiveStatusPaginationFragment(
    activeTab,
    campaignRef,
    visitedTabs.has(activeTab),
  );

  const isTabDataLoading =
    !visitedTabs.has(activeTab) ||
    (visitedTabs.has(activeTab) && !currentTabFragment?.data);

  const visibleTargets = useMemo(() => {
    const config = tabConfig[activeTab];
    const campaignTargetsField = currentTabFragment?.data?.[config.dataField];

    if (!campaignTargetsField?.edges) return [];
    return campaignTargetsField.edges
      .map((edge: any) => edge?.node)
      .filter(Boolean);
  }, [currentTabFragment?.data, activeTab]);

  const loadNextCampaignTargets = useCallback(() => {
    if (currentTabFragment?.hasNext && !currentTabFragment?.isLoadingNext) {
      currentTabFragment.loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [currentTabFragment]);

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[activeTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [activeTab]);

  if (!campaignRef) return null;

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
          {campaignTargetTabs.map((tab) => (
            <NavItem key={tab} as="li" role="presentation">
              <NavLink
                as="button"
                type="button"
                active={activeTab === tab}
                onClick={() => handleTabChange(tab)}
              >
                <CampaignTargetStatus status={tab} />
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
            campaignTargetsRef={visibleTargets}
            hiddenColumns={hiddenColumns}
            isLoadingNext={currentTabFragment?.isLoadingNext ?? false}
            hasNext={currentTabFragment?.hasNext ?? false}
            loadNextCampaignTargets={loadNextCampaignTargets}
          />
        )}
      </div>
    </div>
  );
};

export default DeploymentTargetsTabs;
