/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { useEffect, useMemo, useState } from "react";
import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";
import { FormattedMessage } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay/hooks";

import type { FileDownloadCampaign_getCampaign_Query$data } from "@/api/__generated__/FileDownloadCampaign_getCampaign_Query.graphql";
import type { FileDownloadTargetsTabs_FileDownloadTargetsFragment$key } from "@/api/__generated__/FileDownloadTargetsTabs_FileDownloadTargetsFragment.graphql";
import type { FileDownloadTargets_PaginationQuery } from "@/api/__generated__/FileDownloadTargets_PaginationQuery.graphql";

import CampaignTargetStatus, {
  CampaignTargetStatusType,
} from "@/components/CampaignTargetStatus";
import type { ColumnId } from "@/components/FileDownloadTargetsTable";
import FileDownloadTargetsTable, {
  columnIds,
} from "@/components/FileDownloadTargetsTable";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import Spinner from "./Spinner";

const FILE_DOWNLOAD_TARGETS_FRAGMENT = graphql`
  fragment FileDownloadTargetsTabs_FileDownloadTargetsFragment on Campaign
  @refetchable(queryName: "FileDownloadTargets_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: {
      type: "CampaignTargetFilterInput"
      defaultValue: { status: { eq: SUCCESSFUL } }
    }
  ) {
    campaignTargets(first: $first, after: $after, filter: $filter)
      @connection(key: "FileDownloadTargetsTabs_campaignTargets") {
      edges {
        node {
          __typename
          fileDownloadRequest {
            destinationType
          }
        }
      }
      ...FileDownloadTargetsTable_CampaignTargetEdgeFragment
    }
  }
`;

const columnMap: Record<CampaignTargetStatusType, ColumnId[]> = {
  IDLE: ["deviceName"],
  IN_PROGRESS: [
    "deviceName",
    "requestStatus",
    "requestProgress",
    "retryCount",
    "latestAttempt",
  ],
  SUCCESSFUL: ["deviceName", "pathOnDevice", "completionTimestamp"],
  FAILED: ["deviceName", "failureReason", "completionTimestamp"],
};

const campaignTargetTabs: CampaignTargetStatusType[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

type FileDownloadTargetsTabsProps = {
  campaignRef: NonNullable<
    FileDownloadCampaign_getCampaign_Query$data["campaign"]
  >;
};

const FileDownloadTargetsTabs = ({
  campaignRef,
}: FileDownloadTargetsTabsProps) => {
  const [activeTab, setActiveTab] =
    useState<CampaignTargetStatusType>("SUCCESSFUL");
  const [committedTab, setCommittedTab] = useState(activeTab);

  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      FileDownloadTargets_PaginationQuery,
      FileDownloadTargetsTabs_FileDownloadTargetsFragment$key
    >(FILE_DOWNLOAD_TARGETS_FRAGMENT, campaignRef);

  const isTabDataLoading = activeTab !== committedTab;

  useEffect(() => {
    if (activeTab === committedTab) {
      return;
    }

    refetch(
      {
        first: RECORDS_TO_LOAD_FIRST,
        filter: { status: { eq: activeTab } },
      },
      {
        fetchPolicy: "network-only",
        onComplete: () => {
          setCommittedTab(activeTab);
        },
      },
    );
  }, [activeTab, committedTab, refetch]);

  const { onLoadMore } = useRelayConnectionPagination({
    hasNext,
    isLoadingNext,
    loadNext,
  });

  const targetsRef = data?.campaignTargets;

  const hiddenColumns = useMemo(() => {
    const visible = columnMap[committedTab];
    const hasStorageDestination = Boolean(
      data?.campaignTargets?.edges?.some(
        (edge) =>
          edge?.node?.fileDownloadRequest?.destinationType === "STORAGE",
      ),
    );

    return columnIds.filter((columnId) => {
      if (columnId === "pathOnDevice" && !hasStorageDestination) {
        return true;
      }

      return !visible.includes(columnId);
    });
  }, [committedTab, data?.campaignTargets?.edges]);

  if (!targetsRef) {
    return null;
  }

  return (
    <div>
      <h3>
        <FormattedMessage
          id="components.FileDownloadTargetsTabs.targetsLabel"
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

        <div>
          {isTabDataLoading ? (
            <Spinner />
          ) : (
            <FileDownloadTargetsTable
              key={committedTab}
              campaignTargetsRef={targetsRef}
              hiddenColumns={hiddenColumns}
              loading={isLoadingNext}
              onLoadMore={onLoadMore}
            />
          )}
        </div>
      </div>
    </div>
  );
};

export default FileDownloadTargetsTabs;
