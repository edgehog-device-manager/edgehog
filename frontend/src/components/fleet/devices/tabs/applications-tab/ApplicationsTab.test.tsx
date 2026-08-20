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
import userEvent from "@testing-library/user-event";
import { createMockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import { renderWithProviders } from "@/setupTests";
import Tabs from "@/components/ui/tabs/Tabs";
import type { ApplicationsTab_TestQuery } from "@/api/__generated__/ApplicationsTab_TestQuery.graphql";
import DeviceApplicationsTab from "./ApplicationsTab";

beforeAll(() => {
  Element.prototype.scrollTo = vi.fn();
});

vi.mock(
  "@/components/apps/releases/install-application-modal/InstallApplicationModal",
  () => ({
    default: ({
      open,
      deviceId,
      systemModelName,
    }: {
      open: boolean;
      deviceId: string;
      systemModelName?: string;
    }) =>
      open ? (
        <div data-testid="install-application-modal">
          Modal open for {deviceId} ({systemModelName})
        </div>
      ) : null,
  }),
);

vi.mock(
  "@/components/apps/releases/deployed-applications-table/DeployedApplicationsTable",
  () => ({
    default: () => (
      <div data-testid="deployed-applications-table">Deployed applications</div>
    ),
  }),
);

const TEST_QUERY = graphql`
  query ApplicationsTab_TestQuery($id: ID!, $first: Int, $after: String)
  @relay_test_operation {
    ...ApplicationsTab_deployedApplications
  }
`;

type DeviceData = {
  device: {
    id: string;
    online: boolean;
    capabilities: string[];
    systemModel: {
      name: string;
    };
  };
};

const createDeviceData = (
  capabilities: string[] = ["CONTAINER_MANAGEMENT"],
): DeviceData => ({
  device: {
    id: "device-1",
    online: true,
    capabilities,
    systemModel: {
      name: "Test System Model",
    },
  },
});

const ComponentWithQuery = () => {
  const data = useLazyLoadQuery<ApplicationsTab_TestQuery>(TEST_QUERY, {
    id: "device-1",
  });

  return (
    <Suspense fallback={null}>
      <Tabs activeKey="device-applications-tab">
        <DeviceApplicationsTab deviceRef={data} />
      </Tabs>
    </Suspense>
  );
};

const renderComponent = (device: DeviceData) => {
  const relayEnvironment = createMockEnvironment();

  renderWithProviders(<ComponentWithQuery />, { relayEnvironment });

  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === "ApplicationsTab_TestQuery",
    );
    relayEnvironment.mock.resolve(operation, { data: device });
  });

  return relayEnvironment;
};

it("renders a unique Applications section with the install button and the list", async () => {
  renderComponent(createDeviceData());

  expect(
    await screen.findByRole("heading", { name: "Applications" }),
  ).toBeVisible();
  expect(screen.getByRole("button", { name: "Install" })).toBeVisible();
  expect(screen.getByTestId("deployed-applications-table")).toBeVisible();
  expect(
    screen.queryByTestId("install-application-modal"),
  ).not.toBeInTheDocument();
});

it("opens the install modal when clicking the install button", async () => {
  const user = userEvent.setup();
  renderComponent(createDeviceData());

  await screen.findByRole("heading", { name: "Applications" });

  await user.click(screen.getByRole("button", { name: "Install" }));

  const modal = screen.getByTestId("install-application-modal");
  expect(modal).toBeVisible();
  expect(modal).toHaveTextContent("Modal open for device-1");
  expect(modal).toHaveTextContent("Test System Model");
});

it("does not render the section when the device lacks the container management capability", async () => {
  renderComponent(createDeviceData(["HARDWARE_INFO"]));

  await waitFor(() => {
    expect(
      screen.queryByTestId("deployed-applications-table"),
    ).not.toBeInTheDocument();
  });
  expect(
    screen.queryByRole("heading", { name: "Applications" }),
  ).not.toBeInTheDocument();
  expect(
    screen.queryByRole("button", { name: "Install" }),
  ).not.toBeInTheDocument();
});
