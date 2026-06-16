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

import compact from "lodash/compact";
import { useCallback, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { useMutation } from "react-relay";

import type {
  FilesTable_FileEdgeFragment$data,
  FilesTable_FileEdgeFragment$key,
} from "@/api/__generated__/FilesTable_FileEdgeFragment.graphql";

import type { FilesTable_deleteFile_Mutation } from "@/api/__generated__/FilesTable_deleteFile_Mutation.graphql";

import Button from "@/components/Button";
import DeleteModal from "@/components/DeleteModal";
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
        baseFile {
          url
        }
      }
    }
  }
`;

const DELETE_FILE_MUTATION = graphql`
  mutation FilesTable_deleteFile_Mutation($fileId: ID!) {
    deleteFile(id: $fileId) {
      result {
        id
      }
    }
  }
`;

type FileActionsProps = {
  file: TableRecord;
  onDeleteClick: (file: TableRecord) => void;
};

const FileActions = ({ file, onDeleteClick }: FileActionsProps) => {
  const handleDownload = () => {
    const url = file.baseFile.url;
    if (!url) return;

    const a = document.createElement("a");
    a.href = url;
    a.download = file.name || "file";
    a.target = "_blank";
    document.body.appendChild(a);
    a.click();
    a.remove();
  };

  return (
    <div className="d-inline-flex align-items-center gap-2">
      <Button
        className="btn p-0 border-0 bg-transparent"
        onClick={handleDownload}
      >
        <Icon className="text-primary" icon="arrowDown" />
      </Button>

      <Button
        className="btn p-0 border-0 bg-transparent"
        onClick={() => onDeleteClick(file)}
      >
        <Icon className="text-danger" icon="delete" />
      </Button>
    </div>
  );
};

type TableRecord = NonNullable<
  NonNullable<FilesTable_FileEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const getColumnsDefinition = (onDeleteClick: (file: TableRecord) => void) => [
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
      return size != null ? formatFileSize(size) : null;
    },
  }),
  columnHelper.accessor((row) => row, {
    id: "action",
    header: () => (
      <FormattedMessage
        id="components.FilesTable.actionsTitle"
        defaultMessage="Actions"
      />
    ),
    cell: ({ row }) => {
      const file = row.original;

      return <FileActions file={file} onDeleteClick={onDeleteClick} />;
    },
  }),
];

type Props = {
  className?: string;
  filesRef: FilesTable_FileEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
};

const FilesTable = ({
  className,
  filesRef,
  loading = false,
  onLoadMore,
}: Props) => {
  const filesFragment = useFragment(FILES_TABLE_FRAGMENT, filesRef || null);
  const files = useMemo<TableRecord[]>(() => {
    return compact(filesFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [filesFragment]);

  const [fileToDelete, setFileToDelete] = useState<TableRecord | null>(null);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const columns = useMemo(() => getColumnsDefinition(setFileToDelete), []);

  const handleCancelDelete = useCallback(() => {
    setFileToDelete(null);
    setErrorFeedback(null);
  }, []);

  const [deleteFile, isDeletingFile] =
    useMutation<FilesTable_deleteFile_Mutation>(DELETE_FILE_MUTATION);

  const handleDeleteFile = useCallback(() => {
    if (!fileToDelete) return;

    deleteFile({
      variables: { fileId: fileToDelete.id },
      onCompleted(_data, errors) {
        if (errors) {
          const errorMessages = errors
            .map((error) => error.message)
            .join(". \n");
          setErrorFeedback(errorMessages);
          return;
        }

        setErrorFeedback(null);
        setFileToDelete(null);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="components.FilesTable.deletionErrorFeedback"
            defaultMessage="Could not delete the file, please try again."
          />,
        );
      },
      updater(store, response) {
        const deletedId = response?.deleteFile?.result?.id;
        if (!deletedId) return;

        store.delete(deletedId);
      },
    });
  }, [deleteFile, fileToDelete]);

  return (
    <>
      <InfiniteTable
        className={className}
        columns={columns}
        data={files}
        loading={loading}
        onLoadMore={onLoadMore}
      />
      {fileToDelete && (
        <DeleteModal
          confirmText={fileToDelete.name || ""}
          onCancel={handleCancelDelete}
          onConfirm={handleDeleteFile}
          isDeleting={isDeletingFile}
          title={
            <FormattedMessage
              id="components.FilesTable.deleteModal.title"
              defaultMessage="Delete File"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.FilesTable.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete the file."
            />
          </p>
          {errorFeedback && <p className="text-danger">{errorFeedback}</p>}
        </DeleteModal>
      )}
    </>
  );
};

export default FilesTable;
