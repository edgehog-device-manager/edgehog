/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import { it, expect, describe } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import Tabs, { Tab } from "./Tabs";

describe("Tabs", () => {
  it("assigns className to the Tabs component", () => {
    render(<Tabs className="custom-tabs-class">Tabs Content</Tabs>);

    const tabsElement = screen.getByText("Tabs Content");
    expect(tabsElement).toHaveClass("custom-tabs-class");
  });

  describe("defaultActiveKey", () => {
    it("when not specified, makes the first tab active", () => {
      render(
        <Tabs>
          <Tab eventKey="tab1" title="Tab 1">
            <div data-testid="tab1-content" />
          </Tab>
          <Tab eventKey="tab2" title="Tab 2">
            <div data-testid="tab2-content" />
          </Tab>
        </Tabs>,
      );

      expect(
        screen.getByRole("tab", { name: "Tab 1", selected: true }),
      ).toBeVisible();
      expect(screen.getByTestId("tab1-content")).toBeVisible();
    });

    it("when specified, renders the content of the active tab", () => {
      render(
        <Tabs defaultActiveKey="tab2">
          <Tab eventKey="tab1" title="Tab 1">
            <div data-testid="tab1-content" />
          </Tab>
          <Tab eventKey="tab2" title="Tab 2">
            <div data-testid="tab2-content" />
          </Tab>
        </Tabs>,
      );

      expect(
        screen.getByRole("tab", { name: "Tab 2", selected: true }),
      ).toBeVisible();
      expect(screen.getByTestId("tab2-content")).toBeVisible();
    });

    it("does not render inactive tab content", () => {
      render(
        <Tabs defaultActiveKey="tab1">
          <Tab eventKey="tab1" title="Tab 1">
            <div data-testid="tab1-content" />
          </Tab>
          <Tab eventKey="tab2" title="Tab 2">
            <div data-testid="tab2-content" />
          </Tab>
        </Tabs>,
      );

      expect(
        screen.getByRole("tab", { name: "Tab 2", selected: false }),
      ).toBeVisible();
      expect(screen.queryByTestId("tab2-content")).not.toBeInTheDocument();
    });
  });

  it("changes active tab correctly", async () => {
    render(
      <Tabs defaultActiveKey="tab1">
        <Tab eventKey="tab1" title="Tab 1">
          <div data-testid="tab1-content" />
        </Tab>
        <Tab eventKey="tab2" title="Tab 2">
          <div data-testid="tab2-content" />
        </Tab>
      </Tabs>,
    );

    expect(
      screen.getByRole("tab", { name: "Tab 1", selected: true }),
    ).toBeVisible();
    expect(screen.getByTestId("tab1-content")).toBeVisible();

    expect(
      screen.getByRole("tab", { name: "Tab 2", selected: false }),
    ).toBeVisible();
    expect(screen.queryByTestId("tab2-content")).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole("tab", { name: "Tab 2" }));

    expect(
      screen.getByRole("tab", { name: "Tab 1", selected: false }),
    ).toBeVisible();
    expect(screen.queryByTestId("tab1-content")).not.toBeInTheDocument();

    expect(
      screen.getByRole("tab", { name: "Tab 2", selected: true }),
    ).toBeVisible();
    expect(screen.getByTestId("tab2-content")).toBeVisible();
  });

  describe("tabsOrder", () => {
    it("when not specified, respects children order", () => {
      render(
        <Tabs>
          <Tab eventKey="tabOne" title="Tab 1" />
          <Tab eventKey="tabTwo" title="Tab 2" />
          <Tab eventKey="tabThree" title="Tab 3" />
        </Tabs>,
      );
      const tabs = screen.getAllByRole("tab");
      expect(tabs[0]).toHaveTextContent("Tab 1");
      expect(tabs[1]).toHaveTextContent("Tab 2");
      expect(tabs[2]).toHaveTextContent("Tab 3");
    });

    it("when specified, renders tabs in the requested order", () => {
      render(
        <Tabs tabsOrder={["tabTwo", "tabOne", "tabThree"]}>
          <Tab eventKey="tabOne" title="Tab 1" />
          <Tab eventKey="tabTwo" title="Tab 2" />
          <Tab eventKey="tabThree" title="Tab 3" />
        </Tabs>,
      );
      const tabs = screen.getAllByRole("tab");
      expect(tabs[0]).toHaveTextContent("Tab 2");
      expect(tabs[1]).toHaveTextContent("Tab 1");
      expect(tabs[2]).toHaveTextContent("Tab 3");
    });

    it("renders the tabs specified in the tabsOrder before the other tabs", () => {
      render(
        <Tabs tabsOrder={["tabThree", "tabOne"]}>
          <Tab eventKey="tabOne" title="Tab 1" />
          <Tab eventKey="tabTwo" title="Tab 2" />
          <Tab eventKey="tabThree" title="Tab 3" />
          <Tab eventKey="tabFour" title="Tab 4" />
        </Tabs>,
      );
      const tabs = screen.getAllByRole("tab");
      expect(tabs[0]).toHaveTextContent("Tab 3");
      expect(tabs[1]).toHaveTextContent("Tab 1");
      expect(tabs[2]).toHaveTextContent("Tab 2");
      expect(tabs[3]).toHaveTextContent("Tab 4");
    });
  });
});

describe("Tab", () => {
  it("renders tab title correctly", () => {
    render(
      <Tabs>
        <Tab eventKey="tab1" title="Tab 1" />
      </Tabs>,
    );

    expect(screen.getByRole("tab", { name: "Tab 1" })).toBeVisible();
  });

  it("renders tab content correctly", () => {
    render(
      <Tabs>
        <Tab eventKey="tab1">
          <div data-testid="tab1-content" />
        </Tab>
      </Tabs>,
    );
    expect(screen.getByTestId("tab1-content")).toBeVisible();
  });

  it("assigns className to the Tab component", () => {
    render(
      <Tabs>
        <Tab eventKey="tab1" className="custom-tab-class">
          Tab 1
        </Tab>
      </Tabs>,
    );

    const tab1 = screen.getByText("Tab 1");
    expect(tab1).toHaveClass("custom-tab-class");
  });
});
