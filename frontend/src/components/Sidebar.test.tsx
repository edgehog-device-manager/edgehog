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

import { screen } from "@testing-library/react";
import { expect, it } from "vitest";

import { renderWithProviders } from "@/setupTests";
import Sidebar from "./Sidebar";

const sidebarLinks = [
  ["Devices", "/devices"],
  ["Groups", "/device-groups"],
  ["Update Campaigns", "/update-campaigns"],
  ["Channels", "/channels"],
  ["Base Image Collections", "/base-image-collections"],
  ["System Models", "/system-models"],
  ["Hardware Types", "/hardware-types"],
  ["Applications", "/applications"],
];

it.each(sidebarLinks)("has link to %s", (name, href) => {
  renderWithProviders(<Sidebar />);

  const link = screen.getByRole("link", { name });
  expect(link).toBeVisible();
  expect(link).toHaveAttribute("href", href);
});

it.each(sidebarLinks)(
  "shows %s link as active, others - as inactive on route %s",
  (name, href) => {
    renderWithProviders(<Sidebar />, { path: href });

    const activeLink = screen.getByRole("link", { name });
    const links = screen.getAllByRole("link");

    expect(activeLink).toHaveClass("bg-primary");
    links.forEach((link) => {
      if (link !== activeLink) {
        expect(link).not.toHaveClass("bg-primary");
      }
    });
  },
);
