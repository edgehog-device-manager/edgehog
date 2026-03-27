// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import _ from "lodash";
import { useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  FilesTable_FileEdgeFragment$data,
  FilesTable_FileEdgeFragment$key,
} from "@/api/__generated__/FilesTable_FileEdgeFragment.graphql";

import Button from "@/components/Button";
import Icon from "@/components/Icon";
import InfiniteTable from "@/components/InfiniteTable";
import { createColumnHelper } from "@/components/Table";
import { formatFileSize } from "@/lib/files";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const FILES_TABLE_FRAGMENT = graphql`
  fragment FilesTable_FileEdgeFragment on FileConnection {
    edges {
      node {
        id
        name
        size
        getPresignedUrl
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<FilesTable_FileEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const getColumnsDefinition = (
  setErrorFeedback: (feedback: React.ReactNode) => void,
) => [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.FilesTable.nameTitle"
        defaultMessage="File Name"
        description="Title for the File Name column of the files table"
      />
    ),
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("size", {
    header: () => (
      <FormattedMessage
        id="components.FilesTable.sizeTitle"
        defaultMessage="File Size"
        description="Title for the File Size column of the files table"
      />
    ),
    cell: ({ getValue }) => {
      const size = getValue();
      if (size == null) return null;
      return formatFileSize(size);
    },
  }),
  columnHelper.accessor((row) => row, {
    id: "action",
    header: () => (
      <FormattedMessage
        id="components.FilesTable.action"
        defaultMessage="Action"
      />
    ),
    cell: ({ row }) => (
      <Button
        className="btn p-0 border-0 bg-transparent ms-4"
        onClick={async () => {
          const url = row.original.getPresignedUrl;
          if (!url) return;
          try {
            const resp = await fetch(url);
            if (!resp.ok)
              throw new Error(`Network response was not ok: ${resp.status}`);
            const blob = await resp.blob();
            const downloadUrl = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = downloadUrl;
            a.download = row.original.name || "file";
            document.body.appendChild(a);
            a.click();
            a.remove();
            URL.revokeObjectURL(downloadUrl);
          } catch {
            setErrorFeedback(
              <FormattedMessage
                id="components.FilesTable.downloadError"
                defaultMessage="Failed to download file"
              />,
            );
          }
        }}
      >
        <Icon className="text-primary" icon={"arrowDown"} />
      </Button>
    ),
  }),
];

type Props = {
  className?: string;
  setErrorFeedback: (feedback: React.ReactNode) => void;
  filesRef: FilesTable_FileEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const FilesTable = ({
  className,
  setErrorFeedback,
  filesRef,
  loading = false,
  onLoadMore,
}: Props) => {
  const filesFragment = useFragment(FILES_TABLE_FRAGMENT, filesRef || null);
  const files = useMemo<TableRecord[]>(() => {
    return _.compact(filesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [filesFragment]);

  const columns = useMemo(
    () => getColumnsDefinition(setErrorFeedback),
    [setErrorFeedback],
  );

  return (
    <InfiniteTable
      className={className}
      columns={columns}
      data={files}
      loading={loading}
      onLoadMore={onLoadMore}
      hideSearch
    />
  );
};

export default FilesTable;
