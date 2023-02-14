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
import { graphql, useFragment } from "react-relay";

import type {
  UpdateChannelsTable_UpdateChannelFragment$data,
  UpdateChannelsTable_UpdateChannelFragment$key,
} from "api/__generated__/UpdateChannelsTable_UpdateChannelFragment.graphql";

import Table from "components/Table";
import type { Column } from "components/Table";
import Tag from "components/Tag";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment UpdateChannelsTable_UpdateChannelFragment on UpdateChannel
  @relay(plural: true) {
    name
    handle
    targetGroups {
      name
    }
  }
`;

type TableRecord = UpdateChannelsTable_UpdateChannelFragment$data[0];

const columns: Column<TableRecord>[] = [
  {
    accessor: "name",
    Header: (
      <FormattedMessage
        id="components.UpdateChannelsTable.nameTitle"
        defaultMessage="Update Channel Name"
        description="Title for the Name column of the update channels table"
      />
    ),
  },
  {
    accessor: "handle",
    Header: (
      <FormattedMessage
        id="components.UpdateChannelsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the update channels table"
      />
    ),
  },
  {
    accessor: "targetGroups",
    disableSortBy: true,
    Header: (
      <FormattedMessage
        id="components.UpdateChannelsTable.targetGroupsTitle"
        defaultMessage="Target Groups"
        description="Title for the Target Groups column of the update channels table"
      />
    ),
    Cell: ({ value }) => (
      <>
        {value.map((group) => (
          <Tag key={group.name} className="me-2">
            {group.name}
          </Tag>
        ))}
      </>
    ),
  },
];

type Props = {
  className?: string;
  updateChannelsRef: UpdateChannelsTable_UpdateChannelFragment$key;
};

const UpdateChannelsTable = ({ className, updateChannelsRef }: Props) => {
  const updateChannels = useFragment(
    DEVICE_GROUPS_TABLE_FRAGMENT,
    updateChannelsRef
  );

  return (
    <Table className={className} columns={columns} data={updateChannels} />
  );
};

export default UpdateChannelsTable;
