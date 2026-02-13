/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  ImageCredentialsTable_ImageCredentialEdgeFragment$data,
  ImageCredentialsTable_ImageCredentialEdgeFragment$key,
} from "@/api/__generated__/ImageCredentialsTable_ImageCredentialEdgeFragment.graphql";

import { createColumnHelper } from "@/components/Table";
import { Link, Route } from "@/Navigation";
import InfiniteTable from "./InfiniteTable";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const IMAGE_CREDENTIALS_TABLE_FRAGMENT = graphql`
  fragment ImageCredentialsTable_ImageCredentialEdgeFragment on ImageCredentialsConnection {
    edges {
      node {
        id
        label
        username
        serveraddress
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<ImageCredentialsTable_ImageCredentialEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("label", {
    header: () => (
      <FormattedMessage
        id="components.ImageCredentialsTable.labelTitle"
        defaultMessage="Label"
      />
    ),
    cell: ({
      row: {
        original: { id: imageCredentialId },
      },
      getValue,
    }) => (
      <Link route={Route.imageCredentialsEdit} params={{ imageCredentialId }}>
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("username", {
    header: () => (
      <FormattedMessage
        id="components.ImageCredentialsTable.usernameTitle"
        defaultMessage="Username"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
  columnHelper.accessor("serveraddress", {
    header: () => (
      <FormattedMessage
        id="components.ImageCredentialsTable.serveraddressTitle"
        defaultMessage="Server Address"
      />
    ),
    cell: ({ getValue }) => <span className="text-nowrap">{getValue()}</span>,
  }),
];

type ImageCredentialsTableProps = {
  className?: string;
  imageCredentialsRef: ImageCredentialsTable_ImageCredentialEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const ImageCredentialsTable = ({
  className,
  imageCredentialsRef,
  loading = false,
  onLoadMore,
}: ImageCredentialsTableProps) => {
  const imageCredentialsFragment = useFragment(
    IMAGE_CREDENTIALS_TABLE_FRAGMENT,
    imageCredentialsRef || null,
  );

  const imageCredentials = useMemo<TableRecord[]>(() => {
    return (
      _.compact(imageCredentialsFragment?.edges?.map((e) => e?.node)) ?? []
    );
  }, [imageCredentialsFragment]);
  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={imageCredentials}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default ImageCredentialsTable;
