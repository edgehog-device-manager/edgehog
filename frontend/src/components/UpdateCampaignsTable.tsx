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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import {
  UpdateCampaignsTable_CampaignEdgeFragment$data,
  UpdateCampaignsTable_CampaignEdgeFragment$key,
} from "@/api/__generated__/UpdateCampaignsTable_CampaignEdgeFragment.graphql";

import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGNS_TABLE_FRAGMENT = graphql`
  fragment UpdateCampaignsTable_CampaignEdgeFragment on CampaignConnection {
    edges {
      node {
        id
        name
        status
        ...CampaignStatus_CampaignStatusFragment
        outcome
        ...CampaignOutcome_CampaignOutcomeFragment
        campaignMechanism {
          ... on FirmwareUpgrade {
            baseImage {
              name
              baseImageCollection {
                name
              }
            }
          }
        }
        channel {
          name
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<UpdateCampaignsTable_CampaignEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.nameTitle"
        defaultMessage="Update Campaign Name"
        description="Title for the Name column of the Update Campaigns table"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.updateCampaignsEdit}
        params={{ updateCampaignId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    cell: ({ row }) => <CampaignStatus campaignRef={row.original} />,
  }),
  columnHelper.accessor("outcome", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.outcomeTitle"
        defaultMessage="Outcome"
      />
    ),
    cell: ({ row }) => <CampaignOutcome campaignRef={row.original} />,
  }),
  columnHelper.accessor("channel.name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.channelNameTitle"
        defaultMessage="Channel"
        description="Title for the Channel column of the Update Campaigns table"
      />
    ),
  }),
  columnHelper.accessor(
    "campaignMechanism.baseImage.baseImageCollection.name",
    {
      header: () => (
        <FormattedMessage
          id="components.UpdateCampaignsTable.baseImageCollectionNameTitle"
          defaultMessage="Base Image Collection"
          description="Title for the Base Image Collection column of the Update Campaigns table"
        />
      ),
    },
  ),
  columnHelper.accessor("campaignMechanism.baseImage.name", {
    header: () => (
      <FormattedMessage
        id="components.UpdateCampaignsTable.baseImageTitle"
        defaultMessage="Base Image"
        description="Title for the Base Image column of the Update Campaigns table"
      />
    ),
  }),
];

type UpdateCampaignsTableProps = {
  className?: string;
  updateCampaignsRef: UpdateCampaignsTable_CampaignEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const UpdateCampaignsTable = ({
  className,
  updateCampaignsRef,
  loading = false,
  onLoadMore,
}: UpdateCampaignsTableProps) => {
  const updateCampaignsFragment = useFragment(
    CAMPAIGNS_TABLE_FRAGMENT,
    updateCampaignsRef || null,
  );

  const updateCampaigns = useMemo<TableRecord[]>(() => {
    return _.compact(updateCampaignsFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [updateCampaignsFragment]);

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={updateCampaigns}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default UpdateCampaignsTable;
