/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { describe, it, expect, vi } from "vitest";
import { screen } from "@testing-library/react";
import { userEvent } from "@testing-library/user-event";
import { renderWithProviders } from "setupTests";

import Page from "./Page";

describe("Page", () => {
  it("renders children correctly", () => {
    renderWithProviders(
      <Page>
        <div data-testid="page-children" />
      </Page>,
    );

    const pageElement = screen.getByTestId("page-children");
    expect(pageElement).toBeVisible();
  });
});

describe("Header", () => {
  it("renders title correctly", () => {
    renderWithProviders(<Page.Header title="Header Title" />);

    const pageTitle = screen.getByRole("heading", { name: "Header Title" });
    expect(pageTitle).toBeVisible();
  });

  it("does not render the heading without title property", () => {
    renderWithProviders(<Page.Header />);

    const pageTitle = screen.queryByRole("heading");
    expect(pageTitle).not.toBeInTheDocument();
  });

  it("renders children correctly", () => {
    renderWithProviders(
      <Page.Header>
        <div data-testid="header-children" />
      </Page.Header>,
    );

    expect(screen.getByTestId("header-children")).toBeVisible();
  });
});

describe("Main", () => {
  it("indicates the primary content of a document", () => {
    renderWithProviders(<Page.Main />);

    expect(screen.getByRole("main")).toBeVisible();
  });

  it("renders children correctly", () => {
    renderWithProviders(
      <Page.Main>
        <div data-testid="main-children" />
      </Page.Main>,
    );

    expect(screen.getByTestId("main-children")).toBeVisible();
  });
});

describe("LoadingError", () => {
  it("does not render 'Try Again' button without onRetry property", () => {
    renderWithProviders(<Page.LoadingError />);

    const tryAgainButton = screen.queryByRole("button", { name: "Try again" });
    expect(tryAgainButton).not.toBeInTheDocument();
  });

  it("renders 'Try Again' button and handles click", async () => {
    const onRetryFunction = vi.fn();

    renderWithProviders(<Page.LoadingError onRetry={onRetryFunction} />);

    const retryButton = screen.getByRole("button", { name: "Try Again" });
    expect(retryButton).toBeVisible();

    await userEvent.click(retryButton);
    expect(onRetryFunction).toHaveBeenCalledTimes(1);
  });
});
