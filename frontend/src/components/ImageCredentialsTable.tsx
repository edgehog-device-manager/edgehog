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

import { Link, Route } from "Navigation";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { ImageCredentialsTable_imageCredentials_Fragment$key } from "api/__generated__/ImageCredentialsTable_imageCredentials_Fragment.graphql";
import Table, { createColumnHelper } from "components/Table";
import { FunctionComponent, HTMLProps } from "react";
import { ImageCredential } from "types/ImageCredential";

const { imageCredentialsEdit } = Route;

const IMAGE_CREDENTIALS_FRAGMENT = graphql`
  fragment ImageCredentialsTable_imageCredentials_Fragment on ImageCredentials
  @relay(plural: true) {
    id
    # eslint-disable-next-line relay/unused-fields
    label
    # eslint-disable-next-line relay/unused-fields
    username
  }
`;

const columnHelper = createColumnHelper<ImageCredential>();
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
      <Link route={imageCredentialsEdit} params={{ imageCredentialId }}>
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
];

interface Props extends Pick<HTMLProps<HTMLDivElement>, "className"> {
  listImageCredentialsRef: ImageCredentialsTable_imageCredentials_Fragment$key;
}

const ImageCredentialsTable: FunctionComponent<Props> = ({
  listImageCredentialsRef,
  ...props
}) => {
  const imageCredentials = useFragment(
    IMAGE_CREDENTIALS_FRAGMENT,
    listImageCredentialsRef,
  );

  return <Table {...props} columns={columns} data={imageCredentials} />;
};

export default ImageCredentialsTable;
