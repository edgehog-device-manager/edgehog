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

import { FormattedMessage } from "react-intl";
import { useCallback, useState } from "react";
import { graphql, useFragment, useMutation } from "react-relay/hooks";

import type {
  ApplicationsTable_ApplicationFragment$data,
  ApplicationsTable_ApplicationFragment$key,
} from "api/__generated__/ApplicationsTable_ApplicationFragment.graphql";
import type { ApplicationsTable_deleteApplication_Mutation } from "api/__generated__/ApplicationsTable_deleteApplication_Mutation.graphql";

import { Link, Route } from "Navigation";
import Table, { createColumnHelper } from "components/Table";
import DeleteModal from "components/DeleteModal";
import Button from "components/Button";
import Icon from "components/Icon";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const APPLICATIONS_TABLE_FRAGMENT = graphql`
  fragment ApplicationsTable_ApplicationFragment on Application
  @relay(plural: true) {
    id
    name
    description
  }
`;

const DELETE_APPLICATION_MUTATION = graphql`
  mutation ApplicationsTable_deleteApplication_Mutation($id: ID!) {
    deleteApplication(id: $id) {
      result {
        id
      }
    }
  }
`;

type TableRecord = ApplicationsTable_ApplicationFragment$data[0];

type ApplicationsTableProps = {
  className?: string;
  applicationsRef: ApplicationsTable_ApplicationFragment$key;
  hideSearch?: boolean;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

const ApplicationsTable = ({
  className,
  applicationsRef,
  hideSearch = false,
  setErrorFeedback,
}: ApplicationsTableProps) => {
  const applications = useFragment(
    APPLICATIONS_TABLE_FRAGMENT,
    applicationsRef,
  );
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [selectedApplication, setSelectedApplication] =
    useState<TableRecord | null>(null);

  const [deleteApplication, isDeletingApplication] =
    useMutation<ApplicationsTable_deleteApplication_Mutation>(
      DELETE_APPLICATION_MUTATION,
    );

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const handleDeleteApplication = useCallback(
    (applicationId: string) => {
      deleteApplication({
        variables: { id: applicationId },
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
              id="components.ApplicationsTable.deletionErrorFeedback"
              defaultMessage="Could not delete the application, please try again."
            />,
          );
          setShowDeleteModal(false);
        },
        updater(store, response) {
          const deletedId = response?.deleteApplication?.result?.id;
          if (!deletedId) return;

          const root = store.getRoot();
          const applications = root.getLinkedRecord("applications");
          if (!applications) return;

          const results = applications.getLinkedRecords("results");
          if (!results) return;

          applications.setLinkedRecords(
            results.filter((app) => app.getDataID() !== deletedId),
            "results",
          );

          store.delete(deletedId);
        },
      });
    },
    [deleteApplication],
  );

  const columnHelper = createColumnHelper<TableRecord>();
  const columns = [
    columnHelper.accessor("name", {
      header: () => (
        <FormattedMessage
          id="components.ApplicationsTable.nameTitle"
          defaultMessage="Application Name"
          description="Title for the Name column of the applications table"
        />
      ),
      cell: ({ row, getValue }) => (
        <Link
          route={Route.application}
          params={{ applicationId: row.original.id }}
        >
          {getValue()}
        </Link>
      ),
    }),
    columnHelper.accessor((row) => row, {
      id: "action",
      header: () => (
        <FormattedMessage
          id="components.ApplicationsTable.action"
          defaultMessage="Action"
        />
      ),
      cell: ({ getValue }) => (
        <Button
          className="btn p-0 border-0 bg-transparent ms-4"
          onClick={() => {
            setSelectedApplication(getValue());
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
      <Table
        className={className}
        columns={columns}
        data={applications}
        hideSearch={hideSearch}
      />
      {showDeleteModal && (
        <DeleteModal
          confirmText={selectedApplication?.name || ""}
          onCancel={() => setShowDeleteModal(false)}
          onConfirm={() => {
            if (selectedApplication?.id) {
              handleDeleteApplication(selectedApplication.id);
            }
          }}
          isDeleting={isDeletingApplication}
          title={
            <FormattedMessage
              id="components.ApplicationsTable.deleteModal.title"
              defaultMessage="Delete Application"
            />
          }
        >
          <p>
            <FormattedMessage
              id="components.ApplicationsTable.deleteModal.description"
              defaultMessage="This action cannot be undone. This will permanently delete the application."
            />
          </p>
        </DeleteModal>
      )}
    </div>
  );
};

export default ApplicationsTable;
