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

import { useMemo, type ReactNode } from "react";
import { FormattedMessage } from "react-intl";

import type { FilesDownloadTab_fileUploadRequests$data } from "@/api/__generated__/FilesDownloadTab_fileUploadRequests.graphql";

import Button from "@/components/Button";
import Icon from "@/components/Icon";
import RequestStatus from "@/components/RequestStatus";
import Table, { createColumnHelper } from "@/components/Table";

type FileUploadRequestNode = NonNullable<
  NonNullable<
    FilesDownloadTab_fileUploadRequests$data["fileUploadRequests"]
  >["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<FileUploadRequestNode>();
const getColumnsDefinition = (
  setErrorFeedback: (feedback: ReactNode) => void,
) => [
  columnHelper.accessor("status", {
    header: () => (
      <FormattedMessage
        id="components.FileUploadRequestsTable.status"
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
        id="components.FileUploadRequestsTable.progress"
        defaultMessage="Progress"
      />
    ),
    cell: ({ getValue, row }) => {
      const progressTracked = row.original.progressTracked;

      if (!progressTracked) {
        return (
          <span className="text-muted">
            <FormattedMessage
              id="components.FileUploadRequestsTable.status.notTracked"
              defaultMessage="Not Tracked"
            />
          </span>
        );
      }

      const progress = getValue();
      return progress != null ? `${progress}%` : null;
    },
  }),
  columnHelper.accessor("sourceType", {
    header: () => (
      <FormattedMessage
        id="components.FileUploadRequestsTable.source"
        defaultMessage="Source"
      />
    ),
    cell: ({ getValue, row }) => {
      const sourceType = getValue();

      if (sourceType === "FILESYSTEM") {
        return (
          <FormattedMessage
            id="components.FileUploadRequestsTable.source.filesystem"
            defaultMessage="FILESYSTEM: {source}"
            values={{ source: row.original.source ?? "" }}
          />
        );
      }

      if (sourceType === "STORAGE") {
        return (
          <FormattedMessage
            id="components.FileUploadRequestsTable.source.storage"
            defaultMessage="STORAGE: {source}"
            values={{ source: row.original.source ?? "" }}
          />
        );
      }

      return sourceType;
    },
  }),
  columnHelper.accessor("encoding", {
    header: () => (
      <FormattedMessage
        id="components.FileUploadRequestsTable.encoding"
        defaultMessage="Encoding"
      />
    ),
    cell: ({ getValue }) => {
      const encoding = getValue();

      if (!encoding) {
        return (
          <span className="text-muted">
            <FormattedMessage
              id="components.FileUploadRequestsTable.encoding.none"
              defaultMessage="None"
            />
          </span>
        );
      }

      return encoding;
    },
  }),
  columnHelper.accessor("responseMessage", {
    header: () => (
      <FormattedMessage
        id="components.FileUploadRequestsTable.responseMessage"
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
  columnHelper.display({
    id: "actions",
    header: () => (
      <FormattedMessage
        id="components.FileUploadRequestsTable.actions"
        defaultMessage="Actions"
      />
    ),
    cell: ({ row }) => {
      const downloadUrl = row.original.getPresignedUrl;

      const isDownloadReady =
        row.original.status === "COMPLETED" && !!downloadUrl;

      if (!isDownloadReady) {
        return (
          <span className="text-muted">
            <FormattedMessage
              id="components.FileUploadRequestsTable.actions.notAvailableYet"
              defaultMessage="Not available yet"
            />
          </span>
        );
      }

      return (
        <Button
          className="btn p-0 border-0 bg-transparent ms-4"
          onClick={async () => {
            try {
              const resp = await fetch(downloadUrl);

              if (!resp.ok) {
                throw new Error(`Network response was not ok: ${resp.status}`);
              }

              const blob = await resp.blob();
              const objectUrl = URL.createObjectURL(blob);
              const anchor = document.createElement("a");

              anchor.href = objectUrl;
              anchor.download = row.original.source || "file";

              document.body.appendChild(anchor);
              anchor.click();
              anchor.remove();

              URL.revokeObjectURL(objectUrl);
            } catch {
              setErrorFeedback(
                <FormattedMessage
                  id="components.FileUploadRequestsTable.downloadError"
                  defaultMessage="Failed to download file"
                />,
              );
            }
          }}
        >
          <Icon className="text-primary" icon={"arrowDown"} />
        </Button>
      );
    },
  }),
];

type FileUploadRequestsTableProps = {
  requests: FileUploadRequestNode[];
  setErrorFeedback: (feedback: ReactNode) => void;
};

const FileUploadRequestsTable = ({
  requests,
  setErrorFeedback,
}: FileUploadRequestsTableProps) => {
  const columns = useMemo(
    () => getColumnsDefinition(setErrorFeedback),
    [setErrorFeedback],
  );

  if (requests.length === 0) {
    return (
      <p className="text-muted">
        <FormattedMessage
          id="components.FileUploadRequestsTable.noRequests"
          defaultMessage="No file upload requests have been sent yet."
        />
      </p>
    );
  }

  return <Table columns={columns} data={requests} hideSearch />;
};

export default FileUploadRequestsTable;
