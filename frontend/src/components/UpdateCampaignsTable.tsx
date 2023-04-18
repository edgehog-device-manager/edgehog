/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { Link, Route } from "Navigation";

import type {
  UpdateCampaignsTable_UpdateCampaignFragment$data,
  UpdateCampaignsTable_UpdateCampaignFragment$key,
} from "api/__generated__/UpdateCampaignsTable_UpdateCampaignFragment.graphql";

import Table from "components/Table";
import type { Column } from "components/Table";
import UpdateCampaignOutcome from "components/UpdateCampaignOutcome";
import UpdateCampaignStatus from "components/UpdateCampaignStatus";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const UPDATE_CAMPAIGNS_TABLE_FRAGMENT = graphql`
  fragment UpdateCampaignsTable_UpdateCampaignFragment on UpdateCampaign
  @relay(plural: true) {
    id
    name
    status
    ...UpdateCampaignStatus_UpdateCampaignStatusFragment
    outcome
    ...UpdateCampaignOutcome_UpdateCampaignOutcomeFragment
    baseImage {
      version
      releaseDisplayName
      baseImageCollection {
        name
      }
    }
    updateChannel {
      name
    }
  }
`;

type TableRecord = UpdateCampaignsTable_UpdateCampaignFragment$data[number];

const columns: Column<TableRecord>[] = [
  {
    accessor: "name",
    Header: (
      <FormattedMessage
        id="components.UpdateCampaignsTable.nameTitle"
        defaultMessage="Update Campaign Name"
        description="Title for the Name column of the Update Campaigns table"
      />
    ),
    Cell: ({ row, value }) => (
      <Link
        route={Route.updateCampaignsEdit}
        params={{ updateCampaignId: row.original.id }}
      >
        {value}
      </Link>
    ),
  },
  {
    accessor: "status",
    Header: (
      <FormattedMessage
        id="components.UpdateCampaignsTable.statusTitle"
        defaultMessage="Status"
      />
    ),
    Cell: ({ row }) => (
      <UpdateCampaignStatus updateCampaignRef={row.original} />
    ),
  },
  {
    accessor: "outcome",
    Header: (
      <FormattedMessage
        id="components.UpdateCampaignsTable.outcomeTitle"
        defaultMessage="Outcome"
      />
    ),
    Cell: ({ row }) => (
      <UpdateCampaignOutcome updateCampaignRef={row.original} />
    ),
  },
  {
    id: "updateChannel",
    accessor: (row) => row.updateChannel.name,
    Header: (
      <FormattedMessage
        id="components.UpdateCampaignsTable.updateChannelNameTitle"
        defaultMessage="Update Channel"
        description="Title for the Update Channel column of the Update Campaigns table"
      />
    ),
  },
  {
    id: "baseImageCollection",
    accessor: (row) => row.baseImage.baseImageCollection.name,
    Header: (
      <FormattedMessage
        id="components.UpdateCampaignsTable.baseImageCollectionNameTitle"
        defaultMessage="Base Image Collection"
        description="Title for the Base Image Collection column of the Update Campaigns table"
      />
    ),
  },
  {
    id: "baseImage",
    accessor: ({ baseImage }) => {
      const { releaseDisplayName, version } = baseImage;
      if (releaseDisplayName === null) {
        return version;
      }
      return `${version} (${releaseDisplayName})`;
    },
    Header: (
      <FormattedMessage
        id="components.UpdateCampaignsTable.baseImageTitle"
        defaultMessage="Base Image"
        description="Title for the Base Image column of the Update Campaigns table"
      />
    ),
  },
];

interface Props {
  className?: string;
  updateCampaignsRef: UpdateCampaignsTable_UpdateCampaignFragment$key;
}

const UpdateCampaignsTable = ({ className, updateCampaignsRef }: Props) => {
  const updateCampaigns = useFragment(
    UPDATE_CAMPAIGNS_TABLE_FRAGMENT,
    updateCampaignsRef
  );

  return (
    <Table className={className} columns={columns} data={updateCampaigns} />
  );
};

export default UpdateCampaignsTable;
