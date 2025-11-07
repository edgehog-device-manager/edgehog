/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePaginationFragment,
} from "react-relay/hooks";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Button } from "react-bootstrap";
import _ from "lodash";

import type { ReleasesTable_PaginationQuery } from "api/__generated__/ReleasesTable_PaginationQuery.graphql";
import type {
  ReleasesTable_ReleaseFragment$data,
  ReleasesTable_ReleaseFragment$key,
} from "api/__generated__/ReleasesTable_ReleaseFragment.graphql";
import type { ReleasesTable_deleteRelease_Mutation } from "api/__generated__/ReleasesTable_deleteRelease_Mutation.graphql";

import { Link, Route } from "Navigation";
import { createColumnHelper } from "components/Table";
import Icon from "components/Icon";
import DeleteModal from "./DeleteModal";
import InfiniteTable from "./InfiniteTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "constants";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const RELEASES_TABLE_FRAGMENT = graphql`
  fragment ReleasesTable_ReleaseFragment on Application
  @refetchable(queryName: "ReleasesTable_PaginationQuery")
  @argumentDefinitions(filter: { type: "ReleaseFilterInput" }) {
    releases(first: $first, after: $after, filter: $filter)
      @connection(key: "ReleasesTable_releases") {
      edges {
        node {
          id
          version
          application {
            id
          }
        }
      }
    }
  }
`;

const DELETE_RELEASE_MUTATION = graphql`
  mutation ReleasesTable_deleteRelease_Mutation($id: ID!) {
    deleteRelease(id: $id) {
      result {
        id
      }
    }
  }
`;

type TableRecord = NonNullable<
  ReleasesTable_ReleaseFragment$data["releases"]["edges"]
>[number]["node"];

type ReleaseTableProps = {
  className?: string;
  releasesRef: ReleasesTable_ReleaseFragment$key;
  hideSearch?: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

const ReleasesTable = ({
  className,
  releasesRef,
  hideSearch = false,
  setErrorFeedback,
}: ReleaseTableProps) => {
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [selectedRelease, setSelectedRelease] = useState<TableRecord | null>(
    null,
  );

  const [deleteRelease, isDeletingRelease] =
    useMutation<ReleasesTable_deleteRelease_Mutation>(DELETE_RELEASE_MUTATION);

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const handleDeleteRelease = useCallback(
    (releaseId: string) => {
      deleteRelease({
        variables: { id: releaseId },
        onCompleted(data, errors) {
          if (
            !errors ||
            errors.length === 0 ||
            errors[0].code === "not_found"
          ) {
            setErrorFeedback(null);
            setShowDeleteModal(false);
            return;
          }

          const errorFeedback = errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(" ")} ${message}` : message,
            )
            .join(". \n");
          setErrorFeedback(errorFeedback);
          setShowDeleteModal(false);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="components.ReleasesTable.deletionErrorFeedback"
              defaultMessage="Could not delete the release, please try again."
            />,
          );
          setShowDeleteModal(false);
        },
        updater(store, response) {
          const deletedId = response?.deleteRelease?.result?.id;
          if (!deletedId) return;

          const applicationId = store
            .getRootField("deleteRelease")
            ?.getLinkedRecord("result")
            ?.getLinkedRecord("application")
            ?.getDataID();

          if (!applicationId) return;

          const applicationRecord = store.get(applicationId);
          if (!applicationRecord) return;

          const releasesConnection = ConnectionHandler.getConnection(
            applicationRecord,
            "ReleasesTable_releases",
          );
          if (!releasesConnection) return;

          ConnectionHandler.deleteNode(releasesConnection, deletedId);

          const devicesConnection = ConnectionHandler.getConnection(
            applicationRecord,
            "ApplicationDevicesTable_releases",
          );
          if (!devicesConnection) return;

          ConnectionHandler.deleteNode(devicesConnection, deletedId);

          store.delete(deletedId);
        },
      });
    },
    [deleteRelease],
  );

  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      ReleasesTable_PaginationQuery,
      ReleasesTable_ReleaseFragment$key
    >(RELEASES_TABLE_FRAGMENT, releasesRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { version: { ilike: "%${text}%" } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextReleases = useCallback(() => {
    if (hasNext && !isLoadingNext) loadNext(RECORDS_TO_LOAD_NEXT);
  }, [hasNext, isLoadingNext, loadNext]);

  const releases: TableRecord[] = useMemo(() => {
    return (
      data.releases?.edges
        ?.map((edge) => edge?.node)
        .filter(
          (node): node is TableRecord => node !== undefined && node !== null,
        ) ?? []
    );
  }, [data]);

  const columnHelper = createColumnHelper<TableRecord>();
  const columns = [
    columnHelper.accessor("version", {
      header: () => (
        <FormattedMessage
          id="components.ReleaseTable.versionTitle"
          defaultMessage="Release Version"
          description="Title for the Release Version column of the releases table"
        />
      ),
      cell: ({ row, getValue }) => (
        <Link
          route={Route.release}
          params={{
            applicationId: row.original.application?.id ?? "",
            releaseId: row.original.id,
          }}
        >
          {getValue()}
        </Link>
      ),
    }),
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.ReleasesTable.action"
          defaultMessage="Action"
        />
      ),
      cell: ({ getValue }) => (
        <Button
          className="btn p-0 border-0 bg-transparent ms-4"
          onClick={() => {
            setSelectedRelease(getValue());
            handleShowDeleteModal();
          }}
        >
          <Icon className="text-danger" icon={"delete"} />
        </Button>
      ),
    }),
  ];

  return (
    <div>
      <InfiniteTable
        className={className}
        columns={columns}
        data={releases}
        loading={isLoadingNext}
        onLoadMore={hasNext ? loadNextReleases : undefined}
        setSearchText={hideSearch ? undefined : setSearchText}
        hideSearch={hideSearch}
      />

      {showDeleteModal && (
        <DeleteModal
          confirmText={selectedRelease?.version || ""}
          onCancel={() => setShowDeleteModal(false)}
          onConfirm={() => {
            if (selectedRelease?.id && selectedRelease.application?.id) {
              handleDeleteRelease(selectedRelease.id);
            }
          }}
          isDeleting={isDeletingRelease}
          title={
            <FormattedMessage
              id="components.ReleasesTable.deleteModal.title"
              defaultMessage="Delete Release"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.ReleasesTable.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete the release."
            />
          </p>
        </DeleteModal>
      )}
    </div>
  );
};

export default ReleasesTable;
