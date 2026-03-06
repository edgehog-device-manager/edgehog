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

import { defineMessages, FormattedMessage } from "react-intl";

import type { FilesUploadTab_fileDownloadRequests$data } from "@/api/__generated__/FilesUploadTab_fileDownloadRequests.graphql";

import Icon from "@/components/Icon";
import Table, { createColumnHelper } from "@/components/Table";

type FileDownloadRequestNode = NonNullable<
  NonNullable<
    FilesUploadTab_fileDownloadRequests$data["fileDownloadRequests"]
  >["edges"]
>[number]["node"];

type FileDownloadRequestStatus =
  | "COMPLETED"
  | "FAILED"
  | "IN_PROGRESS"
  | "PENDING"
  | "SENT";

const statusColors: Record<string, string> = {
  COMPLETED: "text-success",
  FAILED: "text-danger",
  IN_PROGRESS: "text-info",
  PENDING: "text-warning",
  SENT: "text-primary",
};

const statusMessages = defineMessages({
  COMPLETED: {
    id: "components.FilesUploadTab.status.completed",
    defaultMessage: "Completed",
  },
  FAILED: {
    id: "components.FilesUploadTab.status.failed",
    defaultMessage: "Failed",
  },
  IN_PROGRESS: {
    id: "components.FilesUploadTab.status.inProgress",
    defaultMessage: "In Progress",
  },
  PENDING: {
    id: "components.FilesUploadTab.status.pending",
    defaultMessage: "Pending",
  },
  SENT: {
    id: "components.FilesUploadTab.status.sent",
    defaultMessage: "Sent",
  },
});

const RequestStatus = ({
  status,
}: {
  status: FileDownloadRequestStatus | null;
}) => {
  if (status === null) {
    return null;
  }

  const color = statusColors[status] ?? "text-secondary";
  const message = statusMessages[status as keyof typeof statusMessages];

  const iconName = status === "IN_PROGRESS" ? "spinner" : "circle";
  const iconClass =
    status === "IN_PROGRESS"
      ? `me-2 ${color} spinner-border spinner-border-sm`
      : `me-2 ${color}`;

  return (
    <div className="d-flex align-items-center">
      <Icon icon={iconName} className={iconClass} />
      <span>{message ? <FormattedMessage id={message.id} /> : status}</span>
    </div>
  );
};

const columnHelper = createColumnHelper<FileDownloadRequestNode>();
const columns = [
  columnHelper.accessor("fileName", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.fileName"
        defaultMessage="File Name"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.status"
        defaultMessage="Status"
      />
    ),
    cell: ({ getValue, row }) => {
      const progressTracked = row.original.progress;

      if (!progressTracked) {
        return (
          <span className="text-muted">
            <FormattedMessage
              id="components.FilesUploadTab.status.notTracked"
              defaultMessage="Not Tracked"
            />
          </span>
        );
      }

      const status = getValue();
      return <RequestStatus status={status} />;
    },
  }),
  columnHelper.accessor("statusProgress", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.progress"
        defaultMessage="Progress"
      />
    ),
    cell: ({ getValue, row }) => {
      const progressTracked = row.original.progress;

      if (!progressTracked) {
        return (
          <span className="text-muted">
            <FormattedMessage
              id="components.FilesUploadTab.status.notTracked"
              defaultMessage="Not Tracked"
            />
          </span>
        );
      }

      const progress = getValue();
      return progress != null ? `${progress}%` : null;
    },
  }),
  columnHelper.accessor("destination", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.destination"
        defaultMessage="Destination"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("uncompressedFileSizeBytes", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.fileSize"
        defaultMessage="File Size"
      />
    ),
    cell: ({ getValue }) => {
      const size = getValue();
      if (size == null) return null;
      if (size < 1024) return `${size} B`;
      if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
      if (size < 1024 * 1024 * 1024)
        return `${(size / (1024 * 1024)).toFixed(1)} MB`;
      return `${(size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    },
  }),
  columnHelper.accessor("ttlSeconds", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.ttl"
        defaultMessage="TTL (s)"
      />
    ),
    cell: ({ getValue }) => {
      const ttl = getValue();

      if (ttl === 0) {
        return (
          <p>
            <FormattedMessage
              id="components.FilesUploadTab.table.infinite"
              defaultMessage="Infinite"
            />
          </p>
        );
      }

      return ttl;
    },
  }),
  columnHelper.accessor("message", {
    header: () => (
      <FormattedMessage
        id="components.FilesUploadTab.table.message"
        defaultMessage="Message"
      />
    ),
    cell: ({ getValue, row }) => {
      const statusCode = row.original.statusCode;
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
          id="components.DeviceTabs.FilesUploadTab.noRequests"
          defaultMessage="No file download requests have been sent yet."
        />
      </p>
    );
  }

  return <Table columns={columns} data={requests} hideSearch />;
};

export default FileDownloadRequestsTable;
