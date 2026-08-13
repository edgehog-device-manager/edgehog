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
import { Modal } from "react-bootstrap";
import { flexRender } from "@tanstack/react-table";
import type { Column, Row, RowData } from "@tanstack/react-table";
import { FormattedMessage } from "react-intl";

import Button from "@/components/ui/button/Button";

type DetailsModalProps<T extends RowData> = {
  row: Row<T>;
  columns: Column<T, unknown>[];
  onClose: () => void;
};

const getColumnLabel = <T extends RowData>(
  column: Column<T, unknown>,
): string => {
  if (column.columnDef.meta?.label) {
    return column.columnDef.meta.label;
  }

  if (typeof column.columnDef.header === "string") {
    return column.columnDef.header;
  }

  return (
    column.id
      .split(".")
      .pop()
      ?.replace(/([A-Z])/g, " $1")
      .replace(/^./, (char) => char.toUpperCase())
      .trim() ?? column.id
  );
};

const DetailsModal = <T extends RowData>({
  row,
  columns,
  onClose,
}: DetailsModalProps<T>) => {
  const cells = new Map(
    row.getAllCells().map((cell) => [cell.column.id, cell]),
  );

  const displayColumns = columns.filter(
    (column) => column.id !== "details" && column.id !== "actions",
  );

  return (
    <Modal show onHide={onClose} centered size="lg">
      <Modal.Header closeButton>
        <Modal.Title>
          <FormattedMessage
            id="components.ui.details-modal.DetailsModal.title"
            defaultMessage="Details"
          />
        </Modal.Title>
      </Modal.Header>

      <Modal.Body>
        <dl className="row mb-0">
          {displayColumns.map((column) => {
            const cell = cells.get(column.id);

            if (!cell) {
              return null;
            }

            const view = flexRender(
              cell.column.columnDef.cell,
              cell.getContext(),
            );

            return (
              <div key={column.id} className="col-12 col-sm-6 mb-3">
                <dt className="text-muted small fw-bold text-uppercase mb-1">
                  {getColumnLabel(column)}
                </dt>

                <dd className="mb-0">
                  {view !== null && view !== undefined && view !== ""
                    ? view
                    : "—"}
                </dd>
              </div>
            );
          })}
        </dl>
      </Modal.Body>

      <Modal.Footer>
        <Button variant="secondary" onClick={onClose}>
          <FormattedMessage
            id="components.ui.details-modal.DetailsModal.close"
            defaultMessage="Close"
          />
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default DetailsModal;
