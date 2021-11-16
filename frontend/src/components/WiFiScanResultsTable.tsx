/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import { FormattedDate, FormattedMessage } from "react-intl";

import Table from "components/Table";
import type { Column } from "components/Table";

type WiFiScanResultProps = {
  channel: number | null;
  essid: string | null;
  macAddress: string | null;
  rssi: number | null;
  timestamp: string;
};

const columns: Column<WiFiScanResultProps>[] = [
  {
    accessor: "essid",
    Header: (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apEssidTitle"
        defaultMessage="ESSID"
      />
    ),
  },
  {
    accessor: "channel",
    Header: (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apChannelTitle"
        defaultMessage="Channel"
      />
    ),
  },
  {
    accessor: "macAddress",
    Header: (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apMacAddressTitle"
        defaultMessage="MAC Address"
      />
    ),
  },
  {
    accessor: "rssi",
    Header: (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apRssiTitle"
        defaultMessage="RSSI"
      />
    ),
    Cell: ({ value }) => (value ? `${value} dBm` : ""),
  },
  {
    accessor: "timestamp",
    Header: (
      <FormattedMessage
        id="components.WiFiScanResultsTable.seenAtTitle"
        defaultMessage="Seen at"
      />
    ),
    Cell: ({ value }) => (
      <FormattedDate
        value={new Date(value)}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    ),
  },
];

interface Props {
  className?: string;
  data: WiFiScanResultProps[];
}

const WiFiScanResultsTable = ({ className, data }: Props) => {
  return <Table className={className} columns={columns} data={data} />;
};

export type { WiFiScanResultProps };

export default WiFiScanResultsTable;
