/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

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

import React from "react";
import Pagination from "react-bootstrap/Pagination";

import "./TablePagination.scss";

const MAX_SHOWN_PAGES = 5;

interface Props {
  activePage: number;
  canLoadMorePages?: boolean;
  onLoadMore?: () => void;
  onPageChange: (pageIndex: number) => void;
  totalPages: number;
}

const TablePagination = ({
  activePage,
  canLoadMorePages = false,
  onLoadMore,
  onPageChange,
  totalPages,
}: Props): React.ReactElement | null => {
  if (totalPages < 2) {
    return null;
  }

  let endPage = activePage + Math.floor(MAX_SHOWN_PAGES / 2);
  if (endPage < MAX_SHOWN_PAGES - 1) {
    endPage = MAX_SHOWN_PAGES - 1;
  }
  if (endPage > totalPages - 1) {
    endPage = totalPages - 1;
  }

  let startPage = endPage - (MAX_SHOWN_PAGES - 1);
  if (startPage < 0) {
    startPage = 0;
  }

  const items = [];
  for (let pageIndex = startPage; pageIndex <= endPage; pageIndex += 1) {
    items.push(
      <Pagination.Item
        data-testid={`pagination-item-${pageIndex}`}
        className="border-0"
        key={pageIndex}
        active={pageIndex === activePage}
        onClick={() => {
          onPageChange(pageIndex);
        }}
      >
        {pageIndex + 1}
      </Pagination.Item>
    );
  }

  return (
    <Pagination className="justify-content-center border-0">
      {startPage > 0 && (
        <Pagination.First
          data-testid="pagination-first"
          onClick={() => {
            onPageChange(0);
          }}
        />
      )}
      {items}
      {(endPage < totalPages - 1 || canLoadMorePages) && (
        <Pagination.Last
          data-testid="pagination-last"
          onClick={() => {
            if (endPage === totalPages - 1) {
              return onLoadMore && onLoadMore();
            }
            return onPageChange(totalPages - 1);
          }}
        />
      )}
    </Pagination>
  );
};

export default TablePagination;
