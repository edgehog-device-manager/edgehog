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

import { useState, useMemo } from "react";
import { defineMessages, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  UpdateTargetStatus,
  UpdateTargetsTabs_UpdateTargetsFragment$key,
} from "api/__generated__/UpdateTargetsTabs_UpdateTargetsFragment.graphql";

import Nav from "react-bootstrap/Nav";
import NavItem from "react-bootstrap/NavItem";
import NavLink from "react-bootstrap/NavLink";
import Icon from "components/Icon";
import UpdateTargetsTable, { columnIds } from "components/UpdateTargetsTable";
import type { ColumnId } from "components/UpdateTargetsTable";

const UPDATE_TARGETS_TABS_FRAGMENT = graphql`
  fragment UpdateTargetsTabs_UpdateTargetsFragment on UpdateCampaign {
    updateTargets {
      status
      ...UpdateTargetsTable_UpdateTargetsFragment
    }
  }
`;

const statusMessages = defineMessages<UpdateTargetStatus>({
  IDLE: {
    id: "components.UpdateTargetsTabs.updateTargetStatus.Idle",
    defaultMessage: "Idle",
  },
  IN_PROGRESS: {
    id: "components.UpdateTargetsTabs.updateTargetStatus.InProgress",
    defaultMessage: "In progress",
  },
  SUCCESSFUL: {
    id: "components.UpdateTargetsTabs.updateTargetStatus.Successful",
    defaultMessage: "Successful",
  },
  FAILED: {
    id: "components.UpdateTargetsTabs.updateTargetStatus.Failed",
    defaultMessage: "Failed",
  },
});

const getVisibleColumns = (status: UpdateTargetStatus): ColumnId[] => {
  switch (status) {
    case "IDLE":
      return ["deviceName"];

    case "IN_PROGRESS":
      return [
        "deviceName",
        "otaOperationStatus",
        "otaOperationStatusProgress",
        "latestAttempt",
      ];

    case "SUCCESSFUL":
      return ["deviceName", "completionTimestamp"];

    case "FAILED":
      return ["deviceName", "otaOperationStatusCode", "completionTimestamp"];
  }
};

const getHiddenColumns = (status: UpdateTargetStatus): ColumnId[] => {
  const visibleColumns = getVisibleColumns(status);
  return columnIds.filter((column) => !visibleColumns.includes(column));
};

const updateTargetTabs: UpdateTargetStatus[] = [
  "SUCCESSFUL",
  "FAILED",
  "IN_PROGRESS",
  "IDLE",
];

type Props = {
  updateCampaignRef: UpdateTargetsTabs_UpdateTargetsFragment$key;
};

const UpdateTargetsTabs = ({ updateCampaignRef }: Props) => {
  const [activeTab, setActiveTab] = useState<UpdateTargetStatus>("SUCCESSFUL");
  const { updateTargets } = useFragment(
    UPDATE_TARGETS_TABS_FRAGMENT,
    updateCampaignRef
  );
  const visibleTargets = useMemo(
    () => updateTargets.filter(({ status }) => status === activeTab),
    [activeTab, updateTargets]
  );
  const hiddenColumns = useMemo(() => getHiddenColumns(activeTab), [activeTab]);

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
                <FormattedMessage id={statusMessages[tab].id} />
              </NavLink>
            </NavItem>
          ))}
        </Nav>
        <UpdateTargetsTable
          updateTargetsRef={visibleTargets}
          hiddenColumns={hiddenColumns}
        />
      </div>
    </div>
  );
};

export default UpdateTargetsTabs;
