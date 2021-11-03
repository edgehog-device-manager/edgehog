import React from "react";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import _ from "lodash";

import { renderWithProviders } from "setupTests";
import Table, { Column } from "./Table";

type Data = { id: string; name: string };

const data: Data[] = _.range(100).map((index) => ({
  id: `${index}`,
  name: `Name ${index}`,
}));

const columns: Column<Data>[] = [
  {
    accessor: "id",
    Header: "ID",
  },
  {
    accessor: "name",
    Header: "Name",
  },
];

it("correctly renders empty list", () => {
  const { container } = renderWithProviders(<Table data={[]} columns={[]} />);
  expect(container.querySelectorAll("thead th")).toHaveLength(0);
  expect(container.querySelectorAll("tbody tr")).toHaveLength(0);
});

it("correctly hides columns", () => {
  const { container } = renderWithProviders(
    <Table data={data} columns={columns} hiddenColumns={["id"]} />
  );
  expect(container.querySelectorAll("thead th")).toHaveLength(
    columns.length - 1
  );
  expect(container.querySelector("thead")).not.toHaveTextContent("ID");
});

it("correctly renders list of data", () => {
  const { container } = renderWithProviders(
    <Table data={data.slice(0, 2)} columns={columns} />
  );
  expect(container.querySelectorAll("tbody tr")).toHaveLength(2);
  const firstRow = container.querySelector("tbody tr:nth-child(1)");
  expect(firstRow).toHaveTextContent("Name 0");
  const secondRow = container.querySelector("tbody tr:nth-child(2)");
  expect(secondRow).toHaveTextContent("Name 1");
});

it("can search data", () => {
  const { container } = renderWithProviders(
    <Table data={data} columns={columns} />
  );
  userEvent.type(screen.getByPlaceholderText("Search"), "Name 42");
  expect(container.querySelectorAll("tbody tr")).toHaveLength(1);
  const firstRow = container.querySelector("tbody tr:nth-child(1)");
  expect(firstRow).toHaveTextContent("Name 42");
});

it("correctly paginates a long list", () => {
  const { container } = renderWithProviders(
    <Table data={data} columns={columns} />
  );
  expect(container.querySelectorAll("tbody tr")).toHaveLength(10);
  const firstRow = container.querySelector("tbody tr:first-child");
  expect(firstRow).toHaveTextContent("Name 0");
  expect(screen.queryByTestId(`pagination-item-0`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-4`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-5`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).toBeInTheDocument();
  userEvent.click(screen.getByTestId(`pagination-last`));
  expect(screen.queryByTestId(`pagination-item-4`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-5`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-9`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-10`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).toBeInTheDocument();
  const lastRow = container.querySelector("tbody tr:last-child");
  expect(lastRow).toHaveTextContent("Name 99");
});
