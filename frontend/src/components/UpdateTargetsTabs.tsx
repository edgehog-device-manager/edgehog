/*
 * This file is part of Edgehog.
 *
 * Copyright 2023 - 2026 SECO Mind Srl
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
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import { UpdateCampaign_getCampaign_Query$data } from "@/api/__generated__/UpdateCampaign_getCampaign_Query.graphql";
import { UpdateTargets_PaginationQuery } from "@/api/__generated__/UpdateTargets_PaginationQuery.graphql";
import { UpdateTargetsTabs_UpdateTargetsFragment$key } from "@/api/__generated__/UpdateTargetsTabs_UpdateTargetsFragment.graphql";

import CampaignTargetStatus, {
  CampaignTargetStatusType,
} from "@/components/CampaignTargetStatus";
import type { ColumnId } from "@/components/UpdateTargetsTable";
import UpdateTargetsTable, { columnIds } from "@/components/UpdateTargetsTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";
import Spinner from "./Spinner";

/* eslint-disable relay/unused-fields */
const UPDATE_TARGETS_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_UpdateTargetsFragment on Campaign
  @refetchable(queryName: "UpdateTargets_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: {
      type: "CampaignTargetFilterInput"
      defaultValue: { status: { eq: SUCCESSFUL } }
    }
  ) {
    campaignTargets(first: $first, after: $after, filter: $filter)
      @connection(key: "UpdateTargetsTabs_campaignTargets") {
      edges {
        node {
          __typename
        }
      }
      ...UpdateTargetsTable_CampaignTargetEdgeFragment
    }
  }
`;

const columnMap: Record<CampaignTargetStatusType, ColumnId[]> = {
  IDLE: ["deviceName"],
  IN_PROGRESS: [
    "deviceName",
    "otaOperationStatus",
    "otaOperationStatusProgress",
    "retryCount",
    "latestAttempt",
  ],
  SUCCESSFUL: ["deviceName", "completionTimestamp"],
  FAILED: ["deviceName", "otaOperationStatusCode", "completionTimestamp"],
};

const campaignTargetTabs: CampaignTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

type Props = {
  campaignRef: NonNullable<UpdateCampaign_getCampaign_Query$data["campaign"]>;
};

const UpdateTargetsTabs = ({ campaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<CampaignTargetStatusType>("SUCCESSFUL");
  const [committedTab, setCommittedTab] = useState(activeTab);
  const [isTabDataLoading, setIsTabDataLoading] = useState(false);

  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      UpdateTargets_PaginationQuery,
      UpdateTargetsTabs_UpdateTargetsFragment$key
    >(UPDATE_TARGETS_FRAGMENT, campaignRef);

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

  const loadNextUpdateTargets = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const updateTargetsRef = data?.campaignTargets;

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[committedTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [committedTab]);

  if (!updateTargetsRef) {
    return null;
  }
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
            <UpdateTargetsTable
              key={committedTab}
              campaignTargetsRef={updateTargetsRef}
              hiddenColumns={hiddenColumns}
              loading={isLoadingNext}
              onLoadMore={hasNext ? loadNextUpdateTargets : undefined}
            />
          )}
        </div>
      </div>
    </div>
  );
};

export default UpdateTargetsTabs;
