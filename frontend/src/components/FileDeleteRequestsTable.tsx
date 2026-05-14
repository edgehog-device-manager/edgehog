/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { FormattedMessage } from "react-intl";

import type { FilesDeleteTab_fileManagement$data } from "@/api/__generated__/FilesDeleteTab_fileManagement.graphql";

import RequestStatus from "@/components/RequestStatus";
import Table, { createColumnHelper } from "@/components/Table";

type FileDeleteRequestNode = NonNullable<
  NonNullable<FilesDeleteTab_fileManagement$data["fileDeleteRequests"]>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<FileDeleteRequestNode>();

const columns = [
  columnHelper.accessor((row) => row.fileDownloadRequest.fileName, {
    id: "fileName",
    header: () => (
      <FormattedMessage
        id="components.FileDeleteRequestsTable.fileName"
        defaultMessage="File Name"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),

  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.FileDeleteRequestsTable.status"
        defaultMessage="Status"
      />
    ),
    cell: ({ getValue }) => {
      const status = getValue();

      return <RequestStatus status={status} />;
    },
  }),

  columnHelper.accessor("force", {
    header: () => (
      <FormattedMessage
        id="components.FileDeleteRequestsTable.force"
        defaultMessage="Force Delete"
      />
    ),

    cell: ({ getValue }) => {
      const force = getValue();

      return force ? (
        <span>
          <FormattedMessage
            id="components.FileDeleteRequestsTable.force.enabled"
            defaultMessage="Yes"
          />
        </span>
      ) : (
        <span>
          <FormattedMessage
            id="components.FileDeleteRequestsTable.force.disabled"
            defaultMessage="No"
          />
        </span>
      );
    },
  }),

  columnHelper.accessor("responseMessages", {
    header: () => (
      <FormattedMessage
        id="components.FileDeleteRequestsTable.responseMessages"
        defaultMessage="Response Messages"
      />
    ),

    cell: ({ getValue, row }) => {
      const statusCode = row.original.responseCode;

      const messages = getValue();

      const joinedMessages =
        messages && messages.length > 0 ? messages.join(", ") : null;

      if (!statusCode && !joinedMessages) {
        return null;
      }

      if (!statusCode) {
        return joinedMessages;
      }

      if (!joinedMessages) {
        return String(statusCode);
      }

      return `${statusCode}: ${joinedMessages}`;
    },
  }),
];

type FileDeleteRequestsTableProps = {
  requests: FileDeleteRequestNode[];
};

const FileDeleteRequestsTable = ({
  requests,
}: FileDeleteRequestsTableProps) => {
  if (requests.length === 0) {
    return (
      <p className="text-muted">
        <FormattedMessage
          id="components.FileDeleteRequestsTable.noRequests"
          defaultMessage="No file delete requests have been sent yet."
        />
      </p>
    );
  }

  return <Table columns={columns} data={requests} hideSearch />;
};

export default FileDeleteRequestsTable;
