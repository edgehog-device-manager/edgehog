/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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

import { it, expect } from "vitest";

import { renderWithProviders } from "setupTests";
import Sidebar from "./Sidebar";

it("renders correctly", async () => {
  const { container } = renderWithProviders(<Sidebar />, {});

  const devicesLink = container.querySelector("a[href='/devices']");
  expect(devicesLink).toBeInTheDocument();
  expect(devicesLink).toHaveTextContent("Devices");

  const groupsLink = container.querySelector("a[href='/device-groups']");
  expect(groupsLink).toBeInTheDocument();
  expect(groupsLink).toHaveTextContent("Groups");

  const updateCampaignsLink = container.querySelector(
    "a[href='/update-campaigns']",
  );
  expect(updateCampaignsLink).toBeInTheDocument();
  expect(updateCampaignsLink).toHaveTextContent("Update Campaigns");

  const updateChannelsLink = container.querySelector(
    "a[href='/update-channels']",
  );
  expect(updateChannelsLink).toBeInTheDocument();
  expect(updateChannelsLink).toHaveTextContent("Update Channels");

  const baseImageCollectionsLink = container.querySelector(
    "a[href='/base-image-collections']",
  );
  expect(baseImageCollectionsLink).toBeInTheDocument();
  expect(baseImageCollectionsLink).toHaveTextContent("Base Image Collections");

  const systemModelsLink = container.querySelector("a[href='/system-models']");
  expect(systemModelsLink).toBeInTheDocument();
  expect(systemModelsLink).toHaveTextContent("System Models");

  const hardwareTypesLink = container.querySelector(
    "a[href='/hardware-types']",
  );
  expect(hardwareTypesLink).toBeInTheDocument();
  expect(hardwareTypesLink).toHaveTextContent("Hardware Types");

  const menuGroups = container.querySelectorAll(".accordion");
  expect(menuGroups).toHaveLength(2);

  expect(menuGroups[0]).toHaveTextContent("Update Campaigns");
  expect(menuGroups[0]).toHaveTextContent("Update Channels");
  expect(menuGroups[0]).toHaveTextContent("Base Image Collections");

  expect(menuGroups[1]).toHaveTextContent("System Models");
  expect(menuGroups[1]).toHaveTextContent("Hardware Types");
});

it("shows links as active when route matches", async () => {
  const { container } = renderWithProviders(<Sidebar />, {
    path: "/devices",
  });

  const devicesLink = container.querySelector("a[href='/devices']");
  expect(devicesLink).toHaveClass("bg-primary");

  const groupsLink = container.querySelector("a[href='/device-groups']");
  expect(groupsLink).not.toHaveClass("bg-primary");

  const updateCampaignsLink = container.querySelector(
    "a[href='/update-campaigns']",
  );
  expect(updateCampaignsLink).not.toHaveClass("bg-primary");

  const updateChannelsLink = container.querySelector(
    "a[href='/update-channels']",
  );
  expect(updateChannelsLink).not.toHaveClass("bg-primary");

  const baseImageCollectionsLink = container.querySelector(
    "a[href='/base-image-collections']",
  );
  expect(baseImageCollectionsLink).not.toHaveClass("bg-primary");

  const systemModelsLink = container.querySelector("a[href='/system-models']");
  expect(systemModelsLink).not.toHaveClass("bg-primary");

  const hardwareTypesLink = container.querySelector(
    "a[href='/hardware-types']",
  );
  expect(hardwareTypesLink).not.toHaveClass("bg-primary");
});
