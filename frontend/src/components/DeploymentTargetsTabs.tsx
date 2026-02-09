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

import { useCallback, useEffect, useMemo, useState } from "react";
import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import { DeploymentCampaign_getCampaign_Query$data } from "@/api/__generated__/DeploymentCampaign_getCampaign_Query.graphql";
import { DeploymentTargets_PaginationQuery } from "@/api/__generated__/DeploymentTargets_PaginationQuery.graphql";
import { DeploymentTargetsTabs_DeploymentTargetsFragment$key } from "@/api/__generated__/DeploymentTargetsTabs_DeploymentTargetsFragment.graphql";

import CampaignTargetStatus, {
  CampaignTargetStatusType,
} from "@/components/CampaignTargetStatus";
import type { ColumnId } from "@/components/DeploymentTargetsTable";
import DeploymentTargetsTable, {
  columnIds,
} from "@/components/DeploymentTargetsTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import Spinner from "./Spinner";

/* eslint-disable relay/unused-fields */
const DEPLOYMENT_TARGETS_FRAGMENT = graphql`
  fragment DeploymentTargetsTabs_DeploymentTargetsFragment on Campaign
  @refetchable(queryName: "DeploymentTargets_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: {
      type: "CampaignTargetFilterInput"
      defaultValue: { status: { eq: SUCCESSFUL } }
    }
  ) {
    campaignTargets(first: $first, after: $after, filter: $filter)
      @connection(key: "DeploymentTargetsTabs_campaignTargets") {
      edges {
        node {
          __typename
        }
      }
      ...DeploymentTargetsTable_CampaignTargetEdgeFragment
    }
  }
`;

const columnMap: Record<CampaignTargetStatusType, ColumnId[]> = {
  IDLE: ["deviceName"],
  IN_PROGRESS: [
    "deviceName",
    "state",
    "readiness",
    "retryCount",
    "latestAttempt",
  ],
  SUCCESSFUL: ["deviceName", "completionTimestamp"],
  FAILED: ["deviceName", "lastErrorMessage", "completionTimestamp"],
};

const campaignTargetTabs: CampaignTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

type Props = {
  campaignRef: NonNullable<
    DeploymentCampaign_getCampaign_Query$data["campaign"]
  >;
};

const DeploymentTargetsTabs = ({ campaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<CampaignTargetStatusType>("SUCCESSFUL");
  const [committedTab, setCommittedTab] = useState(activeTab);
  const [isTabDataLoading, setIsTabDataLoading] = useState(false);

  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      DeploymentTargets_PaginationQuery,
      DeploymentTargetsTabs_DeploymentTargetsFragment$key
    >(DEPLOYMENT_TARGETS_FRAGMENT, campaignRef);

  useEffect(() => {
    setIsTabDataLoading(true);

    refetch(
      {
        first: RECORDS_TO_LOAD_FIRST,
        filter: { status: { eq: activeTab } },
      },
      {
        fetchPolicy: "network-only",
        onComplete: () => {
          setCommittedTab(activeTab);
          setIsTabDataLoading(false);
        },
      },
    );
  }, [activeTab, refetch]);

  const loadNextDeploymentTargets = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const deploymentTargetsRef = data?.campaignTargets;

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[committedTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [committedTab]);

  if (!deploymentTargetsRef) {
    return null;
  }

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
                onClick={() => setActiveTab(tab)}
              >
                <CampaignTargetStatus status={tab} />
              </NavLink>
            </NavItem>
          ))}
        </Nav>
        <div className="deployment-targets-container">
          {isTabDataLoading ? (
            <Spinner />
          ) : (
            <DeploymentTargetsTable
              key={committedTab}
              campaignTargetsRef={deploymentTargetsRef}
              hiddenColumns={hiddenColumns}
              loading={isLoadingNext}
              onLoadMore={hasNext ? loadNextDeploymentTargets : undefined}
            />
          )}
        </div>
      </div>
    </div>
  );
};

export default DeploymentTargetsTabs;
