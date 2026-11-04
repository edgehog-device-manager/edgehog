/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { Suspense } from "react";
import { it, expect } from "vitest";
import { act, screen } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import { renderWithProviders } from "@/setupTests";
import type { VolumesTable_TestQuery } from "@/api/__generated__/VolumesTable_TestQuery.graphql";
import VolumesTable from "./VolumesTable";

const TEST_QUERY = graphql`
  query VolumesTable_TestQuery($id: ID!) @relay_test_operation {
    device(id: $id) {
      ...VolumesTable_volumeDeployments
    }
  }
`;

const ComponentWithQuery = () => {
  const data = useLazyLoadQuery<VolumesTable_TestQuery>(TEST_QUERY, {
    id: "device-1",
  });

  if (!data.device) return null;

  return (
    <Suspense fallback={null}>
      <VolumesTable deviceRef={data.device} />
    </Suspense>
  );
};

const renderComponent = (volumeDeploymentsEdges: unknown[]) => {
  const relayEnvironment = createMockEnvironment();

  renderWithProviders(<ComponentWithQuery />, { relayEnvironment });

  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === "VolumesTable_TestQuery",
    );
    relayEnvironment.mock.resolve(operation, {
      data: {
        device: {
          id: "device-1",
          volumeDeployments: {
            edges: volumeDeploymentsEdges,
          },
        },
      },
    });
  });

  return relayEnvironment;
};

it("renders empty message when there are no volumes", async () => {
  renderComponent([]);

  expect(await screen.findByText("No volumes")).toBeVisible();
  expect(screen.getByText("The device has no volumes.")).toBeVisible();
});

it("renders volumes with label, driver, mountpoints, and state", async () => {
  renderComponent([
    {
      node: {
        id: "vol-dep-1",
        state: "available",
        isReady: true,
        volume: {
          id: "vol-1",
          label: "app-data",
          driver: "local",
          containerVolumes: {
            edges: [
              {
                node: {
                  id: "cv-1",
                  target: "/var/lib/app",
                  container: {
                    id: "cnt-1",
                    name: "backend-service",
                  },
                },
              },
            ],
          },
        },
      },
    },
  ]);

  const volumeLink = await screen.findByRole("link", { name: "app-data" });
  expect(volumeLink).toBeVisible();
  expect(volumeLink).toHaveAttribute("href", "/volumes/vol-1");

  expect(screen.getByText("local")).toBeVisible();

  const containerLink = screen.getByRole("link", { name: "backend-service" });
  expect(containerLink).toBeVisible();
  expect(containerLink).toHaveAttribute("href", "/containers/cnt-1");
  expect(screen.getByText("/var/lib/app")).toBeVisible();

  expect(screen.getByText("available")).toBeVisible();
});
