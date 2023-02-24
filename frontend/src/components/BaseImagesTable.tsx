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
  BaseImagesTable_BaseImagesFragment$data,
  BaseImagesTable_BaseImagesFragment$key,
} from "api/__generated__/BaseImagesTable_BaseImagesFragment.graphql";

import Table from "components/Table";
import type { Column } from "components/Table";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const BASE_IMAGES_TABLE_FRAGMENT = graphql`
  fragment BaseImagesTable_BaseImagesFragment on BaseImageCollection {
    id
    baseImages {
      id
      version
      startingVersionRequirement
      releaseDisplayName
    }
  }
`;

type TableRecord =
  BaseImagesTable_BaseImagesFragment$data["baseImages"][number];

const getColumnsDefinition = (
  baseImageCollectionId: string
): Column<TableRecord>[] => [
  {
    accessor: "version",
    Header: (
      <FormattedMessage
        id="components.BaseImagesTable.versionTitle"
        defaultMessage="Base Image Version"
        description="Title for the Version column of the base images table"
      />
    ),
    Cell: ({ row, value }) => (
      <Link
        route={Route.baseImagesEdit}
        params={{ baseImageCollectionId, baseImageId: row.original.id }}
      >
        {value}
      </Link>
    ),
  },
  {
    accessor: "releaseDisplayName",
    Header: (
      <FormattedMessage
        id="components.BaseImagesTable.releaseDisplayNameTitle"
        defaultMessage="Release Name"
        description="Title for the Release Name column of the base images table"
      />
    ),
  },
  {
    accessor: "startingVersionRequirement",
    Header: (
      <FormattedMessage
        id="components.BaseImagesTable.startingVersionRequirementTitle"
        defaultMessage="Supported Starting Versions"
        description="Title for the Supported Starting Versions column of the base images table"
      />
    ),
  },
];

interface Props {
  className?: string;
  baseImageCollectionRef: BaseImagesTable_BaseImagesFragment$key;
  hideSearch?: boolean;
}

const BaseImagesTable = ({
  className,
  baseImageCollectionRef,
  hideSearch = false,
}: Props) => {
  const baseImageCollection = useFragment(
    BASE_IMAGES_TABLE_FRAGMENT,
    baseImageCollectionRef
  );

  const columns = useMemo(
    () => getColumnsDefinition(baseImageCollection.id),
    [baseImageCollection.id]
  );

  return (
    <Table
      className={className}
      columns={columns}
      data={baseImageCollection.baseImages}
      hideSearch={hideSearch}
    />
  );
};

export default BaseImagesTable;
