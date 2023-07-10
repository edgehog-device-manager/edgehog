/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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

import { FormattedDate, FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  WiFiScanResultsTable_wifiScanResults$data,
  WiFiScanResultsTable_wifiScanResults$key,
} from "api/__generated__/WiFiScanResultsTable_wifiScanResults.graphql";

import Result from "components/Result";
import Table, { createColumnHelper } from "components/Table";
import type { Row } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const WIFI_SCAN_RESULTS_TABLE_FRAGMENT = graphql`
  fragment WiFiScanResultsTable_wifiScanResults on Device {
    wifiScanResults {
      channel
      connected
      essid
      macAddress
      rssi
      timestamp
    }
  }
`;

type TableRecord = Omit<
  NonNullable<WiFiScanResultsTable_wifiScanResults$data["wifiScanResults"]>[0],
  "timestamp"
> & { readonly seenAt: Date };

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("essid", {
    header: () => (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apEssidTitle"
        defaultMessage="ESSID"
      />
    ),
  }),
  columnHelper.accessor("channel", {
    header: () => (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apChannelTitle"
        defaultMessage="Channel"
      />
    ),
  }),
  columnHelper.accessor("macAddress", {
    header: () => (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apMacAddressTitle"
        defaultMessage="MAC Address"
      />
    ),
  }),
  columnHelper.accessor("rssi", {
    header: () => (
      <FormattedMessage
        id="components.WiFiScanResultsTable.apRssiTitle"
        defaultMessage="RSSI"
      />
    ),
    cell: ({ getValue }) => {
      const rssi = getValue();
      return rssi === null ? "" : `${rssi} dBm`;
    },
  }),
  columnHelper.accessor("seenAt", {
    header: () => (
      <FormattedMessage
        id="components.WiFiScanResultsTable.seenAtTitle"
        defaultMessage="Seen at"
      />
    ),
    cell: ({ getValue }) => (
      <FormattedDate
        value={getValue()}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    ),
  }),
];

const getRowProps = (row: Row<TableRecord>) => {
  return row.original.connected ? { className: "fw-bold" } : {};
};

type Props = {
  className?: string;
  deviceRef: WiFiScanResultsTable_wifiScanResults$key;
};

const WiFiScanResultsTable = ({ className, deviceRef }: Props) => {
  const data = useFragment(WIFI_SCAN_RESULTS_TABLE_FRAGMENT, deviceRef);

  if (!data.wifiScanResults || !data.wifiScanResults.length) {
    return (
      <Result.EmptyList
        title={
          <FormattedMessage
            id="pages.Device.wifiScanResultsTab.noResults.title"
            defaultMessage="No results"
          />
        }
      >
        <FormattedMessage
          id="pages.Device.wifiScanResultsTab.noResults.message"
          defaultMessage="The device has not detected any WiFi AP yet."
        />
      </Result.EmptyList>
    );
  }

  let connectedFound = false;
  const wifiScanResults = data.wifiScanResults
    .map((scanResult) => {
      const { timestamp, ...rest } = scanResult;
      return {
        ...rest,
        seenAt: new Date(timestamp),
      };
    })
    .sort((scan1, scan2) => scan2.seenAt.getDate() - scan1.seenAt.getDate())
    .map((scanResult) => {
      if (!connectedFound && scanResult.connected) {
        connectedFound = true;
        return scanResult;
      }
      return {
        ...scanResult,
        connected: false,
      };
    });

  return (
    <Table
      className={className}
      columns={columns}
      data={wifiScanResults}
      getRowProps={getRowProps}
    />
  );
};

export default WiFiScanResultsTable;
