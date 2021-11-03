import { useEffect } from "react";
import {
  useTable,
  useGlobalFilter,
  usePagination,
  useSortBy,
} from "react-table";
import type {
  Column as ReactTableColumn,
  Row,
  HeaderGroup,
  HeaderPropGetter,
  TableInstance,
} from "react-table";
import RBTable from "react-bootstrap/Table";
import _ from "lodash";

import Icon from "components/Icon";
import SearchBox from "components/SearchBox";
import TablePagination from "components/TablePagination";

// Required workaround for missing TypesScript definitions.
// Will be fixed in react-table v8
// see also https://github.com/tannerlinsley/react-table/issues/3064
type TableTypeWorkaround<T extends Object> = TableInstance<T> & {
  page: Row<T>[];
  pageOptions: number[];
  gotoPage: (index: number) => void;
  setPageSize: (index: number) => void;
  state: {
    pageIndex: number;
    pageSize: number;
  };
  setGlobalFilter: (filterValue: any) => void;
};

type HeaderTypeWorkaround<T extends Object> = HeaderGroup<T> & {
  getSortByToggleProps: () => HeaderPropGetter<T>;
  isSorted: boolean;
  isSortedDesc: boolean;
};

type Column<T extends Object> = ReactTableColumn<T> & {
  disableSortBy?: boolean;
  sortType?: "alphanumeric" | "basic" | "datetime" | "number" | "string";
};

function defaultSearchFunction<T extends Object>(
  rows: Row<T>[],
  columnIds: string[],
  globalFilterValue: string
) {
  return rows.filter((row) => {
    if (globalFilterValue) {
      return _.values(row).some(
        (value) => _.isString(value) && value.includes(globalFilterValue)
      );
    } else {
      return rows;
    }
  });
}

// Let the table remove the filter if the string is empty
defaultSearchFunction.autoRemove = (value: string) => !value;

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

type TableProps<T extends Object> = {
  columns: Column<T>[];
  data: T[];
  className?: string;
  maxPageRows?: number;
  hiddenColumns?: string[];
  searchFunction?: (
    rows: Row<T>[],
    columnIds: string[],
    globalFilterValue: any
  ) => Row<T>[];
};

const Table = <T extends Object>({
  columns,
  data,
  className,
  hiddenColumns = [],
  maxPageRows = 10,
  searchFunction,
}: TableProps<T>) => {
  const tableParams = {
    columns,
    data,
    initialState: {
      hiddenColumns,
    },
    filterTypes: {
      text: searchFunction ? searchFunction : defaultSearchFunction,
    },
  };

  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    prepareRow,

    // pagination
    page,
    pageOptions,
    gotoPage,
    setPageSize,
    state: { pageIndex, pageSize },

    // filter
    setGlobalFilter,
  } = useTable(
    tableParams,
    useGlobalFilter,
    useSortBy,
    usePagination
  ) as TableTypeWorkaround<T>;

  useEffect(() => {
    if (pageSize !== maxPageRows) {
      setPageSize(maxPageRows);
    }
  }, [pageSize, maxPageRows, setPageSize]);

  return (
    <div className={className}>
      <div className="py-2 mb-3">
        <SearchBox onChange={setGlobalFilter} />
      </div>
      <RBTable {...getTableProps()} responsive hover>
        <thead>
          {headerGroups.map((headerGroup) => (
            <tr {...headerGroup.getHeaderGroupProps()}>
              {headerGroup.headers.map((column) => {
                const col = column as HeaderTypeWorkaround<T>;
                return (
                  <th {...col.getHeaderProps(col.getSortByToggleProps())}>
                    {col.render("Header")}
                    {col.isSorted && (
                      <SortDirectionIndicator
                        className="ms-2"
                        descending={col.isSortedDesc}
                      />
                    )}
                  </th>
                );
              })}
            </tr>
          ))}
        </thead>
        <tbody {...getTableBodyProps()}>
          {page.map((row) => {
            prepareRow(row);

            return (
              <tr {...row.getRowProps()}>
                {row.cells.map((cell) => {
                  return (
                    <td {...cell.getCellProps()}>{cell.render("Cell")}</td>
                  );
                })}
              </tr>
            );
          })}
        </tbody>
      </RBTable>
      <TablePagination
        totalPages={pageOptions.length}
        activePage={pageIndex}
        onPageChange={gotoPage}
      />
    </div>
  );
};

export default Table;
export type { Column };
