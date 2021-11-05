/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind

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

import { renderWithProviders } from "setupTests";
import Sidebar from "./Sidebar";

it("renders correctly", async () => {
  const { container } = renderWithProviders(<Sidebar />, {});

  const devicesLink = container.querySelector("a[href='/devices']");
  expect(devicesLink).toBeInTheDocument();
  expect(devicesLink).toHaveTextContent("Devices");

  const applianceModelsLink = container.querySelector(
    "a[href='/appliance-models']"
  );
  expect(applianceModelsLink).toBeInTheDocument();
  expect(applianceModelsLink).toHaveTextContent("Appliance Models");

  const hardwareTypesLink = container.querySelector(
    "a[href='/hardware-types']"
  );
  expect(hardwareTypesLink).toBeInTheDocument();
  expect(hardwareTypesLink).toHaveTextContent("Hardware Types");

  const menuGroups = container.querySelectorAll(".accordion");
  expect(menuGroups).toHaveLength(1);
  expect(menuGroups[0]).toHaveTextContent("Appliance Models");
  expect(menuGroups[0]).toHaveTextContent("Hardware Types");
});

it("shows links as active when route matches", async () => {
  const { container } = renderWithProviders(<Sidebar />, {
    path: "/devices",
  });

  const devicesLink = container.querySelector("a[href='/devices']");
  const applianceModelsLink = container.querySelector(
    "a[href='/appliance-models']"
  );
  expect(devicesLink).toHaveClass("bg-primary");
  expect(applianceModelsLink).not.toHaveClass("bg-primary");
});
