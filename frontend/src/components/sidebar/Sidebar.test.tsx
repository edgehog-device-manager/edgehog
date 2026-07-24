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

import { fireEvent, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import assets from "@/assets";
import { renderWithProviders } from "@/setupTests";
import Sidebar from "@/components/Sidebar";

const defaultProps = {
  appName: "Edgehog Device Manager",
  appVersion: "v1.0.0",
  isDesktopCollapsed: false,
  isMobileMenuOpen: false,
};

const renderSidebar = (
  path?: string,
  props?: Partial<React.ComponentProps<typeof Sidebar>>,
) =>
  renderWithProviders(
    <Sidebar {...defaultProps} onToggleCollapse={vi.fn()} {...props} />,
    path ? { path } : {},
  );

const sidebarLinks = [
  ["Devices", "/devices"],
  ["Groups", "/device-groups"],
  ["Channels", "/channels"],
  ["Repositories", "/repositories"],
  ["File Download Campaigns", "/file-download-campaigns"],
  ["Update Campaigns", "/update-campaigns"],
  ["Base Image Collections", "/base-image-collections"],
  ["System Models", "/system-models"],
  ["Hardware Types", "/hardware-types"],
  ["Applications", "/applications"],
  ["Image Credentials", "/image-credentials"],
  ["Volumes", "/volumes"],
  ["Networks", "/networks"],
  ["Containers", "/containers"],
  ["Deployments", "/deployments"],
  ["Campaigns", "/deployment-campaigns"],
  ["Logout", "/logout"],
];

describe("Sidebar Component", () => {
  it.each(sidebarLinks)("has link to %s", (name, href) => {
    renderSidebar();

    const link = screen.getByRole("link", { name });
    expect(link).toBeVisible();
    expect(link).toHaveAttribute("href", href);
  });

  it.each(sidebarLinks)(
    "shows %s link as active, others as inactive on route %s",
    (name, href) => {
      renderSidebar(href);

      const activeLink = screen.getByRole("link", { name });
      const links = screen.getAllByRole("link");

      expect(activeLink).toHaveClass("active");
      links.forEach((link) => {
        if (link !== activeLink) {
          expect(link).not.toHaveClass("active");
        }
      });
    },
  );

  it("calls onToggleCollapse when the collapse button is clicked", () => {
    const onToggleCollapse = vi.fn();
    renderSidebar(undefined, { onToggleCollapse });

    const toggleButton = screen
      .getAllByRole("button")
      .find((btn) => btn.classList.contains("sidebar-collapse-toggle"));

    expect(toggleButton).toBeDefined();
    fireEvent.click(toggleButton!);
    expect(onToggleCollapse).toHaveBeenCalledOnce();
  });

  it("renders correctly in collapsed desktop mode", () => {
    renderSidebar(undefined, { isDesktopCollapsed: true });

    const sidebarElement = screen.getByRole("complementary");
    expect(sidebarElement).toHaveClass("collapsed-desktop");

    const logo = screen.getByRole("img", { name: "Clea Edgehog Logo" });
    expect(logo).toHaveAttribute("src", assets.images.logo);
  });

  it("renders correctly in mobile open mode", () => {
    renderSidebar(undefined, { isMobileMenuOpen: true });

    const sidebarElement = screen.getByRole("complementary");
    expect(sidebarElement).toHaveClass("mobile-open");

    expect(
      screen.queryByRole("img", { name: "Clea Edgehog Logo" }),
    ).not.toBeInTheDocument();

    const toggleButton = screen
      .queryAllByRole("button")
      .find((btn) => btn.classList.contains("sidebar-collapse-toggle"));
    expect(toggleButton).toBeUndefined();
  });

  it("displays repository and documentation links when provided", () => {
    const repoUrl = "https://github.com/example/repo";
    const docsUrl = "https://docs.example.com";

    renderSidebar(undefined, { repoUrl, docsUrl });

    const links = screen.getAllByRole("link");
    const repoLink = links.find(
      (link) => link.getAttribute("href") === repoUrl,
    );
    const docsLink = links.find(
      (link) => link.getAttribute("href") === docsUrl,
    );

    expect(repoLink).toBeInTheDocument();
    expect(docsLink).toBeInTheDocument();
  });

  it("displays app name and version", () => {
    renderSidebar(undefined, {
      appName: "Custom Test App",
      appVersion: "v9.9.9",
    });

    expect(screen.getByText("Custom Test App")).toBeInTheDocument();
    expect(screen.getByText("vv9.9.9")).toBeInTheDocument();
  });
});
