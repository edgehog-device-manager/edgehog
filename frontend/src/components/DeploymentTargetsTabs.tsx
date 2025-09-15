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

import { useState, useMemo, useCallback, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";
import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";

import type { DeploymentTargetsTabs_PaginationQuery } from "api/__generated__/DeploymentTargetsTabs_PaginationQuery.graphql";
import type {
  DeploymentTargetStatus as DeploymentTargetStatusType,
  DeploymentTargetsTabs_DeploymentTargetsFragment$key,
} from "api/__generated__/DeploymentTargetsTabs_DeploymentTargetsFragment.graphql";

import DeploymentTargetsTable, {
  columnIds,
} from "components/DeploymentTargetsTable";
import type { ColumnId } from "components/DeploymentTargetsTable";
import DeploymentTargetStatus from "components/DeploymentTargetStatus";

const DEPLOYMENT_TARGETS_TO_LOAD_FIRST = 40;
const DEPLOYMENT_TARGETS_TO_LOAD_NEXT = 10;

const DEPLOYMENT_TARGETS_TABS_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_DeploymentTargetsFragment on DeploymentCampaign
  @refetchable(queryName: "DeploymentTargetsTabs_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: { type: "DeploymentTargetFilterInput" }
  ) {
    deploymentTargets(first: $first, after: $after, filter: $filter)
      @connection(key: "DeploymentTargetsTabs_deploymentTargets") {
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
  IN_PROGRESS: ["deviceName", "state", "resourcesState", "latestAttempt"],
  SUCCESSFUL: ["deviceName", "completionTimestamp"],
  FAILED: ["deviceName", "lastErrorMessage", "completionTimestamp"],
};

const deploymentTargetTabs: DeploymentTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

type Props = {
  deploymentCampaignRef: DeploymentTargetsTabs_DeploymentTargetsFragment$key;
};

const DeploymentTargetsTabs = ({ deploymentCampaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<DeploymentTargetStatusType>("SUCCESSFUL");

  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      DeploymentTargetsTabs_PaginationQuery,
      DeploymentTargetsTabs_DeploymentTargetsFragment$key
    >(DEPLOYMENT_TARGETS_TABS_FRAGMENT, deploymentCampaignRef);

  const loadNextDeploymentTargets = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(DEPLOYMENT_TARGETS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deploymentTargets = useMemo(() => {
    return data.deploymentTargets?.edges?.map((edge) => edge?.node) ?? [];
  }, [data]);

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[activeTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [activeTab]);

  useEffect(() => {
    const timeout = setTimeout(() => {
      refetch(
        {
          first: DEPLOYMENT_TARGETS_TO_LOAD_FIRST,
          filter: {
            status: {
              eq: activeTab,
            },
          },
        },
        { fetchPolicy: "network-only" },
      );
    }, 500);

    return () => clearTimeout(timeout);
  }, [activeTab, refetch]);

  if (!data.deploymentTargets) return null;

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
                onClick={() => setActiveTab(tab)}
              >
                <DeploymentTargetStatus status={tab} />
              </NavLink>
            </NavItem>
          ))}
        </Nav>
        <DeploymentTargetsTable
          deploymentTargetsRef={deploymentTargets}
          hiddenColumns={hiddenColumns}
          isLoadingNext={isLoadingNext}
          hasNext={hasNext}
          loadNextDeploymentTargets={loadNextDeploymentTargets}
        />
      </div>
    </div>
  );
};

export default DeploymentTargetsTabs;
