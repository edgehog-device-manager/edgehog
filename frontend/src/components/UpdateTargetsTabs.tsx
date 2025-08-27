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

import { useState, useMemo, useCallback, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { UpdateTargetsTabs_PaginationQuery } from "api/__generated__/UpdateTargetsTabs_PaginationQuery.graphql";
import type {
  UpdateTargetStatus as UpdateTargetStatusType,
  UpdateTargetsTabs_UpdateTargetsFragment$key,
} from "api/__generated__/UpdateTargetsTabs_UpdateTargetsFragment.graphql";

import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";
import UpdateTargetsTable, { columnIds } from "components/UpdateTargetsTable";
import type { ColumnId } from "components/UpdateTargetsTable";
import UpdateTargetStatus from "components/UpdateTargetStatus";

const UPDATE_TARGETS_TO_LOAD_FIRST = 10;
const UPDATE_TARGETS_TO_LOAD_NEXT = 10;

const UPDATE_TARGETS_TABS_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_UpdateTargetsFragment on UpdateCampaign
  @refetchable(queryName: "UpdateTargetsTabs_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: { type: "UpdateTargetFilterInput" }
  ) {
    updateTargets(first: $first, after: $after, filter: $filter)
      @connection(key: "UpdateTargetsTabs_updateTargets") {
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

type Props = {
  updateCampaignRef: UpdateTargetsTabs_UpdateTargetsFragment$key;
};

const UpdateTargetsTabs = ({ updateCampaignRef }: Props) => {
  const [activeTab, setActiveTab] =
    useState<UpdateTargetStatusType>("SUCCESSFUL");

  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      UpdateTargetsTabs_PaginationQuery,
      UpdateTargetsTabs_UpdateTargetsFragment$key
    >(UPDATE_TARGETS_TABS_FRAGMENT, updateCampaignRef);

  const loadNextUpdateTargets = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(UPDATE_TARGETS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const updateTargets = useMemo(() => {
    return data.updateTargets?.edges?.map((edge) => edge?.node) ?? [];
  }, [data]);

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[activeTab];
    return columnIds.filter((c) => !visible.includes(c));
  }, [activeTab]);

  useEffect(() => {
    const timeout = setTimeout(() => {
      refetch(
        {
          first: UPDATE_TARGETS_TO_LOAD_FIRST,
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

  if (!data.updateTargets) return null;

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
                onClick={() => setActiveTab(tab)}
              >
                <UpdateTargetStatus status={tab} />
              </NavLink>
            </NavItem>
          ))}
        </Nav>
        <UpdateTargetsTable
          updateTargetsRef={updateTargets}
          hiddenColumns={hiddenColumns}
          isLoadingNext={isLoadingNext}
          hasNext={hasNext}
          loadNextUpdateTargets={loadNextUpdateTargets}
        />
      </div>
    </div>
  );
};

export default UpdateTargetsTabs;
