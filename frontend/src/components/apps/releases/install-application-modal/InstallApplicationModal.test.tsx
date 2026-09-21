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

import { Suspense, type ReactNode } from "react";
import { it, expect, vi } from "vitest";
import { act, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMockEnvironment } from "relay-test-utils";

import { renderWithProviders } from "@/setupTests";
import InstallApplicationModal from "./InstallApplicationModal";

const APPLICATIONS_QUERY_NAME =
  "InstallApplicationModal_GetApplicationsWithReleases_Query";
const RELEASE_CONTAINERS_QUERY_NAME =
  "InstallApplicationModal_GetReleaseContainers_Query";
const DEPLOY_RELEASE_MUTATION_NAME =
  "InstallApplicationModal_DeployRelease_Mutation";

const applicationsData = {
  applications: {
    edges: [
      {
        node: {
          id: "app-1",
          name: "App One",
          releases: {
            edges: [
              {
                node: {
                  id: "rel-1",
                  version: "1.0.0",
                  systemModels: [{ name: "Test System Model" }],
                },
              },
              {
                node: {
                  id: "rel-2",
                  version: "2.0.0",
                  systemModels: [],
                },
              },
            ],
          },
        },
      },
    ],
  },
};

type RenderModalParams = {
  isOnline?: boolean;
  onToggleModal?: (show: boolean) => void;
  setErrorFeedback?: (errorMessages: ReactNode) => void;
};

const renderModal = ({
  isOnline = true,
  onToggleModal = vi.fn(() => {}),
  setErrorFeedback = vi.fn(() => {}),
}: RenderModalParams = {}) => {
  const relayEnvironment = createMockEnvironment();

  renderWithProviders(
    <Suspense fallback={null}>
      <InstallApplicationModal
        open
        onToggleModal={onToggleModal}
        deviceId="device-1"
        systemModelName="Test System Model"
        isOnline={isOnline}
        setErrorFeedback={setErrorFeedback}
      />
    </Suspense>,
    { relayEnvironment },
  );

  return { relayEnvironment, onToggleModal, setErrorFeedback };
};

const resolveApplicationsQuery = (
  relayEnvironment: ReturnType<typeof createMockEnvironment>,
) => {
  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === APPLICATIONS_QUERY_NAME,
    );
    relayEnvironment.mock.resolve(operation, { data: applicationsData });
  });
};

const resolveReleaseContainersQuery = (
  relayEnvironment: ReturnType<typeof createMockEnvironment>,
  containers: { id: string; name: string }[] = [],
) => {
  act(() => {
    const op = relayEnvironment.mock.findOperation(
      (o) => o.request.node.params.name === RELEASE_CONTAINERS_QUERY_NAME,
    );
    if (!op) return;
    relayEnvironment.mock.resolve(op, {
      data: {
        release: {
          id: "rel-2",
          containers: {
            edges: containers.map((c) => ({ node: c })),
          },
        },
      },
    });
  });
};

const selectOption = async (combobox: HTMLElement, text: string) => {
  await userEvent.click(combobox);
  // menu is portaled to document.body, so query within body
  const option = await within(document.body).findByText(text);
  await userEvent.click(option);
};

it("renders the selects and disables deploy until a release is selected", async () => {
  const { relayEnvironment } = renderModal();
  resolveApplicationsQuery(relayEnvironment);

  expect(await screen.findByText("Install Application")).toBeVisible();
  expect(screen.getByText("Select Application")).toBeVisible();
  expect(screen.getByText("Select Release")).toBeVisible();
  expect(screen.getByRole("button", { name: "Deploy" })).toBeDisabled();
});

it("enables deploy after selecting an application and a release, then deploys", async () => {
  const { relayEnvironment, onToggleModal, setErrorFeedback } = renderModal();
  resolveApplicationsQuery(relayEnvironment);

  await screen.findByText("Install Application");

  const [appCombobox] = screen.getAllByRole("combobox");
  await selectOption(appCombobox, "App One");
  await selectOption(screen.getAllByRole("combobox")[1], "2.0.0");

  // release containers query fires on selection
  resolveReleaseContainersQuery(relayEnvironment, []);

  const deployButton = screen.getByRole("button", { name: "Deploy" });
  expect(deployButton).toBeEnabled();

  await userEvent.click(deployButton);

  const mutationOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === DEPLOY_RELEASE_MUTATION_NAME,
  );
  expect(mutationOperation.request.variables).toEqual({
    input: {
      deviceId: "device-1",
      releaseId: "rel-2",
    },
  });

  act(() => {
    relayEnvironment.mock.resolve(mutationOperation, {
      data: {
        deployRelease: {
          result: {
            id: "deployment-1",
            state: "STARTED",
            containerDeployments: { edges: [] },
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() => expect(onToggleModal).toHaveBeenCalledWith(false));
  expect(setErrorFeedback).toHaveBeenCalledWith(null);
});

it("does not allow deploying while the device is offline", async () => {
  const { relayEnvironment, setErrorFeedback } = renderModal({
    isOnline: false,
  });
  resolveApplicationsQuery(relayEnvironment);

  await screen.findByText("Install Application");

  const [appCombobox] = screen.getAllByRole("combobox");
  await selectOption(appCombobox, "App One");

  expect(setErrorFeedback).toHaveBeenCalledTimes(1);
  expect(screen.getByRole("button", { name: "Deploy" })).toBeDisabled();
});
