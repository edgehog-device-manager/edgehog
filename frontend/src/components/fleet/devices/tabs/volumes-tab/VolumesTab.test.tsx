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
import { it, expect, vi, beforeAll } from "vitest";
import { act, screen, waitFor } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import { renderWithProviders } from "@/setupTests";
import Tabs from "@/components/ui/tabs/Tabs";
import type { VolumesTab_TestQuery } from "@/api/__generated__/VolumesTab_TestQuery.graphql";
import DeviceVolumesTab from "./VolumesTab";

beforeAll(() => {
  Element.prototype.scrollTo = vi.fn();
});

vi.mock("@/components/fleet/devices/volumes-table/VolumesTable", () => ({
  default: () => <div data-testid="volumes-table">Volumes table</div>,
}));

const TEST_QUERY = graphql`
  query VolumesTab_TestQuery($id: ID!) @relay_test_operation {
    device(id: $id) {
      ...VolumesTab_volumeDeployments
    }
  }
`;

type DeviceData = {
  device: {
    id: string;
    capabilities: string[];
    volumeDeployments: {
      edges: never[];
    };
  };
};

const createDeviceData = (
  capabilities: string[] = ["CONTAINER_MANAGEMENT"],
): DeviceData => ({
  device: {
    id: "device-1",
    capabilities,
    volumeDeployments: {
      edges: [],
    },
  },
});

const ComponentWithQuery = () => {
  const data = useLazyLoadQuery<VolumesTab_TestQuery>(TEST_QUERY, {
    id: "device-1",
  });

  if (!data.device) {
    return null;
  }

  return (
    <Suspense fallback={null}>
      <Tabs activeKey="device-volumes-tab">
        <DeviceVolumesTab deviceRef={data.device} />
      </Tabs>
    </Suspense>
  );
};

const renderComponent = (device: DeviceData) => {
  const relayEnvironment = createMockEnvironment();

  renderWithProviders(<ComponentWithQuery />, { relayEnvironment });

  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === "VolumesTab_TestQuery",
    );
    relayEnvironment.mock.resolve(operation, { data: device });
  });

  return relayEnvironment;
};

it("renders the Volumes tab with the volumes table", async () => {
  renderComponent(createDeviceData());

  expect(await screen.findByRole("button", { name: "Volumes" })).toBeVisible();
  expect(screen.getByTestId("volumes-table")).toBeVisible();
});

it("does not render the tab when the device lacks the container management capability", async () => {
  renderComponent(createDeviceData(["HARDWARE_INFO"]));

  await waitFor(() => {
    expect(screen.queryByTestId("volumes-table")).not.toBeInTheDocument();
  });
  expect(
    screen.queryByRole("button", { name: "Volumes" }),
  ).not.toBeInTheDocument();
});
