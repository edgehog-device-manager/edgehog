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

import { it, expect } from "vitest";
import { screen, within } from "@testing-library/react";
import { renderWithProviders } from "setupTests";

import Footer from "./Footer";

it("displays correct app name and app version", () => {
  renderWithProviders(
    <Footer
      appName="Edgehog Device Manager"
      appVersion="0.1.0-alpha.1"
      homepageUrl="https://edgehog.io/"
      repoUrl="https://github.com/edgehog-device-manager/edgehog"
      issueTrackerUrl="https://github.com/edgehog-device-manager/edgehog/issues"
    />,
  );

  const appNameElement = screen.getByText("Edgehog Device Manager");
  expect(appNameElement).toBeVisible();

  const appVersionElement = screen.getByText(/0\.1\.0-alpha\.1/);
  expect(appVersionElement).toBeVisible();
});

it("app logo points to the homepage URL", () => {
  renderWithProviders(
    <Footer
      appName="Edgehog Device Manager"
      appVersion="0.1.0-alpha.1"
      homepageUrl="https://edgehog.io/"
      repoUrl="https://github.com/edgehog-device-manager/edgehog"
      issueTrackerUrl="https://github.com/edgehog-device-manager/edgehog/issues"
    />,
  );

  const homepageLink = screen.getByRole("link", {
    name: "Edgehog Homepage Link",
  });
  expect(homepageLink).toBeVisible();
  expect(homepageLink).toHaveAttribute("href", "https://edgehog.io/");

  const appLogo = within(homepageLink).getByRole("img");
  expect(appLogo).toBeVisible();
});

it("anchors point to correct URL's", () => {
  renderWithProviders(
    <Footer
      appName="Edgehog Device Manager"
      appVersion="0.1.0-alpha.1"
      homepageUrl="https://edgehog.io/"
      repoUrl="https://github.com/edgehog-device-manager/edgehog"
      issueTrackerUrl="https://github.com/edgehog-device-manager/edgehog/issues"
    />,
  );

  const repositoryLink = screen.getByRole("link", { name: "GitHub" });
  expect(repositoryLink).toBeVisible();
  expect(repositoryLink).toHaveAttribute(
    "href",
    "https://github.com/edgehog-device-manager/edgehog",
  );

  const issuesLink = screen.getByRole("link", { name: "GitHub-Issues" });
  expect(issuesLink).toBeVisible();
  expect(issuesLink).toHaveAttribute(
    "href",
    "https://github.com/edgehog-device-manager/edgehog/issues",
  );
});
