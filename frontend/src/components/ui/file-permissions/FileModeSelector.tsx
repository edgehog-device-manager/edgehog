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

import React, { useState } from "react";
import { FormattedMessage } from "react-intl";
import Form from "react-bootstrap/Form";
import Button from "react-bootstrap/Button";
import Table from "react-bootstrap/Table";
import Badge from "react-bootstrap/Badge";

import {
  FilePermissionsMatrix,
  PERMISSION_PRESETS,
  PermissionAction,
  PermissionTarget,
  matrixToMode,
  modeToMatrix,
  modeToOctal,
  modeToSymbolic,
  octalToMode,
} from "@/lib/permissions";

export type FileModeSelectorProps = {
  value?: number | null;
  onChange: (value: number | undefined) => void;
  disabled?: boolean;
  id?: string;
  idPrefix?: string;
  className?: string;
  showPresets?: boolean;
};

const FileModeSelector: React.FC<FileModeSelectorProps> = ({
  value,
  onChange,
  disabled = false,
  id,
  idPrefix,
  className,
  showPresets = true,
}) => {
  const elementIdPrefix = idPrefix ?? id ?? "file-mode";
  const [prevValue, setPrevValue] = useState(value);
  const [octalInput, setOctalInput] = useState<string>(
    value !== undefined && value !== null ? modeToOctal(value) : "",
  );
  const [isOctalInvalid, setIsOctalInvalid] = useState(false);

  if (value !== prevValue) {
    setPrevValue(value);
    setOctalInput(
      value !== undefined && value !== null ? modeToOctal(value) : "",
    );
    setIsOctalInvalid(false);
  }

  const matrix = modeToMatrix(value);

  const handleCheckboxChange = (
    target: PermissionTarget,
    action: PermissionAction,
    checked: boolean,
  ) => {
    const updated: FilePermissionsMatrix = {
      ...matrix,
      [target]: {
        ...matrix[target],
        [action]: checked,
      },
    };
    const newMode = matrixToMode(updated);
    onChange(newMode);
  };

  const handleOctalInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const text = e.target.value;
    setOctalInput(text);

    if (text.trim() === "") {
      setIsOctalInvalid(false);
      onChange(undefined);
      return;
    }

    const parsed = octalToMode(text);
    if (parsed !== null) {
      setIsOctalInvalid(false);
      onChange(parsed);
    } else {
      setIsOctalInvalid(true);
    }
  };

  const handlePresetClick = (presetMode: number) => {
    onChange(presetMode);
  };

  const handleClear = () => {
    setOctalInput("");
    setIsOctalInvalid(false);
    onChange(undefined);
  };

  const targets: { key: PermissionTarget; label: React.ReactNode }[] = [
    {
      key: "user",
      label: (
        <FormattedMessage
          id="components.ui.file-permissions.FileModeSelector.userTarget"
          defaultMessage="User (Owner)"
        />
      ),
    },
    {
      key: "group",
      label: (
        <FormattedMessage
          id="components.ui.file-permissions.FileModeSelector.groupTarget"
          defaultMessage="Group"
        />
      ),
    },
    {
      key: "others",
      label: (
        <FormattedMessage
          id="components.ui.file-permissions.FileModeSelector.othersTarget"
          defaultMessage="Others (Global)"
        />
      ),
    },
  ];

  const actions: {
    key: PermissionAction;
    label: React.ReactNode;
    symbol: string;
  }[] = [
    {
      key: "read",
      label: (
        <FormattedMessage
          id="components.ui.file-permissions.FileModeSelector.readAction"
          defaultMessage="Read (r)"
        />
      ),
      symbol: "r",
    },
    {
      key: "write",
      label: (
        <FormattedMessage
          id="components.ui.file-permissions.FileModeSelector.writeAction"
          defaultMessage="Write (w)"
        />
      ),
      symbol: "w",
    },
    {
      key: "execute",
      label: (
        <FormattedMessage
          id="components.ui.file-permissions.FileModeSelector.executeAction"
          defaultMessage="Execute (x)"
        />
      ),
      symbol: "x",
    },
  ];

  const symbolic =
    value !== undefined && value !== null ? modeToSymbolic(value) : "---------";

  return (
    <div className={`file-mode-selector ${className ?? ""}`} id={id}>
      {showPresets && (
        <div className="mb-2 d-flex flex-wrap align-items-center gap-1">
          <span className="text-muted small me-1">
            <FormattedMessage
              id="components.ui.file-permissions.FileModeSelector.presets"
              defaultMessage="Presets:"
            />
          </span>
          {PERMISSION_PRESETS.map((p) => {
            const isSelected = value === p.mode;
            return (
              <Button
                key={p.octal}
                size="sm"
                variant={isSelected ? "primary" : "outline-secondary"}
                disabled={disabled}
                onClick={() => handlePresetClick(p.mode)}
                className="py-0 px-2"
                style={{ fontSize: "0.8rem" }}
              >
                {p.label}
              </Button>
            );
          })}
          {value !== undefined && value !== null && (
            <Button
              size="sm"
              variant="link"
              disabled={disabled}
              onClick={handleClear}
              className="text-decoration-none py-0 px-2 text-danger"
              style={{ fontSize: "0.8rem" }}
            >
              <FormattedMessage
                id="components.ui.file-permissions.FileModeSelector.clear"
                defaultMessage="Clear"
              />
            </Button>
          )}
        </div>
      )}

      <div className="d-flex flex-wrap align-items-start gap-3">
        <div style={{ maxWidth: 440, width: "100%", flex: "0 1 440px" }}>
          <Table bordered size="sm" className="mb-0 text-center align-middle">
            <thead className="table-light">
              <tr>
                <th className="text-start" style={{ width: "35%" }}>
                  <FormattedMessage
                    id="components.ui.file-permissions.FileModeSelector.scope"
                    defaultMessage="Scope"
                  />
                </th>
                {actions.map((act) => (
                  <th key={act.key} style={{ width: "21%" }}>
                    {act.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {targets.map((tgt) => (
                <tr key={tgt.key}>
                  <td className="text-start fw-medium">{tgt.label}</td>
                  {actions.map((act) => {
                    const isChecked = matrix[tgt.key][act.key];
                    return (
                      <td key={act.key}>
                        <Form.Check
                          type="checkbox"
                          id={`${elementIdPrefix}-${tgt.key}-${act.key}`}
                          aria-label={`${tgt.key} ${act.key}`}
                          checked={isChecked}
                          disabled={disabled}
                          onChange={(e) =>
                            handleCheckboxChange(
                              tgt.key,
                              act.key,
                              e.target.checked,
                            )
                          }
                          className="d-flex justify-content-center m-0"
                        />
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </Table>
        </div>

        <div className="d-flex flex-column gap-2" style={{ minWidth: 140 }}>
          <Form.Group controlId={`${elementIdPrefix}-octal-input`}>
            <Form.Label className="small text-muted mb-0">
              <FormattedMessage
                id="components.ui.file-permissions.FileModeSelector.octalNotation"
                defaultMessage="Octal Notation"
              />
            </Form.Label>
            <Form.Control
              type="text"
              size="sm"
              placeholder="e.g. 0755"
              value={octalInput}
              disabled={disabled}
              isInvalid={isOctalInvalid}
              onChange={handleOctalInputChange}
              className="font-monospace"
            />
            {isOctalInvalid && (
              <Form.Control.Feedback type="invalid" className="small">
                <FormattedMessage
                  id="components.ui.file-permissions.FileModeSelector.invalidOctal"
                  defaultMessage="Valid: 000-777"
                />
              </Form.Control.Feedback>
            )}
          </Form.Group>

          <div>
            <div className="small text-muted">
              <FormattedMessage
                id="components.ui.file-permissions.FileModeSelector.symbolic"
                defaultMessage="Symbolic"
              />
            </div>
            <Badge
              bg="light"
              text="dark"
              className="font-monospace border px-2 py-1"
            >
              {symbolic}
            </Badge>
          </div>
        </div>
      </div>
    </div>
  );
};

export default FileModeSelector;
