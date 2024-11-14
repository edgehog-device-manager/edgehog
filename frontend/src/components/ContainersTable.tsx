/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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
  ContainersTable_ContainerFragment$data,
  ContainersTable_ContainerFragment$key,
} from "api/__generated__/ContainersTable_ContainerFragment.graphql";

import Table, { createColumnHelper } from "components/Table";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CONTAINERS_TABLE_FRAGMENT = graphql`
  fragment ContainersTable_ContainerFragment on ContainerConnection {
    edges {
      node {
        id
        portBindings
        image {
          reference
          credentials {
            label
            username
          }
        }
        networks {
          edges {
            node {
              driver
              internal
            }
          }
        }
      }
    }
  }
`;

type TableRecord = NonNullable<
  ContainersTable_ContainerFragment$data["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("image.reference", {
    id: "imageReference",
    header: () => (
      <FormattedMessage
        id="components.ContainersTable.imageReference"
        defaultMessage="Image Reference"
        description="Title for the Image Reference column of the container table"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("image.credentials.label", {
    id: "imageLabel",
    header: () => (
      <FormattedMessage
        id="components.ContainersTable.credentialsLabel"
        defaultMessage="Credentials Label"
        description="Title for the Credentials Label column of the container table"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("image.credentials.username", {
    id: "imageUsername",
    header: () => (
      <FormattedMessage
        id="components.ContainersTable.credentialsUsername"
        defaultMessage="Credentials Username"
        description="Title for the Credentials Username column of the container table"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor(
    (row) =>
      row.networks.edges
        ?.map((edge) =>
          `${edge.node.driver} ${
            edge.node.internal ? "(internal)" : ""
          }`.trim(),
        )
        .join(", "),
    {
      id: "networks",
      header: () => (
        <FormattedMessage
          id="components.ContainersTable.networks"
          defaultMessage="Networks"
          description="Title for the Networks column of the container table"
        />
      ),
      cell: ({ getValue }) => getValue(),
    },
  ),
  columnHelper.accessor("portBindings", {
    id: "portBindings",
    header: () => (
      <FormattedMessage
        id="components.ContainersTable.portBindings"
        defaultMessage="Port Bindings"
        description="Title for the Port Bindings column of the container table"
      />
    ),
    cell: ({ getValue }) => {
      const portBindings = getValue();
      if (!portBindings || portBindings.length === 0) {
        return "";
      }
      return portBindings.join(", ");
    },
  }),
];

type ContainersTableProps = {
  className?: string;
  containersRef: ContainersTable_ContainerFragment$key;
  hideSearch?: boolean;
};

const ContainersTable = ({
  className,
  containersRef,
  hideSearch = false,
}: ContainersTableProps) => {
  const containers = useFragment(CONTAINERS_TABLE_FRAGMENT, containersRef);
  const data = containers.edges?.map((edge) => edge.node) || [];

  return (
    <Table
      className={className}
      columns={columns}
      data={data}
      hideSearch={hideSearch}
    />
  );
};

export default ContainersTable;
