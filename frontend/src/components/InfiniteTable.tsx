/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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

import { useMemo, useState, Fragment } from "react";
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
} from "@tanstack/react-table";
import type {
  FilterFnOption,
  Row,
  RowData,
  SortingState,
  TableOptions,
} from "@tanstack/react-table";
import { FormattedMessage } from "react-intl";
import RBTable from "react-bootstrap/Table";

import InfiniteScroll from "@/components/InfiniteScroll";
import { SortDirectionIndicator } from "@/components/Table";
import "@/components/Table.scss";

declare module "@tanstack/table-core" {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface ColumnMeta<TData extends RowData, TValue> {
    className?: string;
  }
}

const HIDDEN_COLUMN_IDS: string[] = [];
const SORT_BY_DEFAULT: SortingState = [];

type InfiniteTableProps<T extends RowData> = {
  columns: TableOptions<T>["columns"];
  data: T[];
  className?: string;
  loading?: boolean;
  onLoadMore?: () => void;
  hiddenColumns?: string[];
  sortBy?: SortingState;
  searchFunction?: FilterFnOption<T>;
  getRowProps?: (row: Row<T>) => object;
};

const InfiniteTable = <T extends RowData>({
  columns,
  data,
  className = "",
  loading = false,
  onLoadMore,
  hiddenColumns = HIDDEN_COLUMN_IDS,
  sortBy = SORT_BY_DEFAULT,
  searchFunction,
  getRowProps,
}: InfiniteTableProps<T>) => {
  const [sorting, setSorting] = useState<SortingState>(sortBy);
  const columnVisibility = useMemo(
    () =>
      hiddenColumns.reduce(
        (acc, columnId) => ({ ...acc, [columnId]: false }),
        {},
      ),
    [hiddenColumns],
  );

  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable<T>({
    data: data, // TODO: remove when react-table narrows data type to readonly array
    columns,
    state: {
      columnVisibility,
      sorting,
    },
    globalFilterFn: searchFunction ?? "auto",
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  return (
    <div className={`${className}`}>
      <InfiniteScroll loading={loading} onLoadMore={onLoadMore}>
        <RBTable responsive hover className="mb-0">
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr
                key={headerGroup.id}
                className="border-bottom border-light-subtle"
              >
                {headerGroup.headers.map((header) => {
                  const isSortable = header.column.getCanSort();
                  const isSorted = header.column.getIsSorted();

                  return (
                    <th
                      key={header.id}
                      colSpan={header.colSpan}
                      className={`py-3 fw-bold table-header ${isSortable ? "is-sortable " : ""}`}
                      onClick={header.column.getToggleSortingHandler()}
                    >
                      <div className="d-flex align-items-center text-nowrap">
                        <span>
                          {header.isPlaceholder
                            ? null
                            : flexRender(
                                header.column.columnDef.header,
                                header.getContext(),
                              )}
                        </span>
                        {isSorted && (
                          <SortDirectionIndicator
                            className="ms-2"
                            descending={isSorted === "desc"}
                          />
                        )}
                      </div>
                    </th>
                  );
                })}
              </tr>
            ))}
          </thead>
          <tbody className="border-bottom border-light-subtle">
            {table.getRowModel().rows.length > 0 ? (
              table.getRowModel().rows.map((row) => (
                <Fragment key={row.id}>
                  <tr {...(getRowProps ? getRowProps(row) : {})}>
                    {row.getVisibleCells().map((cell) => (
                      <td key={cell.id} className="table-cell">
                        {flexRender(
                          cell.column.columnDef.cell,
                          cell.getContext(),
                        )}
                      </td>
                    ))}
                  </tr>
                </Fragment>
              ))
            ) : (
              <tr>
                <td
                  colSpan={table.getVisibleFlatColumns().length}
                  className="text-center py-4 text-muted small"
                >
                  <FormattedMessage
                    id="components.InfiniteTable.noRecords"
                    defaultMessage="No records to display."
                  />
                </td>
              </tr>
            )}
          </tbody>
        </RBTable>
      </InfiniteScroll>
    </div>
  );
};

export default InfiniteTable;
