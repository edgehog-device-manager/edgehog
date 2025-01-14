/*
  This file is part of Edgehog.

  Copyright 2022-2024 SECO Mind Srl

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

import React, { useCallback } from "react";
import { FormattedMessage } from "react-intl";

import { Modal } from "react-bootstrap";
import type { ModalProps } from "react-bootstrap";

import Button from "components/Button";
import Spinner from "components/Spinner";

type BoostrapVariant =
  | "primary"
  | "secondary"
  | "success"
  | "warning"
  | "danger"
  | "info"
  | "light"
  | "dark"
  | "link";

interface Props {
  cancelLabel?: React.ReactNode;
  children: React.ReactNode;
  confirmLabel: React.ReactNode;
  confirmOnEnter?: boolean;
  confirmVariant?: BoostrapVariant;
  disabled?: boolean;
  isConfirming?: boolean;
  onCancel?: () => void;
  onConfirm: () => void;
  size?: ModalProps["size"];
  title: React.ReactNode;
}

const ConfirmModal = ({
  cancelLabel,
  children,
  confirmLabel,
  confirmOnEnter = true,
  confirmVariant = "primary",
  disabled = false,
  isConfirming = false,
  onCancel,
  onConfirm,
  size = "lg",
  title,
  ...restProps
}: Props): React.ReactElement => {
  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent<HTMLDivElement>) => {
      if (
        event.key === "Enter" &&
        confirmOnEnter &&
        !isConfirming &&
        !disabled
      ) {
        event.preventDefault();
        event.stopPropagation();
        onConfirm();
      }
    },
    [confirmOnEnter, isConfirming, disabled, onConfirm],
  );

  const handleHide = useCallback(() => {
    if (disabled) {
      return;
    }
    if (onCancel) {
      onCancel();
    } else if (!isConfirming) {
      onConfirm();
    }
  }, [onCancel, onConfirm, isConfirming, disabled]);

  return (
    <div onKeyDown={handleKeyDown} {...restProps}>
      <Modal show centered size={size} onHide={handleHide}>
        <Modal.Header closeButton onClick={onCancel}>
          <Modal.Title>{title}</Modal.Title>
        </Modal.Header>
        <Modal.Body>{children}</Modal.Body>
        <Modal.Footer>
          {onCancel && (
            <Button
              variant="secondary"
              onClick={onCancel}
              data-testid="modal-cancel-button"
            >
              {cancelLabel || (
                <FormattedMessage
                  id="components.ConfirmModal.cancelButton"
                  defaultMessage="Cancel"
                  description="Title for the button to cancel and dismiss a confirmation modal"
                />
              )}
            </Button>
          )}
          <Button
            variant={confirmVariant}
            disabled={disabled || isConfirming}
            onClick={onConfirm}
            data-testid="modal-confirm-button"
          >
            {isConfirming && <Spinner className="mr-2" size="sm" />}
            {confirmLabel}
          </Button>
        </Modal.Footer>
      </Modal>
    </div>
  );
};

export default ConfirmModal;
