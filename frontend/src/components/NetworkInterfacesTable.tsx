/*
 * This file is part of Edgehog.
 *
 * Copyright 2023, 2025 SECO Mind Srl
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

import { defineMessages, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  NetworkInterfaceTechnology,
  NetworkInterfacesTable_networkInterfaces$data,
  NetworkInterfacesTable_networkInterfaces$key,
} from "@/api/__generated__/NetworkInterfacesTable_networkInterfaces.graphql";

import Result from "@/components/Result";
import Table, { createColumnHelper } from "@/components/Table";

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

const technologyMessages = defineMessages<NetworkInterfaceTechnology>({
  ETHERNET: {
    id: "components.NetworkInterfacesTable.technology.Ethernet",
    defaultMessage: "Ethernet",
  },
  WIFI: {
    id: "components.NetworkInterfacesTable.technology.WiFi",
    defaultMessage: "WiFi",
  },
  CELLULAR: {
    id: "components.NetworkInterfacesTable.technology.Cellular",
    defaultMessage: "Cellular",
  },
  BLUETOOTH: {
    id: "components.NetworkInterfacesTable.technology.Bluetooth",
    defaultMessage: "Bluetooth",
  },
});

type TableRecord = NonNullable<
  NetworkInterfacesTable_networkInterfaces$data["networkInterfaces"]
>[number];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.NetworkInterfacesTable.nameTitle"
        defaultMessage="Name"
      />
    ),
  }),
  columnHelper.accessor("technology", {
    header: () => (
      <FormattedMessage
        id="components.NetworkInterfacesTable.technologyTitle"
        defaultMessage="Technology"
      />
    ),
    cell: ({ getValue }) => {
      const technology = getValue();
      return (
        technology && (
          <FormattedMessage id={technologyMessages[technology].id} />
        )
      );
    },
  }),
  columnHelper.accessor("macAddress", {
    header: () => (
      <FormattedMessage
        id="components.NetworkInterfacesTable.macAddressTitle"
        defaultMessage="MAC Address"
      />
    ),
  }),
];

type Props = {
  className?: string;
  deviceRef: NetworkInterfacesTable_networkInterfaces$key;
};

const NetworkInterfacesTable = ({ className, deviceRef }: Props) => {
  const { networkInterfaces } = useFragment(
    NETWORK_INTERFACES_TABLE_FRAGMENT,
    deviceRef,
  );

  if (!networkInterfaces || !networkInterfaces.length) {
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

  return (
    <Table className={className} columns={columns} data={networkInterfaces} />
  );
};

export default NetworkInterfacesTable;
