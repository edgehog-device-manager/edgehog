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

import { useState, Fragment } from "react";
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

import ColumnVisibilityDropdown from "@/components/ui/column-visibility-dropdown/ColumnVisibilityDropdown";
import Icon from "@/components/ui/icon/Icon";
import InfiniteScroll from "@/components/ui/infinite-scroll/InfiniteScroll";
import SearchBox from "@/components/ui/search-box/SearchBox";
import { SortDirectionIndicator } from "@/components/ui/table/Table";
import "@/components/ui/table/Table.scss";
import useColumnVisibility from "@/hooks/useColumnVisibility";

declare module "@tanstack/table-core" {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface ColumnMeta<TData extends RowData, TValue> {
    className?: string;
    label?: string;
    getLink?: (row: Row<TData>, children: React.ReactNode) => React.ReactNode;
    isPrimaryLink?: boolean;
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
  onSearchChange?: (text: string) => void;
  searchText?: string;
  searchBox?: React.ReactNode;
  hideSearch?: boolean;
  hideColumnVisibility?: boolean;
  getRowProps?: (row: Row<T>) => object;
  columnVisibilityKey?: string;
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
  onSearchChange,
  searchText,
  searchBox,
  hideSearch = false,
  hideColumnVisibility = false,
  getRowProps,
  columnVisibilityKey,
}: InfiniteTableProps<T>) => {
  const [sorting, setSorting] = useState<SortingState>(sortBy);

  const { columnVisibility, setColumnVisibility } = useColumnVisibility(
    columnVisibilityKey,
    hiddenColumns,
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
    onColumnVisibilityChange: setColumnVisibility,
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  const leafColumns = table.getAllLeafColumns();

  const primaryLinkColumn = leafColumns.find(
    (column) => column.columnDef.meta?.isPrimaryLink,
  );

  const showPrimaryLinkAtEnd =
    primaryLinkColumn != null && !primaryLinkColumn.getIsVisible();

  const showColumnVisibilityDropdown =
    !hideColumnVisibility && leafColumns.some((column) => column.getCanHide());
  const getSearchElement = () => {
    if (hideSearch) return null;
    if (searchBox !== undefined) return searchBox;
    if (onSearchChange != null || searchText != null) {
      return <SearchBox value={searchText ?? ""} onChange={onSearchChange} />;
    }
    if (searchFunction != null) {
      return <SearchBox onChange={table.setGlobalFilter} />;
    }
    return null;
  };

  const searchElement = getSearchElement();

  const renderRowLink = (
    column: (typeof leafColumns)[number] | undefined,
    row: Row<T>,
  ) => {
    const getLink = column?.columnDef.meta?.getLink;

    if (!getLink) return null;

    return (
      <span className="row-link-icon">
        {getLink(row, <Icon icon="arrowUpRightFromSquare" />)}
      </span>
    );
  };

  return (
    <div className={`${className}`}>
      {(searchElement !== null || showColumnVisibilityDropdown) && (
        <div className="d-flex mb-4 gap-3">
          {searchElement !== null && (
            <div className="flex-grow-1">{searchElement}</div>
          )}

          {showColumnVisibilityDropdown && (
            <ColumnVisibilityDropdown columns={leafColumns} />
          )}
        </div>
      )}

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
                {showPrimaryLinkAtEnd && <th className="row-link-header" />}
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
                        <div className="d-flex align-items-center">
                          {flexRender(
                            cell.column.columnDef.cell,
                            cell.getContext(),
                          )}
                          {renderRowLink(cell.column, row)}
                        </div>
                      </td>
                    ))}
                    {showPrimaryLinkAtEnd && (
                      <td className="table-cell row-link-cell align-middle">
                        <div className="d-flex align-items-center justify-content-center">
                          {renderRowLink(primaryLinkColumn, row)}
                        </div>
                      </td>
                    )}
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
                    id="components.ui.infinite-table.InfiniteTable.noRecords"
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
