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

import { defineMessages, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  UpdateTargetStatus,
  UpdateTargetsTable_UpdateTargetsFragment$data,
  UpdateTargetsTable_UpdateTargetsFragment$key,
} from "api/__generated__/UpdateTargetsTable_UpdateTargetsFragment.graphql";

import Icon from "components/Icon";
import Table from "components/Table";
import type { Column } from "components/Table";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const UPDATE_TARGETS_TABLE_FRAGMENT = graphql`
  fragment UpdateTargetsTable_UpdateTargetsFragment on UpdateCampaign {
    updateTargets {
      device {
        id
        name
      }
      status
    }
  }
`;

const statusColors: Record<UpdateTargetStatus, string> = {
  IDLE: "text-muted",
  IN_PROGRESS: "text-warning",
  SUCCESSFUL: "text-success",
  FAILED: "text-danger",
};

const statusMessages = defineMessages<UpdateTargetStatus>({
  IDLE: {
    id: "components.UpdateTargetsTable.updateTargetStatus.Idle",
    defaultMessage: "Idle",
  },
  IN_PROGRESS: {
    id: "components.UpdateTargetsTable.updateTargetStatus.InProgress",
    defaultMessage: "In progress",
  },
  SUCCESSFUL: {
    id: "components.UpdateTargetsTable.updateTargetStatus.Successful",
    defaultMessage: "Successful",
  },
  FAILED: {
    id: "components.UpdateTargetsTable.updateTargetStatus.Failed",
    defaultMessage: "Failed",
  },
});

const TargetStatus = ({ status }: { status: UpdateTargetStatus }) => (
  <div className="d-flex align-items-center">
    <Icon icon="circle" className={`me-2 ${statusColors[status]}`} />
    <span>
      <FormattedMessage id={statusMessages[status].id} />
    </span>
  </div>
);

type TableRecord =
  UpdateTargetsTable_UpdateTargetsFragment$data["updateTargets"][number];

const columns: Column<TableRecord>[] = [
  {
    accessor: "device",
    Header: (
      <FormattedMessage
        id="components.UpdateTargetsTable.deviceTitle"
        defaultMessage="Device"
        description="Title for the Device column of the Update Targets table"
      />
    ),
    Cell: ({ value }) => (
      <Link route={Route.devicesEdit} params={{ deviceId: value.id }}>
        {value.name}
      </Link>
    ),
  },
  {
    accessor: "status",
    Header: (
      <FormattedMessage
        id="components.UpdateTargetsTable.statusTitle"
        defaultMessage="Status"
        description="Title for the Status column of the Update Targets table"
      />
    ),
    Cell: ({ value }) => <TargetStatus status={value} />,
  },
];

type Props = {
  className?: string;
  updateCampaignRef: UpdateTargetsTable_UpdateTargetsFragment$key;
};

const UpdateTargetsTable = ({ className, updateCampaignRef }: Props) => {
  const { updateTargets } = useFragment(
    UPDATE_TARGETS_TABLE_FRAGMENT,
    updateCampaignRef
  );

  return (
    <Table
      className={className}
      columns={columns}
      data={updateTargets}
      hideSearch
    />
  );
};

export default UpdateTargetsTable;
