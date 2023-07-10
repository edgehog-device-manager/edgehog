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

import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  StorageTable_storageUsage$data,
  StorageTable_storageUsage$key,
} from "api/__generated__/StorageTable_storageUsage.graphql";

import Result from "components/Result";
import Table, { createColumnHelper } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const STORAGE_TABLE_FRAGMENT = graphql`
  fragment StorageTable_storageUsage on Device {
    storageUsage {
      label
      totalBytes
      freeBytes
    }
  }
`;

type StorageUnit = NonNullable<
  StorageTable_storageUsage$data["storageUsage"]
>[number];

const formatBytes = (bytes: number, decimals = 2) => {
  if (bytes === 0) return "0 B";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
};

const columnHelper = createColumnHelper<StorageUnit>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.StorageTable.labelTitle"
        defaultMessage="Storage Unit"
      />
    ),
  }),
  columnHelper.accessor("totalBytes", {
    header: () => (
      <FormattedMessage
        id="components.StorageTable.totalSpaceTitle"
        defaultMessage="Total Space"
      />
    ),
    cell: ({ getValue }) => {
      const value = getValue();
      return value === null ? (
        ""
      ) : (
        <span className="text-nowrap">{formatBytes(value)}</span>
      );
    },
  }),
  columnHelper.accessor("freeBytes", {
    header: () => (
      <FormattedMessage
        id="components.StorageTable.freeSpaceTitle"
        defaultMessage="Free Space"
      />
    ),
    cell: ({ getValue }) => {
      const value = getValue();
      return value === null ? (
        ""
      ) : (
        <span className="text-nowrap">{formatBytes(value)}</span>
      );
    },
  }),
];

type Props = {
  className?: string;
  deviceRef: StorageTable_storageUsage$key;
};

const StorageTable = ({ className, deviceRef }: Props) => {
  const { storageUsage } = useFragment(STORAGE_TABLE_FRAGMENT, deviceRef);

  if (!storageUsage || !storageUsage.length) {
    return (
      <Result.EmptyList
        title={
          <FormattedMessage
            id="components.StorageTable.noStorage.title"
            defaultMessage="No storage"
          />
        }
      >
        <FormattedMessage
          id="components.StorageTable.noStorage.message"
          defaultMessage="The device has not detected any storage unit yet."
        />
      </Result.EmptyList>
    );
  }

  return (
    <Table
      className={className}
      columns={columns}
      data={storageUsage}
      hideSearch
    />
  );
};

export default StorageTable;
