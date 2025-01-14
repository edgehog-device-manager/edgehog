/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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
import { screen } from "@testing-library/react";
import { renderWithProviders } from "setupTests";
import { createMockEnvironment } from "relay-test-utils";

import { graphql, useLazyLoadQuery } from "react-relay/hooks";
import type { HardwareTypesTable_getHardwareTypes_Query } from "api/__generated__/HardwareTypesTable_getHardwareTypes_Query.graphql";

import HardwareTypesTable from "./HardwareTypesTable";

const GET_HARDWARE_TYPES_QUERY = graphql`
  query HardwareTypesTable_getHardwareTypes_Query($first: Int, $after: String)
  @relay_test_operation {
    ...HardwareTypesTable_HardwareTypesFragment
  }
`;

const ComponentWithQuery = () => {
  const hardwareTypes =
    useLazyLoadQuery<HardwareTypesTable_getHardwareTypes_Query>(
      GET_HARDWARE_TYPES_QUERY,
      {},
    );
  return <HardwareTypesTable hardwareTypesRef={hardwareTypes} />;
};

type HardwareType = {
  id: string;
  handle: string;
  name: string;
  partNumbers: {
    edges: {
      node: {
        id: string;
        partNumber: string;
      };
    }[];
  };
};

const renderComponent = (hardwareTypes: HardwareType[] = []) => {
  const relayEnvironment = createMockEnvironment();

  relayEnvironment.mock.queueOperationResolver(() => ({
    data: {
      hardwareTypes: {
        edges: hardwareTypes.map((model) => ({
          node: model,
        })),
      },
    },
  }));

  relayEnvironment.mock.queuePendingOperation(GET_HARDWARE_TYPES_QUERY, {});

  renderWithProviders(<ComponentWithQuery />, { relayEnvironment });
};

it("renders column headers", () => {
  renderComponent();

  expect(
    screen.getByRole("columnheader", { name: "Hardware Type Name" }),
  ).toBeVisible();
  expect(screen.getByRole("columnheader", { name: "Handle" })).toBeVisible();
  expect(
    screen.getByRole("columnheader", { name: "Part Numbers" }),
  ).toBeVisible();
});

it("renders Hardware Type data", () => {
  renderComponent([
    {
      id: "HW-ID",
      handle: "hw-handle",
      name: "HW name",
      partNumbers: {
        edges: [{ node: { id: "HW-PN1", partNumber: "HW-PN1" } }],
      },
    },
  ]);

  expect(screen.getByRole("cell", { name: "HW name" })).toBeVisible();
  expect(screen.getByRole("link", { name: "HW name" })).toHaveAttribute(
    "href",
    "/hardware-types/HW-ID/edit",
  );
  expect(screen.getByRole("cell", { name: "hw-handle" })).toBeVisible();
  expect(screen.getByRole("cell", { name: "HW-PN1" })).toBeVisible();
});

it("renders multiple Part Numbers separated by comma", () => {
  renderComponent([
    {
      id: "HW-ID",
      handle: "hw-handle",
      name: "HW name",
      partNumbers: {
        edges: [
          { node: { id: "HW-PN1", partNumber: "HW-PN1" } },
          { node: { id: "HW-PN2", partNumber: "HW-PN2" } },
        ],
      },
    },
  ]);

  expect(screen.getByRole("cell", { name: "HW-PN1 , HW-PN2" })).toBeVisible();
});

it("renders Hardware Type data in correct columns", () => {
  renderComponent([
    {
      id: "HW-ID",
      handle: "hw-handle",
      name: "HW name",
      partNumbers: {
        edges: [
          { node: { id: "HW-PN1", partNumber: "HW-PN1" } },
          { node: { id: "HW-PN2", partNumber: "HW-PN2" } },
        ],
      },
    },
  ]);

  const columns = screen.getAllByRole("columnheader");
  const cells = screen.getAllByRole("cell");

  expect(columns).toHaveLength(3);
  expect(cells).toHaveLength(3);

  expect(columns[0]).toHaveTextContent("Hardware Type Name");
  expect(cells[0]).toHaveTextContent("HW name");

  expect(columns[1]).toHaveTextContent("Handle");
  expect(cells[1]).toHaveTextContent("hw-handle");

  expect(columns[2]).toHaveTextContent("Part Numbers");
  expect(cells[2]).toHaveTextContent("HW-PN1, HW-PN2");
});
