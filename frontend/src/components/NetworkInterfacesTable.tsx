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
  NetworkInterfacesTable_networkInterfaces$data,
  NetworkInterfacesTable_networkInterfaces$key,
} from "api/__generated__/NetworkInterfacesTable_networkInterfaces.graphql";

import Result from "components/Result";
import Table from "components/Table";
import type { Column } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const NETWORK_INTERFACES_TABLE_FRAGMENT = graphql`
  fragment NetworkInterfacesTable_networkInterfaces on Device {
    networkInterfaces {
      name
      macAddress
      technology
    }
  }
`;

type TableRecord = NonNullable<
  NetworkInterfacesTable_networkInterfaces$data["networkInterfaces"]
>[number];

const renderTechnology = (technology: TableRecord["technology"]) => {
  switch (technology) {
    case "ETHERNET":
      return (
        <FormattedMessage
          id="components.NetworkInterfacesTable.technology.Ethernet"
          defaultMessage="Ethernet"
        />
      );
    case "WIFI":
      return (
        <FormattedMessage
          id="components.NetworkInterfacesTable.technology.WiFi"
          defaultMessage="WiFi"
        />
      );
    case "CELLULAR":
      return (
        <FormattedMessage
          id="components.NetworkInterfacesTable.technology.Cellular"
          defaultMessage="Cellular"
        />
      );
    case "BLUETOOTH":
      return (
        <FormattedMessage
          id="components.NetworkInterfacesTable.technology.Bluetooth"
          defaultMessage="Bluetooth"
        />
      );
    case null:
      return null;

    default:
      return null;
  }
};

const columns: Column<TableRecord>[] = [
  {
    accessor: "name",
    Header: (
      <FormattedMessage
        id="components.NetworkInterfacesTable.nameTitle"
        defaultMessage="Name"
      />
    ),
  },
  {
    accessor: "technology",
    Header: (
      <FormattedMessage
        id="components.NetworkInterfacesTable.technologyTitle"
        defaultMessage="Technology"
      />
    ),
    Cell: ({ value }) => renderTechnology(value),
  },
  {
    accessor: "macAddress",
    Header: (
      <FormattedMessage
        id="components.NetworkInterfacesTable.macAddressTitle"
        defaultMessage="MAC Address"
      />
    ),
  },
];

interface Props {
  className?: string;
  deviceRef: NetworkInterfacesTable_networkInterfaces$key;
}

const NetworkInterfacesTable = ({ className, deviceRef }: Props) => {
  const data = useFragment(NETWORK_INTERFACES_TABLE_FRAGMENT, deviceRef);

  if (!data.networkInterfaces || !data.networkInterfaces.length) {
    return (
      <Result.EmptyList
        title={
          <FormattedMessage
            id="components.NetworkInterfacesTable.noResults.title"
            defaultMessage="No results"
          />
        }
      >
        <FormattedMessage
          id="components.NetworkInterfacesTable.noResults.message"
          defaultMessage="The device has not detected any network interface yet."
        />
      </Result.EmptyList>
    );
  }

  // TODO: handle readonly type without mapping to mutable type
  const networkInterfaces = data.networkInterfaces.map((networkInterface) => ({
    ...networkInterface,
  }));

  return (
    <Table className={className} columns={columns} data={networkInterfaces} />
  );
};

export default NetworkInterfacesTable;
