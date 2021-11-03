import React from "react";
import { render, screen } from "@testing-library/react";

import TablePagination from "./TablePagination";

it("renders correctly", () => {
  const pageChangeHandler = jest.fn();
  const { rerender } = render(
    <TablePagination
      activePage={0}
      totalPages={5}
      onPageChange={pageChangeHandler}
    />
  );
  expect(screen.queryByTestId(`pagination-item-0`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-1`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-2`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-3`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-4`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-5`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).not.toBeInTheDocument();

  rerender(
    <TablePagination
      activePage={5}
      totalPages={5}
      onPageChange={pageChangeHandler}
    />
  );
  expect(screen.queryByTestId(`pagination-item-0`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-1`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-2`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-3`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-4`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-5`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).not.toBeInTheDocument();
});

it("shows only available pages", () => {
  const pageChangeHandler = jest.fn();
  render(
    <TablePagination
      activePage={2}
      totalPages={3}
      onPageChange={pageChangeHandler}
    />
  );
  expect(screen.queryByTestId(`pagination-item-0`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-1`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-2`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-3`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).not.toBeInTheDocument();
});

it("shows there are more pages available", () => {
  const pageChangeHandler = jest.fn();
  const { rerender } = render(
    <TablePagination
      activePage={0}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />
  );
  expect(screen.queryByTestId(`pagination-item-0`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-1`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-2`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-3`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-4`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-5`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).toBeInTheDocument();

  rerender(
    <TablePagination
      activePage={15}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />
  );
  expect(screen.queryByTestId(`pagination-item-12`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-13`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-14`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-15`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-16`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-17`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-18`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).toBeInTheDocument();

  rerender(
    <TablePagination
      activePage={30}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />
  );
  expect(screen.queryByTestId(`pagination-item-24`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-25`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-26`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-27`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-28`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-29`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-item-30`)).not.toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-first`)).toBeInTheDocument();
  expect(screen.queryByTestId(`pagination-last`)).not.toBeInTheDocument();
});

it("correctly notifies page index on change", () => {
  const pageChangeHandler = jest.fn();
  render(
    <TablePagination
      activePage={15}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />
  );
  screen.getByTestId("pagination-item-16").click();
  expect(pageChangeHandler).toHaveBeenCalledWith(16);
  screen.getByTestId("pagination-first").click();
  expect(pageChangeHandler).toHaveBeenCalledWith(0);
  screen.getByTestId("pagination-last").click();
  expect(pageChangeHandler).toHaveBeenCalledWith(29);
});

it("shows that more pages can be loaded", () => {
  const pageChangeHandler = jest.fn();
  const onLoadMoreHandler = jest.fn();
  render(
    <TablePagination
      activePage={0}
      totalPages={2}
      canLoadMorePages
      onLoadMore={onLoadMoreHandler}
      onPageChange={pageChangeHandler}
    />
  );
  const paginationLast = screen.queryByTestId(`pagination-last`);
  expect(paginationLast).toBeInTheDocument();
  expect(onLoadMoreHandler).toHaveBeenCalledTimes(0);
  paginationLast?.click();
  expect(onLoadMoreHandler).toHaveBeenCalledTimes(1);
});
