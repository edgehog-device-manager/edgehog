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

import type { FilesUploadTab_fileDownloadRequests$data } from "@/api/__generated__/FilesUploadTab_fileDownloadRequests.graphql";

import RequestStatus from "@/components/RequestStatus";
import Table, { createColumnHelper } from "@/components/Table";
import { formatFileSize } from "@/lib/files";
import { Link, Route } from "@/Navigation";

type FileDownloadRequestNode = NonNullable<
  NonNullable<
    FilesUploadTab_fileDownloadRequests$data["fileDownloadRequests"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<FileDownloadRequestNode>();
const columns = [
  columnHelper.accessor("fileName", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.fileName"
        defaultMessage="File Name"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor((row) => row.campaignTarget?.campaign?.name, {
    id: "fileDownloadCampaignName",
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.campaignName"
        defaultMessage="File Download Campaign"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.fileDownloadCampaignsEdit}
        params={{
          fileDownloadCampaignId:
            row.original.campaignTarget?.campaign?.id ?? "",
        }}
      >
        {getValue()}
      </Link>
    ),
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.status"
        defaultMessage="Status"
      />
    ),
    cell: ({ getValue }) => {
      const status = getValue();
      return <RequestStatus status={status} />;
    },
  }),
  columnHelper.accessor("progressPercentage", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.progress"
        defaultMessage="Progress"
      />
    ),
    cell: ({ getValue, row }) => {
      const progressTracked = row.original.progressTracked;

      if (!progressTracked) {
        return (
          <span className="text-muted">
            <FormattedMessage
              id="components.FileDownloadRequestsTable.status.notTracked"
              defaultMessage="Not Tracked"
            />
          </span>
        );
      }

      const progress = getValue();
      return progress != null ? `${progress}%` : null;
    },
  }),
  columnHelper.accessor("destinationType", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.destination"
        defaultMessage="Destination"
      />
    ),
    cell: ({ getValue, row }) => {
      const destinationType = getValue();

      if (destinationType == "FILESYSTEM") {
        return (
          <FormattedMessage
            id="components.FileDownloadRequestsTable.destination.filesystem"
            defaultMessage="FILESYSTEM: {destination}"
            values={{ destination: row.original.destination ?? "" }}
          />
        );
      }

      if (destinationType == "STORAGE") {
        return (
          <FormattedMessage
            id="components.FileDownloadRequestsTable.destination.storage"
            defaultMessage="STORAGE: {path}"
            values={{ path: row.original.pathOnDevice ?? "" }}
          />
        );
      }

      return destinationType;
    },
  }),
  columnHelper.accessor("uncompressedFileSizeBytes", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.fileSize"
        defaultMessage="Uncompressed File Size"
      />
    ),
    cell: ({ getValue }) => {
      const size = getValue();
      return size != null ? formatFileSize(size) : null;
    },
  }),
  columnHelper.accessor("ttlSeconds", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.ttl"
        defaultMessage="TTL (s)"
      />
    ),
    cell: ({ getValue }) => {
      const ttl = getValue();

      if (ttl === 0) {
        return (
          <p>
            <FormattedMessage
              id="components.FileDownloadRequestsTable.ttl.infinite"
              defaultMessage="Infinite"
            />
          </p>
        );
      }

      return ttl;
    },
  }),
  columnHelper.accessor("responseMessage", {
    header: () => (
      <FormattedMessage
        id="components.FileDownloadRequestsTable.responseMessage"
        defaultMessage="Response Message"
      />
    ),
    cell: ({ getValue, row }) => {
      const statusCode = row.original.responseCode;
      const message = getValue();

      if (!statusCode && !message) return null;

      if (!statusCode) return message ?? null;
      if (!message) return String(statusCode);

      return `${statusCode}: ${message}`;
    },
  }),
];

type FileDownloadRequestsTableProps = {
  requests: FileDownloadRequestNode[];
};

const FileDownloadRequestsTable = ({
  requests,
}: FileDownloadRequestsTableProps) => {
  if (requests.length === 0) {
    return (
      <p className="text-muted">
        <FormattedMessage
          id="components.FileDownloadRequestsTable.noRequests"
          defaultMessage="No file download requests have been sent yet."
        />
      </p>
    );
  }

  return <Table columns={columns} data={requests} hideSearch />;
};

export default FileDownloadRequestsTable;
