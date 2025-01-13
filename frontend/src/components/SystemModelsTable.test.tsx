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
import type { SystemModelsTable_getSystemModels_Query } from "api/__generated__/SystemModelsTable_getSystemModels_Query.graphql";

import SystemModelsTable from "./SystemModelsTable";

const GET_SYSTEM_MODELS_QUERY = graphql`
  query SystemModelsTable_getSystemModels_Query($first: Int, $after: String)
  @relay_test_operation {
    ...SystemModelsTable_SystemModelsFragment
  }
`;

const ComponentWithQuery = () => {
  const systemModels =
    useLazyLoadQuery<SystemModelsTable_getSystemModels_Query>(
      GET_SYSTEM_MODELS_QUERY,
      {},
    );
  return <SystemModelsTable systemModelsRef={systemModels} />;
};

type SystemModel = {
  id: string;
  handle: string;
  name: string;
  hardwareType: {
    id: string;
    name: string;
  };
  partNumbers: {
    edges: {
      node: {
        id: string;
        partNumber: string;
      };
    }[];
  };
};

const renderComponent = (systemModels: SystemModel[] = []) => {
  const relayEnvironment = createMockEnvironment();

  relayEnvironment.mock.queueOperationResolver(() => ({
    data: {
      systemModels: {
        edges: systemModels.map((model) => ({
          node: model,
        })),
      },
    },
  }));

  relayEnvironment.mock.queuePendingOperation(GET_SYSTEM_MODELS_QUERY, {});

  renderWithProviders(<ComponentWithQuery />, { relayEnvironment });
};

it("renders column headers", async () => {
  renderComponent();

  expect(
    screen.getByRole("columnheader", { name: "System Model Name" }),
  ).toBeVisible();
  expect(screen.getByRole("columnheader", { name: "Handle" })).toBeVisible();
  expect(
    screen.getByRole("columnheader", { name: "Hardware Type" }),
  ).toBeVisible();
  expect(
    screen.getByRole("columnheader", { name: "Part Numbers" }),
  ).toBeVisible();
});

it("renders System Model data", async () => {
  renderComponent([
    {
      id: "SM-ID",
      handle: "sm-handle",
      name: "SM name",
      hardwareType: {
        id: "HW-ID",
        name: "HW name",
      },
      partNumbers: {
        edges: [{ node: { id: "SM-PN1", partNumber: "SM-PN1" } }],
      },
    },
  ]);

  expect(screen.getByRole("cell", { name: "SM name" })).toBeVisible();
  expect(screen.getByRole("link", { name: "SM name" })).toHaveAttribute(
    "href",
    "/system-models/SM-ID/edit",
  );
  expect(screen.getByRole("cell", { name: "sm-handle" })).toBeVisible();
  expect(screen.getByRole("cell", { name: "HW name" })).toBeVisible();
  expect(screen.getByRole("cell", { name: "SM-PN1" })).toBeVisible();
});

it("renders multiple Part Numbers separated by comma", async () => {
  renderComponent([
    {
      id: "SM-ID",
      handle: "sm-handle",
      name: "SM name",
      hardwareType: {
        id: "HW-ID",
        name: "HW name",
      },
      partNumbers: {
        edges: [
          { node: { id: "SM-PN1", partNumber: "SM-PN1" } },
          { node: { id: "SM-PN2", partNumber: "SM-PN2" } },
        ],
      },
    },
  ]);

  expect(screen.getByRole("cell", { name: "SM-PN1 , SM-PN2" })).toBeVisible();
});

it("renders System Model data in correct columns", async () => {
  renderComponent([
    {
      id: "SM-ID",
      handle: "sm-handle",
      name: "SM name",
      hardwareType: {
        id: "HW-ID",
        name: "HW name",
      },
      partNumbers: {
        edges: [{ node: { id: "SM-PN1", partNumber: "SM-PN1" } }],
      },
    },
  ]);

  const columns = screen.getAllByRole("columnheader");
  const cells = screen.getAllByRole("cell");

  expect(columns).toHaveLength(4);
  expect(cells).toHaveLength(4);

  expect(columns[0]).toHaveTextContent("System Model Name");
  expect(cells[0]).toHaveTextContent("SM name");

  expect(columns[1]).toHaveTextContent("Handle");
  expect(cells[1]).toHaveTextContent("sm-handle");

  expect(columns[2]).toHaveTextContent("Hardware Type");
  expect(cells[2]).toHaveTextContent("HW name");

  expect(columns[3]).toHaveTextContent("Part Numbers");
  expect(cells[3]).toHaveTextContent("SM-PN1");
});
