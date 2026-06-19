/*
  This file is part of Edgehog.

  Copyright 2026 SECO Mind Srl

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

import { useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useMutation } from "react-relay";

import type { DeleteCampaignModal_deleteCampaign_Mutation } from "@/api/__generated__/DeleteCampaignModal_deleteCampaign_Mutation.graphql";

import DeleteModal from "@/components/DeleteModal";

const DELETE_CAMPAIGN_MUTATION = graphql`
  mutation DeleteCampaignModal_deleteCampaign_Mutation($id: ID!) {
    deleteCampaign(id: $id) {
      result {
        id
      }
    }
  }
`;

type Campaign = {
  id: string;
  name: string;
};

type DeleteCampaignModalProps<C extends Campaign> = {
  campaignToDelete: C;
  onCancel: () => void;
  onSuccess: () => void;
  setErrorFeedback: (msg: React.ReactNode) => void;
};

const DeleteCampaignModal = <C extends Campaign>({
  campaignToDelete,
  onCancel,
  onSuccess,
  setErrorFeedback,
}: DeleteCampaignModalProps<C>) => {
  const [deleteCampaign, isDeleting] =
    useMutation<DeleteCampaignModal_deleteCampaign_Mutation>(
      DELETE_CAMPAIGN_MUTATION,
    );

  const handleDelete = useCallback(() => {
    deleteCampaign({
      variables: { id: campaignToDelete.id },
      onCompleted(_data, errors) {
        if (errors?.length) {
          setErrorFeedback(errors.map((e) => e.message).join("\n"));
          return;
        }

        setErrorFeedback(null);
        onSuccess();
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeleteCampaignModal.error"
            defaultMessage="Could not delete campaign."
          />,
        );
      },
    });
  }, [campaignToDelete, deleteCampaign, onSuccess, setErrorFeedback]);

  return (
    <DeleteModal
      confirmText={campaignToDelete.name || ""}
      title={
        <FormattedMessage
          id="components.DeleteCampaignModal.title"
          defaultMessage="Delete Campaign"
        />
      }
      onCancel={onCancel}
      onConfirm={handleDelete}
      isDeleting={isDeleting}
    >
      <p>
        <FormattedMessage
          id="components.DeleteCampaignModal.warning"
          defaultMessage="This will permanently delete the campaign."
        />
      </p>
    </DeleteModal>
  );
};

export default DeleteCampaignModal;
