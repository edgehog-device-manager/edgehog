/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2026 SECO Mind Srl
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

import { it, expect } from "vitest";
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";

import { renderWithProviders } from "@/setupTests";
import Table from "./Table";
import type { Row } from "./Table";

type Data = { id: string; name: string };

const data: Data[] = Array.from({ length: 100 }, (_, index) => ({
  id: `${index}`,
  name: `Name ${index}`,
}));

const columns = [
  { header: "ID", accessorKey: "id" },
  { header: "Name", accessorKey: "name" },
];

type TableProps = ComponentProps<typeof Table<Data>>;

const renderTable = (
  props: TableProps,
): [thead: HTMLElement, tbody: HTMLElement] => {
  renderWithProviders(<Table {...props} />);

  const table = screen.getByRole("table");
  expect(table).toBeVisible();

  const tableElements = screen.getAllByRole("rowgroup");
  expect(tableElements).toHaveLength(2);

  const [thead, tbody] = tableElements;
  return [thead, tbody];
};

it("correctly renders empty list", () => {
  const [thead, tbody] = renderTable({ data: [], columns });

  expect(within(thead).getByRole("row")).toBeVisible();
  expect(within(thead).getAllByRole("columnheader")).toHaveLength(
    columns.length,
  );
  expect(within(tbody).queryByRole("row")).not.toBeInTheDocument();
});

it.each(columns)("correctly hides $header column", (hiddenColumn) => {
  renderTable({ data, columns, hiddenColumns: [hiddenColumn.accessorKey] });

  expect(
    screen.queryByRole("columnheader", { name: hiddenColumn.header }),
  ).not.toBeInTheDocument();
  columns.forEach((column) => {
    if (column !== hiddenColumn) {
      expect(
        screen.getByRole("columnheader", { name: column.header }),
      ).toBeVisible();
    }
  });
});

it("correctly renders list of data", () => {
  const rowsCount = 2;
  const [, tbody] = renderTable({ data: data.slice(0, rowsCount), columns });

  const dataRows = within(tbody).getAllByRole("row");
  expect(dataRows).toHaveLength(rowsCount);
  for (let i = 0; i < rowsCount; i++) {
    expect(within(dataRows[i]).getByText(i)).toBeVisible();
    expect(within(dataRows[i]).getByText(`Name ${i}`)).toBeVisible();
  }
});

it("can search data", async () => {
  const [, tbody] = renderTable({ data, columns });

  await userEvent.type(screen.getByPlaceholderText("Search"), "Name 42");
  const dataRow = within(tbody).getByRole("row");
  expect(dataRow).toBeVisible();
  expect(dataRow).toHaveTextContent("Name 42");
});

it("correctly paginates a long list", async () => {
  const [, tbody] = renderTable({ data, columns });

  const firstPageDataRows = within(tbody).getAllByRole("row");
  expect(firstPageDataRows).toHaveLength(10);
  expect(firstPageDataRows[0]).toHaveTextContent("Name 0");

  expect(screen.getByTestId("pagination-item-0")).toBeVisible();
  expect(screen.getByTestId("pagination-item-4")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-5")).not.toBeInTheDocument();
  expect(screen.getByTestId("pagination-last")).toBeVisible();

  await userEvent.click(screen.getByTestId("pagination-last"));

  expect(screen.queryByTestId("pagination-item-4")).not.toBeInTheDocument();
  expect(screen.getByTestId("pagination-item-5")).toBeVisible();
  expect(screen.getByTestId("pagination-item-9")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-10")).not.toBeInTheDocument();
  expect(screen.getByTestId("pagination-first")).toBeVisible();

  const lastPageDataRows = within(tbody).getAllByRole("row");
  const lastDataRow = lastPageDataRows[lastPageDataRows.length - 1];
  expect(lastDataRow).toHaveTextContent("Name 99");
});

it("correctly passes props with getRowProps", () => {
  const getRowProps = (row: Row<Data>) => ({
    className: `custom-class-${row.original.id}`,
  });
  const [, tbody] = renderTable({
    data: data.slice(0, 2),
    columns,
    getRowProps,
  });

  const dataRows = within(tbody).getAllByRole("row");
  dataRows.forEach((row, index) => {
    expect(row).toHaveClass(`custom-class-${index}`);
  });
});
