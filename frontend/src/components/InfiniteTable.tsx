/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { useMemo, useState } from "react";
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

import InfiniteScroll from "components/InfiniteScroll";
import Icon from "./Icon";
import RBTable from "react-bootstrap/Table";
import SearchBox from "./SearchBox";

declare module "@tanstack/table-core" {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface ColumnMeta<TData extends RowData, TValue> {
    className?: string;
  }
}

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

type InfiniteTableProps<T extends RowData> = {
  columns: TableOptions<T>["columns"];
  data: T[];
  className?: string;
  loading?: boolean;
  onLoadMore?: () => void;
  hiddenColumns?: string[];
  sortBy?: SortingState;
  searchFunction?: FilterFnOption<T>;
  hideSearch?: boolean;
  getRowProps?: (row: Row<T>) => object;
  setSearchText?: (value: string | null) => void;
};

const InfiniteTable = <T extends RowData>({
  columns,
  data,
  className = "",
  loading = false,
  onLoadMore,
  hiddenColumns = [],
  sortBy = [],
  searchFunction,
  hideSearch = false,
  getRowProps,
  setSearchText,
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
    <div className={className}>
      {hideSearch || (
        <div className="py-2 mb-3">
          <SearchBox onChange={(text) => setSearchText?.(text)} />
        </div>
      )}
      <InfiniteScroll
        className={className}
        loading={loading}
        onLoadMore={onLoadMore}
      >
        <RBTable responsive hover>
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <th
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
                  <td key={cell.id}>
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </RBTable>
      </InfiniteScroll>
    </div>
  );
};

export default InfiniteTable;
