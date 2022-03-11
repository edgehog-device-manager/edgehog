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

  SPDX-License-Identifier: Apache-2.0
*/

import { FormattedMessage } from "react-intl";

import Table from "components/Table";
import type { Column } from "components/Table";

const formatBytes = (bytes: number, decimals = 2) => {
  if (bytes === 0) return "0 B";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
};

type StorageProps = {
  label: string;
  totalBytes: number | null;
  freeBytes: number | null;
};

const columns: Column<StorageProps>[] = [
  {
    accessor: "label",
    Header: (
      <FormattedMessage
        id="components.StorageTable.labelTitle"
        defaultMessage="Storage Unit"
      />
    ),
  },
  {
    accessor: "totalBytes",
    Header: (
      <FormattedMessage
        id="components.StorageTable.totalSpaceTitle"
        defaultMessage="Total Space"
      />
    ),
    Cell: ({ value }) =>
      value == null ? (
        ""
      ) : (
        <span className="text-nowrap">{formatBytes(value)}</span>
      ),
  },
  {
    accessor: "freeBytes",
    Header: (
      <FormattedMessage
        id="components.StorageTable.freeSpaceTitle"
        defaultMessage="Free Space"
      />
    ),
    Cell: ({ value }) =>
      value == null ? (
        ""
      ) : (
        <span className="text-nowrap">{formatBytes(value)}</span>
      ),
  },
];

interface Props {
  className?: string;
  data: StorageProps[];
}

const StorageTable = ({ className, data }: Props) => {
  return (
    <Table className={className} columns={columns} data={data} hideSearch />
  );
};

export type { StorageProps };

export default StorageTable;
