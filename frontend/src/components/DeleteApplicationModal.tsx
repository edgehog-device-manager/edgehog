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

import { useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useMutation } from "react-relay";

import type { DeleteApplicationModal_deleteApplication_Mutation } from "@/api/__generated__/DeleteApplicationModal_deleteApplication_Mutation.graphql";

import DeleteModal from "./DeleteModal";

const DELETE_APPLICATION_MUTATION = graphql`
  mutation DeleteApplicationModal_deleteApplication_Mutation($id: ID!) {
    deleteApplication(id: $id) {
      result {
        id
      }
    }
  }
`;

type Application = {
  id: string;
  name: string;
};

type DeleteApplicationModalProps<A extends Application> = {
  applicationToDelete: A;
  onCancel: () => void;
  onConfirm: () => void;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};
const DeleteApplicationModal = <A extends Application>({
  applicationToDelete,
  onCancel,
  onConfirm,
  setErrorFeedback,
}: DeleteApplicationModalProps<A>) => {
  const [deleteApplication, isDeletingApplication] =
    useMutation<DeleteApplicationModal_deleteApplication_Mutation>(
      DELETE_APPLICATION_MUTATION,
    );

  const handleDeleteApplication = useCallback(() => {
    deleteApplication({
      variables: { id: applicationToDelete.id },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map((error) => error.message)
            .join(". \n");
          return setErrorFeedback(errorFeedback);
        }
        setErrorFeedback(null);
        return onConfirm();
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeleteApplicationModal.deletionErrorFeedback"
            defaultMessage="Could not delete the application, please try again."
          />,
        );
      },
      updater(store, response) {
        const deletedId = response?.deleteApplication?.result?.id;
        if (!deletedId) return;

        store.delete(deletedId);
      },
    });
  }, [applicationToDelete, onConfirm, deleteApplication, setErrorFeedback]);

  return (
    <DeleteModal
      confirmText={applicationToDelete.name || ""}
      onCancel={onCancel}
      onConfirm={handleDeleteApplication}
      isDeleting={isDeletingApplication}
      title={
        <FormattedMessage
          id="components.DeleteApplicationModal.deleteModal.title"
          defaultMessage="Delete Application"
        />
      }
    >
      <p>
        <FormattedMessage
          id="components.DeleteApplicationModal.deleteModal.description"
          defaultMessage="This action cannot be undone. This will permanently delete the application."
        />
      </p>
    </DeleteModal>
  );
};
export default DeleteApplicationModal;
