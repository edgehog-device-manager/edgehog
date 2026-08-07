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

import { Dropdown, Form } from "react-bootstrap";
import type { Column, RowData } from "@tanstack/react-table";
import Icon from "@/components/ui/icon/Icon";

type ColumnVisibilityDropdownProps<TData extends RowData> = {
  columns: Column<TData, unknown>[];
  className?: string;
};

const formatColumnId = (id: string): string =>
  id
    .split(".")
    .map((part) =>
      part
        .replace(/[-_]/g, " ")
        .replace(/([a-z])([A-Z])/g, "$1 $2")
        .replace(/^./, (s) => s.toUpperCase()),
    )
    .join(" ");

const ColumnVisibilityDropdown = <TData extends RowData>({
  columns,
  className = "",
}: ColumnVisibilityDropdownProps<TData>) => {
  const hidableColumns = columns.filter((column) => column.getCanHide());

  if (hidableColumns.length === 0) {
    return null;
  }

  return (
    <div className={`ms-auto d-flex ${className}`}>
      <Dropdown align="end">
        <Dropdown.Toggle
          variant="transparent"
          className="h-100"
          style={{
            borderColor: "var(--bs-border-color)",
          }}
        >
          <Icon icon="columnVisibility" />
        </Dropdown.Toggle>

        <Dropdown.Menu>
          {hidableColumns.map((column) => (
            <Dropdown.Item
              key={column.id}
              as="div"
              className="px-3 py-1"
              onClick={(e) => e.stopPropagation()}
            >
              <Form.Check
                type="checkbox"
                id={`column-vis-${column.id}`}
                label={
                  column.columnDef.meta?.label ?? formatColumnId(column.id)
                }
                checked={column.getIsVisible()}
                onChange={column.getToggleVisibilityHandler()}
              />
            </Dropdown.Item>
          ))}
        </Dropdown.Menu>
      </Dropdown>
    </div>
  );
};

export default ColumnVisibilityDropdown;
