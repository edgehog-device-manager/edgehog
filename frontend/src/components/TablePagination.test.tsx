// This file is part of Edgehog.
//
// Copyright 2021-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import TablePagination from "@/components/TablePagination";

it("returns null when totalPages is less than 2", () => {
  const pageChangeHandler = vi.fn();
  const { container } = render(
    <TablePagination
      activePage={0}
      totalPages={1}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(container).toBeEmptyDOMElement();
});

it("renders correctly", () => {
  const pageChangeHandler = vi.fn();
  const { rerender } = render(
    <TablePagination
      activePage={0}
      totalPages={5}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(screen.getByTestId("pagination-item-0")).toBeVisible();
  expect(screen.getByTestId("pagination-item-1")).toBeVisible();
  expect(screen.getByTestId("pagination-item-2")).toBeVisible();
  expect(screen.getByTestId("pagination-item-3")).toBeVisible();
  expect(screen.getByTestId("pagination-item-4")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-5")).not.toBeInTheDocument();

  const items = screen.getAllByRole("listitem");
  expect(items[0]).toHaveClass("disabled");
  expect(items[items.length - 1]).not.toHaveClass("disabled");

  rerender(
    <TablePagination
      activePage={4}
      totalPages={5}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(screen.getByTestId("pagination-item-0")).toBeVisible();
  expect(screen.getByTestId("pagination-item-1")).toBeVisible();
  expect(screen.getByTestId("pagination-item-2")).toBeVisible();
  expect(screen.getByTestId("pagination-item-3")).toBeVisible();
  expect(screen.getByTestId("pagination-item-4")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-5")).not.toBeInTheDocument();

  const itemsAfter = screen.getAllByRole("listitem");
  expect(itemsAfter[0]).not.toHaveClass("disabled");
  expect(itemsAfter[itemsAfter.length - 1]).toHaveClass("disabled");
});

it("marks the active page item correctly", () => {
  render(
    <TablePagination activePage={2} totalPages={5} onPageChange={vi.fn()} />,
  );

  const items = screen.getAllByRole("listitem");
  expect(items[4]).toHaveClass("active");
  expect(items[3]).not.toHaveClass("active");
});

it("shows only available pages", () => {
  const pageChangeHandler = vi.fn();
  render(
    <TablePagination
      activePage={2}
      totalPages={3}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(screen.getByTestId("pagination-item-0")).toBeVisible();
  expect(screen.getByTestId("pagination-item-1")).toBeVisible();
  expect(screen.getByTestId("pagination-item-2")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-3")).not.toBeInTheDocument();

  const items = screen.getAllByRole("listitem");
  expect(items[0]).not.toHaveClass("disabled");
  expect(items[items.length - 1]).toHaveClass("disabled");
});

it("shows there are more pages available", () => {
  const pageChangeHandler = vi.fn();
  const { rerender } = render(
    <TablePagination
      activePage={0}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(screen.getByTestId("pagination-item-0")).toBeVisible();
  expect(screen.getByTestId("pagination-item-1")).toBeVisible();
  expect(screen.getByTestId("pagination-item-2")).toBeVisible();
  expect(screen.getByTestId("pagination-item-3")).toBeVisible();
  expect(screen.getByTestId("pagination-item-4")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-5")).not.toBeInTheDocument();

  const items1 = screen.getAllByRole("listitem");
  expect(items1[0]).toHaveClass("disabled");
  expect(screen.getByTestId("pagination-last")).toBeVisible();

  rerender(
    <TablePagination
      activePage={15}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(screen.queryByTestId("pagination-item-12")).not.toBeInTheDocument();
  expect(screen.getByTestId("pagination-item-13")).toBeVisible();
  expect(screen.getByTestId("pagination-item-14")).toBeVisible();
  expect(screen.getByTestId("pagination-item-15")).toBeVisible();
  expect(screen.getByTestId("pagination-item-16")).toBeVisible();
  expect(screen.getByTestId("pagination-item-17")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-18")).not.toBeInTheDocument();
  expect(screen.getByTestId("pagination-first")).toBeVisible();
  expect(screen.getByTestId("pagination-last")).toBeVisible();

  rerender(
    <TablePagination
      activePage={29}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />,
  );
  expect(screen.queryByTestId("pagination-item-24")).not.toBeInTheDocument();
  expect(screen.getByTestId("pagination-item-25")).toBeVisible();
  expect(screen.getByTestId("pagination-item-26")).toBeVisible();
  expect(screen.getByTestId("pagination-item-27")).toBeVisible();
  expect(screen.getByTestId("pagination-item-28")).toBeVisible();
  expect(screen.getByTestId("pagination-item-29")).toBeVisible();
  expect(screen.queryByTestId("pagination-item-30")).not.toBeInTheDocument();

  const items3 = screen.getAllByRole("listitem");
  expect(screen.getByTestId("pagination-first")).toBeVisible();
  expect(items3[items3.length - 1]).toHaveClass("disabled");
});

it("manages disabled states for boundary navigation buttons", () => {
  const { rerender } = render(
    <TablePagination activePage={0} totalPages={5} onPageChange={vi.fn()} />,
  );

  const items1 = screen.getAllByRole("listitem");
  expect(items1[1]).toHaveClass("disabled");
  expect(items1[0]).toHaveClass("disabled");
  expect(items1[items1.length - 2]).not.toHaveClass("disabled");

  rerender(
    <TablePagination activePage={4} totalPages={5} onPageChange={vi.fn()} />,
  );

  const items2 = screen.getAllByRole("listitem");
  expect(items2[1]).not.toHaveClass("disabled");
  expect(items2[items2.length - 2]).toHaveClass("disabled");
  expect(items2[items2.length - 1]).toHaveClass("disabled");
});

it("correctly notifies page index on change", async () => {
  const pageChangeHandler = vi.fn();
  render(
    <TablePagination
      activePage={15}
      totalPages={30}
      onPageChange={pageChangeHandler}
    />,
  );

  const user = userEvent.setup();

  await user.click(screen.getByTestId("pagination-item-16"));
  expect(pageChangeHandler).toHaveBeenCalledWith(16);

  await user.click(screen.getByTestId("pagination-first"));
  expect(pageChangeHandler).toHaveBeenCalledWith(0);

  await user.click(screen.getByTestId("pagination-last"));
  expect(pageChangeHandler).toHaveBeenCalledWith(29);

  await user.click(screen.getByText("‹"));
  expect(pageChangeHandler).toHaveBeenCalledWith(14);

  await user.click(screen.getByText("›"));
  expect(pageChangeHandler).toHaveBeenCalledWith(16);
});

it("shows that more pages can be loaded and triggers onLoadMore", async () => {
  const pageChangeHandler = vi.fn();
  const onLoadMoreHandler = vi.fn();
  const user = userEvent.setup();

  render(
    <TablePagination
      activePage={1}
      totalPages={2}
      canLoadMorePages
      onLoadMore={onLoadMoreHandler}
      onPageChange={pageChangeHandler}
    />,
  );

  const paginationLast = screen.getByTestId("pagination-last");
  expect(paginationLast).toBeInTheDocument();
  expect(onLoadMoreHandler).toHaveBeenCalledTimes(0);

  await user.click(paginationLast);
  expect(onLoadMoreHandler).toHaveBeenCalledTimes(1);
  expect(pageChangeHandler).not.toHaveBeenCalled();
});
