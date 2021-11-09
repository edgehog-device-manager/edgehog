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
*/

import React from "react";
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { renderWithProviders } from "setupTests";
import Topbar from "./Topbar";

it("renders correctly", async () => {
  const { container } = renderWithProviders(<Topbar />);
  expect(container.querySelector(".navbar-brand")).toBeInTheDocument();
  const menuGroups = container.querySelectorAll(".dropdown");
  expect(menuGroups).toHaveLength(1);

  const userMenu = menuGroups[0];
  const userMenuToggle = userMenu.querySelector(".dropdown-toggle")!;
  userEvent.click(userMenuToggle);
  await waitFor(() => {
    expect(document.querySelector("a[href='/logout']")).toHaveTextContent(
      "Logout"
    );
  });
});
