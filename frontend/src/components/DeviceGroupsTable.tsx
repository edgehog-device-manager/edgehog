/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

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

import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay";

import type {
  DeviceGroupsTable_DeviceGroupFragment$data,
  DeviceGroupsTable_DeviceGroupFragment$key,
} from "api/__generated__/DeviceGroupsTable_DeviceGroupFragment.graphql";

import Table from "components/Table";
import type { Column } from "components/Table";

const DEVICE_GROUPS_TABLE_FRAGMENT = graphql`
  fragment DeviceGroupsTable_DeviceGroupFragment on DeviceGroup
  @relay(plural: true) {
    name
    handle
    selector
  }
`;

type TableRecord = DeviceGroupsTable_DeviceGroupFragment$data[0];

const columns: Column<TableRecord>[] = [
  {
    accessor: "name",
    Header: (
      <FormattedMessage
        id="components.DeviceGroupsTable.nameTitle"
        defaultMessage="Group Name"
        description="Title for the Name column of the device groups table"
      />
    ),
  },
  {
    accessor: "handle",
    Header: (
      <FormattedMessage
        id="components.DeviceGroupsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the device groups table"
      />
    ),
  },
  {
    accessor: "selector",
    Header: (
      <FormattedMessage
        id="components.DeviceGroupsTable.selectorTitle"
        defaultMessage="Selector"
        description="Title for the Selector column of the device groups table"
      />
    ),
  },
];

interface Props {
  className?: string;
  deviceGroupsRef: DeviceGroupsTable_DeviceGroupFragment$key;
}

const DeviceGroupsTable = ({ className, deviceGroupsRef }: Props) => {
  const deviceGroupsData = useFragment(
    DEVICE_GROUPS_TABLE_FRAGMENT,
    deviceGroupsRef
  );

  // TODO: handle readonly type without mapping to mutable type
  const deviceGroups = useMemo(
    () => deviceGroupsData.map((group) => ({ ...group })),
    [deviceGroupsData]
  );

  return <Table className={className} columns={columns} data={deviceGroups} />;
};

export default DeviceGroupsTable;
