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

import React from "react";
import { FormattedMessage } from "react-intl";
import Form from "react-bootstrap/Form";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/Col";

import FileModeSelector from "./FileModeSelector";

export type FilePermissionsInputProps = {
  fileMode?: number | null;
  userId?: number | null;
  groupId?: number | null;
  onFileModeChange: (mode: number | undefined) => void;
  onUserIdChange: (userId: number | undefined) => void;
  onGroupIdChange: (groupId: number | undefined) => void;
  disabled?: boolean;
  idPrefix?: string;
  className?: string;
};

const FilePermissionsInput: React.FC<FilePermissionsInputProps> = ({
  fileMode,
  userId,
  groupId,
  onFileModeChange,
  onUserIdChange,
  onGroupIdChange,
  disabled = false,
  idPrefix = "file-perm",
  className,
}) => {
  return (
    <div className={`file-permissions-input ${className ?? ""}`}>
      <div className="mb-3">
        <Form.Label className="fw-semibold">
          <FormattedMessage
            id="components.ui.file-permissions.FilePermissionsInput.fileMode"
            defaultMessage="File Mode (Permissions)"
          />
        </Form.Label>
        <FileModeSelector
          id={`${idPrefix}-mode`}
          value={fileMode}
          onChange={onFileModeChange}
          disabled={disabled}
        />
      </div>

      <Row className="g-3">
        <Col xs={12} sm={6}>
          <Form.Group controlId={`${idPrefix}-userId`}>
            <Form.Label className="small text-muted mb-1">
              <FormattedMessage
                id="components.ui.file-permissions.FilePermissionsInput.userId"
                defaultMessage="Owner User ID (UID)"
              />
            </Form.Label>
            <Form.Control
              type="number"
              size="sm"
              placeholder="e.g. 0 (root), 1000"
              value={userId !== undefined && userId !== null ? userId : ""}
              disabled={disabled}
              onChange={(e) => {
                const val = e.target.value.trim();
                onUserIdChange(val === "" ? undefined : parseInt(val, 10));
              }}
            />
            <Form.Text className="text-muted small">
              <FormattedMessage
                id="components.ui.file-permissions.FilePermissionsInput.userIdHelp"
                defaultMessage="Leave empty for device runtime default"
              />
            </Form.Text>
          </Form.Group>
        </Col>

        <Col xs={12} sm={6}>
          <Form.Group controlId={`${idPrefix}-groupId`}>
            <Form.Label className="small text-muted mb-1">
              <FormattedMessage
                id="components.ui.file-permissions.FilePermissionsInput.groupId"
                defaultMessage="Group ID (GID)"
              />
            </Form.Label>
            <Form.Control
              type="number"
              size="sm"
              placeholder="e.g. 0 (root), 1000"
              value={groupId !== undefined && groupId !== null ? groupId : ""}
              disabled={disabled}
              onChange={(e) => {
                const val = e.target.value.trim();
                onGroupIdChange(val === "" ? undefined : parseInt(val, 10));
              }}
            />
            <Form.Text className="text-muted small">
              <FormattedMessage
                id="components.ui.file-permissions.FilePermissionsInput.groupIdHelp"
                defaultMessage="Leave empty for device runtime default"
              />
            </Form.Text>
          </Form.Group>
        </Col>
      </Row>
    </div>
  );
};

export default FilePermissionsInput;
