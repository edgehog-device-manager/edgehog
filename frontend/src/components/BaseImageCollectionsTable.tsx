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

import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay";

import type {
  BaseImageCollectionsTable_BaseImageCollectionFragment$data,
  BaseImageCollectionsTable_BaseImageCollectionFragment$key,
} from "api/__generated__/BaseImageCollectionsTable_BaseImageCollectionFragment.graphql";

import Table from "components/Table";
import type { Column } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BASE_IMAGE_COLLECTIONS_TABLE_FRAGMENT = graphql`
  fragment BaseImageCollectionsTable_BaseImageCollectionFragment on BaseImageCollection
  @relay(plural: true) {
    name
    handle
    systemModel {
      name
    }
  }
`;

type TableRecord =
  BaseImageCollectionsTable_BaseImageCollectionFragment$data[number];

const columns: Column<TableRecord>[] = [
  {
    accessor: "name",
    Header: (
      <FormattedMessage
        id="components.BaseImageCollectionsTable.nameTitle"
        defaultMessage="Base Image Collection Name"
        description="Title for the Name column of the base image collections table"
      />
    ),
  },
  {
    accessor: "handle",
    Header: (
      <FormattedMessage
        id="components.BaseImageCollectionsTable.handleTitle"
        defaultMessage="Handle"
        description="Title for the Handle column of the base image collections table"
      />
    ),
  },
  {
    id: "systemModel",
    accessor: (row) => row.systemModel?.name,
    Header: (
      <FormattedMessage
        id="components.BaseImageCollectionsTable.systemModelTitle"
        defaultMessage="System Model"
        description="Title for the System Model column of the base image collections table"
      />
    ),
    Cell: ({ value }: { value: string }) => (
      <span className="text-nowrap">{value}</span>
    ),
  },
];

interface Props {
  className?: string;
  baseImageCollectionsRef: BaseImageCollectionsTable_BaseImageCollectionFragment$key;
}

const BaseImageCollectionsTable = ({
  className,
  baseImageCollectionsRef,
}: Props) => {
  const baseImageCollectionsData = useFragment(
    BASE_IMAGE_COLLECTIONS_TABLE_FRAGMENT,
    baseImageCollectionsRef
  );

  // TODO: handle readonly type without mapping to mutable type
  const baseImageCollections = useMemo(
    () =>
      baseImageCollectionsData.map((collection) => ({
        ...collection,
        systemModel: collection.systemModel && {
          name: collection.systemModel.name,
        },
      })),
    [baseImageCollectionsData]
  );

  return (
    <Table
      className={className}
      columns={columns}
      data={baseImageCollections}
    />
  );
};

export default BaseImageCollectionsTable;
