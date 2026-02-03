/*
 * This file is part of Edgehog.
 *
 * Copyright 2022-2026 SECO Mind Srl
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

import React, { useCallback, useState } from "react";
import { FormattedMessage } from "react-intl";

import ConfirmModal from "@/components/ConfirmModal";
import Form from "@/components/Form";

interface DeleteModalProps {
  children?: React.ReactNode;
  confirmText: string;
  isDeleting?: boolean;
  onCancel: () => void;
  onConfirm: () => void;
  title: React.ReactNode;
}

const DeleteModal = ({
  children,
  confirmText,
  isDeleting,
  onCancel,
  onConfirm,
  title,
  ...restProps
}: DeleteModalProps) => {
  const [confirmString, setConfirmString] = useState("");

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) =>
      setConfirmString(e.target.value),
    [],
  );

  const canDelete = confirmString === confirmText;

  return (
    <ConfirmModal
      title={title}
      confirmLabel={
        <FormattedMessage
          id="components.DeleteModal.confirmButton"
          defaultMessage="Delete"
          description="Title for the button to confirm a deletion modal"
        />
      }
      confirmVariant="danger"
      onCancel={onCancel}
      onConfirm={onConfirm}
      isConfirming={isDeleting}
      disabled={!canDelete}
      {...restProps}
    >
      {children}
      <p>
        <FormattedMessage
          id="components.DeleteModal.confirmPrompt"
          defaultMessage="Please type <bold>{confirmText}</bold> to confirm."
          description="Description of the action to perform to confirm the deletion modal"
          values={{
            confirmText,
            bold: (chunks: React.ReactNode) => <strong>{chunks}</strong>,
          }}
        />
      </p>
      <Form.Group controlId="confirmResourceName">
        <Form.Control
          type="text"
          value={confirmString}
          placeholder={confirmText}
          onChange={handleInputChange}
        />
      </Form.Group>
    </ConfirmModal>
  );
};

export default DeleteModal;
