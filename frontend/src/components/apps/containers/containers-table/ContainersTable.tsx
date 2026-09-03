// This file is part of Edgehog.
//
// Copyright 2024-2026 SECO Mind Srl
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
import { graphql, useFragment, useMutation } from "react-relay/hooks";

import type {
  ContainersTable_ContainerEdgeFragment$data,
  ContainersTable_ContainerEdgeFragment$key,
} from "@/api/__generated__/ContainersTable_ContainerEdgeFragment.graphql";
import type { ContainersTable_deleteContainer_Mutation } from "@/api/__generated__/ContainersTable_deleteContainer_Mutation.graphql";

import { Link, Route } from "@/Navigation";
import { createColumnHelper } from "@tanstack/react-table";
import Button from "@/components/ui/button/Button";
import DeleteModal from "@/components/ui/delete-modal/DeleteModal";
import Icon from "@/components/ui/icon/Icon";
import InfiniteTable from "@/components/ui/infinite-table/InfiniteTable";

/* eslint-disable relay/unused-fields */
const CONTAINERS_TABLE_FRAGMENT = graphql`
  fragment ContainersTable_ContainerEdgeFragment on ContainerConnection {
    edges {
      node {
        id
        name
        image {
          reference
          credentials {
            id
            label
            username
          }
        }
      }
    }
  }
`;

const DELETE_CONTAINER_MUTATION = graphql`
  mutation ContainersTable_deleteContainer_Mutation($containerId: ID!) {
    deleteContainer(id: $containerId) {
      result {
        id
      }
    }
  }
`;

type TableRecord = NonNullable<
  NonNullable<ContainersTable_ContainerEdgeFragment$data>["edges"]
>[number]["node"];

const columnHelper = createColumnHelper<TableRecord>();
const getColumnsDefinition = (
  onDeleteClick: (container: TableRecord) => void,
) => [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.containers-table.ContainersTable.Name"
        defaultMessage="Name"
        description="Title for the Name column of the containers table"
      />
    ),
    meta: {
      label: "Name",
      isPrimaryLink: true,
      getLink: (row, children) => (
        <Link
          route={Route.containersEdit}
          params={{ containerId: row.original.id }}
          className="row-link"
          onClick={(e) => e.stopPropagation()}
        >
          {children}
        </Link>
      ),
    },
    cell: ({ getValue }) => getValue(),
  }),
  columnHelper.accessor("image.reference", {
    header: () => (
      <FormattedMessage
        id="components.apps.containers.containers-table.ContainersTable.imageTitle"
        defaultMessage="Image"
        description="Title for the Image column of the containers table"
      />
    ),
    meta: {
      label: "Image",
    },
  }),
  columnHelper.accessor((row) => row, {
    id: "action",
    header: () => (
      <FormattedMessage
        id="components.apps.containers.containers-table.ContainersTable.actionsTitle"
        defaultMessage="Actions"
      />
    ),
    meta: {
      label: "Actions",
    },
    cell: ({ row }) => {
      const container = row.original;

      return (
        <Button
          className="btn p-0 border-0 bg-transparent"
          onClick={() => onDeleteClick(container)}
        >
          <Icon className="text-danger" icon="delete" />
        </Button>
      );
    },
  }),
];

type ContainersTableProps = {
  className?: string;
  containersRef: ContainersTable_ContainerEdgeFragment$key;
  loading?: boolean;
  onLoadMore?: () => void;
  onSearchChange?: (text: string) => void;
  searchText?: string;
};

const ContainersTable = ({
  className,
  containersRef,
  loading = false,
  onLoadMore,
  onSearchChange,
  searchText,
}: ContainersTableProps) => {
  const containersFragment = useFragment(
    CONTAINERS_TABLE_FRAGMENT,
    containersRef || null,
  );

  const containers = useMemo<TableRecord[]>(() => {
    return compact(containersFragment?.edges?.map((e) => e?.node)) ?? [];
  }, [containersFragment]);

  const [containerToDelete, setContainerToDelete] =
    useState<TableRecord | null>(null);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const columns = useMemo(() => getColumnsDefinition(setContainerToDelete), []);

  const handleCancelDelete = useCallback(() => {
    setContainerToDelete(null);
    setErrorFeedback(null);
  }, []);

  const [deleteContainer, isDeletingContainer] =
    useMutation<ContainersTable_deleteContainer_Mutation>(
      DELETE_CONTAINER_MUTATION,
    );

  const handleDeleteContainer = useCallback(() => {
    if (!containerToDelete) return;

    deleteContainer({
      variables: { containerId: containerToDelete.id },
      onCompleted(_data, errors) {
        if (errors) {
          const errorMessages = errors
            .map((error) => error.message)
            .join(". \n");
          setErrorFeedback(errorMessages);
          return;
        }

        setErrorFeedback(null);
        setContainerToDelete(null);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="components.apps.containers.containers-table.ContainersTable.deletionErrorFeedback"
            defaultMessage="Could not delete the container, please try again."
          />,
        );
      },
      updater(store, response) {
        const deletedId = response?.deleteContainer?.result?.id;
        if (!deletedId) return;

        store.delete(deletedId);
      },
    });
  }, [deleteContainer, containerToDelete]);

  return (
    <>
      <InfiniteTable
        className={className}
        columns={columns}
        data={containers}
        loading={loading}
        onLoadMore={onLoadMore}
        columnVisibilityKey="containers-table"
        onSearchChange={onSearchChange}
        searchText={searchText}
      />
      {containerToDelete && (
        <DeleteModal
          confirmText={containerToDelete.name}
          onCancel={handleCancelDelete}
          onConfirm={handleDeleteContainer}
          isDeleting={isDeletingContainer}
          title={
            <FormattedMessage
              id="components.apps.containers.containers-table.ContainersTable.deleteModal.title"
              defaultMessage="Delete Container"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.apps.containers.containers-table.ContainersTable.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete the Container <bold>{name}</bold>."
              values={{
                name: containerToDelete.name,
                bold: (chunks) => <strong>{chunks}</strong>,
              }}
            />
          </p>
          {errorFeedback && <p className="text-danger">{errorFeedback}</p>}
        </DeleteModal>
      )}
    </>
  );
};

export default ContainersTable;
