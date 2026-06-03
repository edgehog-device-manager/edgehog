/*
 * This file is part of Edgehog.
 *
 * Copyright 2021 - 2026 SECO Mind Srl
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
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  getPaginationRowModel,
  useReactTable,
} from "@tanstack/react-table";
import type {
  ColumnDef,
  FilterFnOption,
  PaginationState,
  Row,
  RowData,
  SortingState,
} from "@tanstack/react-table";
import RBTable from "react-bootstrap/Table";
import { FormattedMessage } from "react-intl";

import Icon from "@/components/Icon";
import SearchBox from "@/components/SearchBox";
import TablePagination from "@/components/TablePagination";
import "@/components/Table.scss";

type SortDirectionIndicatorProps = {
  className?: string;
  descending: boolean;
};

const SortDirectionIndicator = ({
  className = "",
  descending,
}: SortDirectionIndicatorProps) => (
  <span className={`${className} sort-direction-indicator`}>
    {descending ? <Icon icon="arrowDown" /> : <Icon icon="arrowUp" />}
  </span>
);

const HIDDEN_COLUMN_IDS: string[] = [];
const SORT_BY_DEFAULT: SortingState = [];

export type TableProps<T extends RowData> = {
  columns: ColumnDef<T, unknown>[];
  data: readonly T[];
  className?: string;
  headerStyle?: React.CSSProperties;
  maxPageRows?: number;
  hiddenColumns?: string[];
  sortBy?: SortingState;
  searchFunction?: FilterFnOption<T>;
  hideSearch?: boolean;
  getRowProps?: (row: Row<T>) => object;
};

const Table = <T extends RowData>({
  columns,
  data,
  className = "",
  headerStyle,
  hiddenColumns = HIDDEN_COLUMN_IDS,
  sortBy = SORT_BY_DEFAULT,
  maxPageRows = 10,
  searchFunction,
  hideSearch = false,
  getRowProps,
}: TableProps<T>) => {
  const [pageIndex, setPageIndex] = useState(0);
  const [sorting, setSorting] = useState<SortingState>(sortBy);

  const pagination = useMemo<PaginationState>(() => {
    const totalPages = Math.ceil(data.length / maxPageRows);
    const safePageIndex =
      totalPages > 0 ? Math.min(pageIndex, totalPages - 1) : 0;

    return {
      pageIndex: safePageIndex,
      pageSize: maxPageRows,
    };
  }, [pageIndex, maxPageRows, data.length]);

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
    data: data as T[], // TODO: remove when react-table narrows data type to readonly array
    columns,
    state: {
      columnVisibility,
      pagination,
      sorting,
    },
    globalFilterFn: searchFunction ?? "auto",
    onPaginationChange: (updater) => {
      const nextPagination =
        typeof updater === "function" ? updater(pagination) : updater;
      setPageIndex(nextPagination.pageIndex);
    },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  });

  const totalRows = table.getFilteredRowModel().rows.length;
  const startRow =
    totalRows === 0 ? 0 : pagination.pageIndex * pagination.pageSize + 1;
  const endRow = Math.min(
    (pagination.pageIndex + 1) * pagination.pageSize,
    totalRows,
  );

  return (
    <div className={`${className}`}>
      {!hideSearch && (
        <div className="mb-4 w-100">
          <SearchBox onChange={table.setGlobalFilter} />
        </div>
      )}

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
                    style={headerStyle}
                    className={`py-3 fw-bold table-header ${isSortable ? "is-sortable" : ""}`}
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

        <tbody>
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
                  id="components.Table.noRecords"
                  defaultMessage="No records to display."
                />
              </td>
            </tr>
          )}
        </tbody>
      </RBTable>

      <div className="d-flex flex-column flex-sm-row justify-content-between align-items-center gap-3 pt-3">
        <div className="text-muted small">
          <FormattedMessage
            id="components.Table.showing"
            defaultMessage="Showing {start} to {end} of {total} entries"
            values={{
              start: <span className="fw-semibold text-dark">{startRow}</span>,
              end: <span className="fw-semibold text-dark">{endRow}</span>,
              total: <span className="fw-semibold text-dark">{totalRows}</span>,
            }}
          />
        </div>

        <TablePagination
          totalPages={table.getPageCount()}
          activePage={pagination.pageIndex}
          onPageChange={setPageIndex}
        />
      </div>
    </div>
  );
};

export type { Row };

export { createColumnHelper, SortDirectionIndicator };

export default Table;
