/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

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

import { useEffect, useMemo, useState } from "react";
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

import Icon from "components/Icon";
import SearchBox from "components/SearchBox";
import TablePagination from "components/TablePagination";

type SortDirectionIndicatorProps = {
  className?: string;
  descending: boolean;
};

const SortDirectionIndicator = ({
  className,
  descending,
}: SortDirectionIndicatorProps) => (
  <span className={className}>
    {descending ? <Icon icon="arrowDown" /> : <Icon icon="arrowUp" />}
  </span>
);

export type TableProps<T extends RowData> = {
  columns: ColumnDef<T, any>[];
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
  className,
  headerStyle,
  hiddenColumns = [],
  sortBy = [],
  maxPageRows = 10,
  searchFunction,
  hideSearch = false,
  getRowProps,
}: TableProps<T>) => {
  const [pagination, setPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize: maxPageRows,
  });
  const [sorting, setSorting] = useState<SortingState>(sortBy);
  const columnVisibility = useMemo(
    () =>
      hiddenColumns.reduce(
        (acc, columnId) => ({ ...acc, [columnId]: false }),
        {},
      ),
    [hiddenColumns],
  );

  useEffect(() => {
    setPagination((prev) => {
      const totalPages = Math.ceil(data.length / maxPageRows);
      return {
        ...prev,
        pageSize: maxPageRows,
        pageIndex:
          totalPages > 0 ? Math.min(prev.pageIndex, totalPages - 1) : 0,
      };
    });
  }, [maxPageRows, data.length]);

  const table = useReactTable<T>({
    data: data as T[], // TODO: remove when react-table narrows data type to readonly array
    columns,
    state: {
      columnVisibility,
      pagination,
      sorting,
    },
    globalFilterFn: searchFunction ?? "auto",
    onPaginationChange: (newPagination) => {
      setPagination((prev) => ({
        ...prev,
        ...newPagination,
      }));
    },
    onSortingChange: setSorting,

    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  });

  return (
    <div className={className}>
      {hideSearch || (
        <div className="py-2 mb-3">
          <SearchBox onChange={table.setGlobalFilter} />
        </div>
      )}
      <RBTable responsive hover>
        <thead>
          {table.getHeaderGroups().map((headerGroup) => (
            <tr key={headerGroup.id}>
              {headerGroup.headers.map((header) => (
                <th
                  style={headerStyle}
                  key={header.id}
                  colSpan={header.colSpan}
                  onClick={header.column.getToggleSortingHandler()}
                >
                  {header.isPlaceholder
                    ? null
                    : flexRender(
                        header.column.columnDef.header,
                        header.getContext(),
                      )}
                  {header.column.getIsSorted() && (
                    <SortDirectionIndicator
                      className="ms-2"
                      descending={header.column.getIsSorted() === "desc"}
                    />
                  )}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row) => (
            <tr {...(getRowProps ? getRowProps(row) : {})} key={row.id}>
              {row.getVisibleCells().map((cell) => (
                <td key={cell.id} style={headerStyle}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </RBTable>
      <TablePagination
        totalPages={table.getPageCount()}
        activePage={pagination.pageIndex}
        onPageChange={(page) =>
          setPagination((prev) => ({
            ...prev,
            pageIndex: page,
          }))
        }
      />
    </div>
  );
};

export default Table;
export { createColumnHelper };
export type { Row };
