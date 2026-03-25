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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  FileDownloadCampaignsTable_CampaignEdgeFragment$data,
  FileDownloadCampaignsTable_CampaignEdgeFragment$key,
} from "@/api/__generated__/FileDownloadCampaignsTable_CampaignEdgeFragment.graphql";

import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGNS_TABLE_FRAGMENT = graphql`
  fragment FileDownloadCampaignsTable_CampaignEdgeFragment on CampaignConnection {
    edges {
      node {
        id
        name
        status
        ...CampaignStatus_CampaignStatusFragment
        outcome
        ...CampaignOutcome_CampaignOutcomeFragment
        channel {
          name
        }
        campaignMechanism {
          __typename
          ... on FileDownload {
            destinationType
            file {
              id
              name
              repository {
                id
                name
              }
            }
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<FileDownloadCampaignsTable_CampaignEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.nameTitle"
        defaultMessage="File Download Campaign Name"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.fileDownloadCampaignsEdit}
        params={{ fileDownloadCampaignId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("campaignMechanism.destinationType", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.destinationTypeTitle"
        defaultMessage="Destination Type"
      />
    ),
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    cell: ({ row }) => <CampaignStatus campaignRef={row.original} />,
  }),
  columnHelper.accessor("outcome", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.outcomeTitle"
        defaultMessage="Outcome"
      />
    ),
    cell: ({ row }) => <CampaignOutcome campaignRef={row.original} />,
  }),
  columnHelper.accessor("channel.name", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.channelNameTitle"
        defaultMessage="Channel"
      />
    ),
  }),
  columnHelper.accessor("campaignMechanism.file.repository.name", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.repositoryNameTitle"
        defaultMessage="Repository"
      />
    ),
  }),
  columnHelper.accessor("campaignMechanism.file.name", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadCampaignsTable.fileNameTitle"
        defaultMessage="File"
      />
    ),
  }),
];

type FileDownloadCampaignsTableProps = {
  className?: string;
  fileDownloadCampaignsRef: FileDownloadCampaignsTable_CampaignEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const FileDownloadCampaignsTable = ({
  className,
  fileDownloadCampaignsRef,
  loading = false,
  onLoadMore,
}: FileDownloadCampaignsTableProps) => {
  const campaignsFragment = useFragment(
    CAMPAIGNS_TABLE_FRAGMENT,
    fileDownloadCampaignsRef || null,
  );

  const campaigns = useMemo<TableRecord[]>(() => {
    return (
      _.compact(campaignsFragment?.edges?.map((e) => e?.node)).filter(
        (campaign) => campaign.campaignMechanism.__typename === "FileDownload",
      ) ?? []
    );
  }, [campaignsFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={campaigns}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default FileDownloadCampaignsTable;
