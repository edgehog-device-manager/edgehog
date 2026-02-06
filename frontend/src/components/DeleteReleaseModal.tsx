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

import type { DeleteReleaseModal_deleteRelease_Mutation } from "@/api/__generated__/DeleteReleaseModal_deleteRelease_Mutation.graphql";

import DeleteModal from "./DeleteModal";

const DELETE_RELEASE_MUTATION = graphql`
  mutation DeleteReleaseModal_deleteRelease_Mutation($id: ID!) {
    deleteRelease(id: $id) {
      result {
        id
      }
    }
  }
`;

type Release = {
  id: string;
  version: string;
};

type DeleteReleaseModalProps<R extends Release> = {
  releaseToDelete: R;
  onCancel: () => void;
  onConfirm: () => void;
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};
const DeleteReleaseModal = <R extends Release>({
  releaseToDelete,
  onCancel,
  onConfirm,
  setErrorFeedback,
}: DeleteReleaseModalProps<R>) => {
  const [deleteRelease, isDeletingRelease] =
    useMutation<DeleteReleaseModal_deleteRelease_Mutation>(
      DELETE_RELEASE_MUTATION,
    );

  const handleDeleteRelease = useCallback(() => {
    deleteRelease({
      variables: { id: releaseToDelete.id },
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
            id="components.DeleteReleaseModal.deletionErrorFeedback"
            defaultMessage="Could not delete the release, please try again."
          />,
        );
      },
      updater(store, response) {
        const deletedId = response?.deleteRelease?.result?.id;
        if (!deletedId) return;

        store.delete(deletedId);
      },
    });
  }, [releaseToDelete, onConfirm, deleteRelease, setErrorFeedback]);

  return (
    <DeleteModal
      confirmText={releaseToDelete.version || ""}
      onCancel={onCancel}
      onConfirm={handleDeleteRelease}
      isDeleting={isDeletingRelease}
      title={
        <FormattedMessage
          id="components.DeleteReleaseModal.deleteModal.title"
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
  );
};
export default DeleteReleaseModal;
