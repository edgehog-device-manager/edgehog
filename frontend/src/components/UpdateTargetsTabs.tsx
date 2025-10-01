/*
  This file is part of Edgehog.

  Copyright 2023-2025 SECO Mind Srl

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

import type { UpdateTargetStatus as UpdateTargetStatusType } from "api/__generated__/UpdateTargetsTabs_SuccessfulFragment.graphql";
import type { UpdateTargetsTabs_SuccessfulFragment$key } from "api/__generated__/UpdateTargetsTabs_SuccessfulFragment.graphql";
import type { UpdateTargetsTabs_FailedFragment$key } from "api/__generated__/UpdateTargetsTabs_FailedFragment.graphql";
import type { UpdateTargetsTabs_InProgressFragment$key } from "api/__generated__/UpdateTargetsTabs_InProgressFragment.graphql";
import type { UpdateTargetsTabs_IdleFragment$key } from "api/__generated__/UpdateTargetsTabs_IdleFragment.graphql";

import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";
import UpdateTargetsTable, { columnIds } from "components/UpdateTargetsTable";
import type { ColumnId } from "components/UpdateTargetsTable";
import UpdateTargetStatus from "components/UpdateTargetStatus";

const UPDATE_TARGETS_TO_LOAD_NEXT = 10;

const UPDATE_TARGETS_SUCCESSFUL_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_SuccessfulFragment on UpdateCampaign
  @refetchable(queryName: "UpdateTargetsTabs_SuccessfulPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    successfulUpdateTargets: updateTargets(
      first: $first
      after: $after
      filter: { status: { eq: SUCCESSFUL } }
    ) @connection(key: "UpdateTargetsTabs_successfulUpdateTargets") {
      edges {
        node {
          status
          ...UpdateTargetsTable_UpdateTargetsFragment
        }
      }
    }
  }
`;

const UPDATE_TARGETS_FAILED_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_FailedFragment on UpdateCampaign
  @refetchable(queryName: "UpdateTargetsTabs_FailedPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    failedUpdateTargets: updateTargets(
      first: $first
      after: $after
      filter: { status: { eq: FAILED } }
    ) @connection(key: "UpdateTargetsTabs_failedUpdateTargets") {
      edges {
        node {
          status
          ...UpdateTargetsTable_UpdateTargetsFragment
        }
      }
    }
  }
`;

const UPDATE_TARGETS_IN_PROGRESS_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_InProgressFragment on UpdateCampaign
  @refetchable(queryName: "UpdateTargetsTabs_InProgressPaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    inProgressUpdateTargets: updateTargets(
      first: $first
      after: $after
      filter: { status: { eq: IN_PROGRESS } }
    ) @connection(key: "UpdateTargetsTabs_inProgressUpdateTargets") {
      edges {
        node {
          status
          ...UpdateTargetsTable_UpdateTargetsFragment
        }
      }
    }
  }
`;

const UPDATE_TARGETS_IDLE_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_IdleFragment on UpdateCampaign
  @refetchable(queryName: "UpdateTargetsTabs_IdlePaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    idleUpdateTargets: updateTargets(
      first: $first
      after: $after
      filter: { status: { eq: IDLE } }
    ) @connection(key: "UpdateTargetsTabs_idleUpdateTargets") {
      edges {
        node {
          status
          ...UpdateTargetsTable_UpdateTargetsFragment
        }
      }
    }
  }
`;

const columnMap: Record<UpdateTargetStatusType, ColumnId[]> = {
  IDLE: ["deviceName"],
  IN_PROGRESS: [
    "deviceName",
    "otaOperationStatus",
    "otaOperationStatusProgress",
    "latestAttempt",
  ],
  SUCCESSFUL: ["deviceName", "completionTimestamp"],
  FAILED: ["deviceName", "otaOperationStatusCode", "completionTimestamp"],
};

const updateTargetTabs: UpdateTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

const tabConfig = {
  SUCCESSFUL: {
    fragment: UPDATE_TARGETS_SUCCESSFUL_FRAGMENT,
    dataField: "successfulUpdateTargets",
  },
  FAILED: {
    fragment: UPDATE_TARGETS_FAILED_FRAGMENT,
    dataField: "failedUpdateTargets",
  },
  IN_PROGRESS: {
    fragment: UPDATE_TARGETS_IN_PROGRESS_FRAGMENT,
    dataField: "inProgressUpdateTargets",
  },
  IDLE: {
    fragment: UPDATE_TARGETS_IDLE_FRAGMENT,
    dataField: "idleUpdateTargets",
  },
} as const;

const useActiveStatusPaginationFragment = (
  activeTab: UpdateTargetStatusType,
  updateCampaignRef: any,
  isVisited: boolean,
) => {
  const config = tabConfig[activeTab];
  return usePaginationFragment(
    config.fragment,
    isVisited ? updateCampaignRef : null,
  );
};

type Props = {
  updateCampaignRef: UpdateTargetsTabs_SuccessfulFragment$key &
    UpdateTargetsTabs_FailedFragment$key &
    UpdateTargetsTabs_InProgressFragment$key &
    UpdateTargetsTabs_IdleFragment$key;
};

const UpdateTargetsTabs = ({ updateCampaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<UpdateTargetStatusType>("SUCCESSFUL");

  const [visitedTabs, setVisitedTabs] = useState<Set<UpdateTargetStatusType>>(
    new Set(["SUCCESSFUL"]),
  );

  const handleTabChange = useCallback((newTab: UpdateTargetStatusType) => {
    setActiveTab(newTab);
    setVisitedTabs((prev) => new Set([...prev, newTab]));
  }, []);

  // Only runs one fragment hook (for the active tab)
  const currentTabFragment = useActiveStatusPaginationFragment(
    activeTab,
    updateCampaignRef,
    visitedTabs.has(activeTab),
  );

  const isTabDataLoading =
    !visitedTabs.has(activeTab) ||
    (visitedTabs.has(activeTab) && !currentTabFragment?.data);

  const visibleTargets = useMemo(() => {
    const config = tabConfig[activeTab as keyof typeof tabConfig];
    const updateTargetsField = currentTabFragment?.data?.[config.dataField];

    if (!updateTargetsField?.edges) return [];
    return updateTargetsField.edges
      .map((edge: any) => edge?.node)
      .filter(Boolean);
  }, [currentTabFragment?.data, activeTab]);

  const loadNextUpdateTargets = useCallback(() => {
    if (currentTabFragment?.hasNext && !currentTabFragment?.isLoadingNext) {
      currentTabFragment.loadNext(UPDATE_TARGETS_TO_LOAD_NEXT);
    }
  }, [currentTabFragment]);

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[activeTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [activeTab]);

  if (!updateCampaignRef) return null;

  return (
    <div>
      <h3>
        <FormattedMessage
          id="components.UpdateTargetsTabs.updateTargetsLabel"
          defaultMessage="Devices"
        />
      </h3>
      <div>
        <Nav role="tablist" as="ul" className="nav-tabs">
          {updateTargetTabs.map((tab) => (
            <NavItem key={tab} as="li" role="presentation">
              <NavLink
                as="button"
                type="button"
                active={activeTab === tab}
                onClick={() => handleTabChange(tab)}
              >
                <UpdateTargetStatus status={tab} />
              </NavLink>
            </NavItem>
          ))}
        </Nav>

        {isTabDataLoading ? (
          <div className="d-flex justify-content-center p-4">
            <div className="spinner-border" role="status"></div>
          </div>
        ) : (
          <UpdateTargetsTable
            updateTargetsRef={visibleTargets}
            hiddenColumns={hiddenColumns}
            isLoadingNext={currentTabFragment?.isLoadingNext ?? false}
            hasNext={currentTabFragment?.hasNext ?? false}
            loadNextUpdateTargets={loadNextUpdateTargets}
          />
        )}
      </div>
    </div>
  );
};

export default UpdateTargetsTabs;
