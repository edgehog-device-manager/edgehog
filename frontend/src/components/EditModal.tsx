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

import React from "react";
import { Modal, ModalProps } from "react-bootstrap";
import { FormattedMessage } from "react-intl";

import Button from "@/components/Button";
import Spinner from "@/components/Spinner";

type EditModalProps = {
  children: React.ReactNode;
  title: React.ReactNode;
  onCancel: () => void;
  onSubmit: (e?: React.BaseSyntheticEvent) => Promise<void> | void;
  isSubmitting: boolean;
  size?: ModalProps["size"];
  submitLabel?: React.ReactNode;
  cancelLabel?: React.ReactNode;
};

const EditModal = ({
  children,
  title,
  onCancel,
  onSubmit,
  isSubmitting,
  size = "lg",
  submitLabel = (
    <FormattedMessage id="components.EditModal.save" defaultMessage="Save" />
  ),
  cancelLabel = (
    <FormattedMessage
      id="components.EditModal.cancel"
      defaultMessage="Cancel"
    />
  ),
}: EditModalProps) => {
  return (
    <Modal show onHide={onCancel} centered backdrop="static" size={size}>
      <form onSubmit={onSubmit}>
        <Modal.Header closeButton>
          <Modal.Title>{title}</Modal.Title>
        </Modal.Header>

        <Modal.Body>{children}</Modal.Body>

        <Modal.Footer>
          <Button
            variant="secondary"
            onClick={onCancel}
            disabled={isSubmitting}
          >
            {cancelLabel}
          </Button>

          <Button
            type="submit"
            variant="primary"
            disabled={isSubmitting}
            data-testid="edit-modal-save-button"
          >
            {isSubmitting && <Spinner size="sm" className="me-2" />}
            {isSubmitting ? (
              <FormattedMessage
                id="components.EditModal.saving"
                defaultMessage="Saving..."
              />
            ) : (
              submitLabel
            )}
          </Button>
        </Modal.Footer>
      </form>
    </Modal>
  );
};

export default EditModal;
