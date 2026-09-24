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
import selectEvent from "react-select-event";
import { createMockEnvironment } from "relay-test-utils";

import { renderWithProviders } from "@/setupTests";
import UpgradeDeploymentModal from "./UpgradeDeploymentModal";

const GET_UPGRADE_DATA_QUERY_NAME =
  "UpgradeDeploymentModal_GetUpgradeData_Query";
const UPGRADE_DEPLOYMENT_MUTATION_NAME =
  "UpgradeDeploymentModal_upgradeDeployment_Mutation";
const MARK_ENV_FILE_AS_UPLOADED_MUTATION_NAME =
  "UpgradeDeploymentModal_markEnvFileAsUploaded_Mutation";
const MARK_FILE_BIND_AS_UPLOADED_MUTATION_NAME =
  "UpgradeDeploymentModal_markFileBindAsUploaded_Mutation";

const upgradeData = {
  device: {
    id: "device-1",
    deviceFiles: {
      edges: [
        {
          node: {
            id: "device-file-1",
            pathOnDevice: "/data/.env",
            deleted: false,
            fileDownloadRequest: null,
          },
        },
        {
          node: {
            id: "device-file-2",
            pathOnDevice: "/etc/app.conf",
            deleted: false,
            fileDownloadRequest: null,
          },
        },
      ],
    },
    fileDownloadRequests: {
      edges: [],
    },
  },
  application: {
    id: "app-1",
    name: "App One",
    releases: {
      edges: [
        {
          node: {
            id: "rel-0",
            version: "0.9.0",
            systemModels: [],
            containers: { edges: [] },
          },
        },
        {
          node: {
            id: "rel-1",
            version: "1.0.0",
            systemModels: [],
            containers: { edges: [] },
          },
        },
        {
          node: {
            id: "rel-2",
            version: "2.0.0",
            systemModels: [{ name: "Incompatible Model" }],
            containers: { edges: [] },
          },
        },
        {
          node: {
            id: "rel-3",
            version: "3.0.0",
            systemModels: [{ name: "Test System Model" }],
            containers: {
              edges: [
                {
                  node: {
                    id: "container-1",
                    name: "app",
                    fileMounts: {
                      edges: [
                        {
                          node: {
                            id: "mount-1",
                            mountpoint: "/etc/app.conf",
                            required: false,
                            defaultFileId: null,
                            defaultFile: null,
                            fileMode: null,
                            userId: null,
                            groupId: null,
                          },
                        },
                      ],
                    },
                  },
                },
              ],
            },
          },
        },
      ],
    },
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
      <UpgradeDeploymentModal
        open
        onToggleModal={onToggleModal}
        deploymentId="deployment-1"
        deviceId="device-1"
        applicationId="app-1"
        applicationName="App One"
        currentVersion="1.0.0"
        systemModelName="Test System Model"
        isOnline={isOnline}
        setErrorFeedback={setErrorFeedback}
      />
    </Suspense>,
    { relayEnvironment },
  );

  return { relayEnvironment, onToggleModal, setErrorFeedback };
};

const resolveUpgradeDataQuery = (
  relayEnvironment: ReturnType<typeof createMockEnvironment>,
) => {
  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === GET_UPGRADE_DATA_QUERY_NAME,
    );
    relayEnvironment.mock.resolve(operation, { data: upgradeData });
  });
};

it("renders the modal and disables upgrade until target release is selected", async () => {
  const { relayEnvironment } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  expect(await screen.findByText("Upgrade Deployment")).toBeVisible();
  expect(screen.getByText("Target Release")).toBeVisible();
  expect(
    screen.queryByText("Environment configuration"),
  ).not.toBeInTheDocument();
  expect(screen.getByRole("button", { name: "Upgrade" })).toBeDisabled();
});

it("shows collapsed environment and file mounts sections after selecting a release", async () => {
  const { relayEnvironment } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const envToggle = await screen.findByRole("button", {
    name: "Environment configuration",
  });
  expect(envToggle).toBeVisible();
  expect(envToggle).toHaveAttribute("aria-expanded", "false");

  const mountsToggle = await screen.findByRole("button", {
    name: "File Mounts Configuration",
  });
  expect(mountsToggle).toBeVisible();
  expect(mountsToggle).toHaveAttribute("aria-expanded", "false");

  await userEvent.click(envToggle);
  expect(envToggle).toHaveAttribute("aria-expanded", "true");

  await screen.findByText("No config");
  await screen.findByTestId("container-env-files-container-1");
});

it("does not allow upgrading while device is offline", async () => {
  const { relayEnvironment } = renderModal({ isOnline: false });
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  expect(screen.getByRole("button", { name: "Upgrade" })).toBeDisabled();
});

it("upgrades without container configs by default", async () => {
  const { relayEnvironment, onToggleModal, setErrorFeedback } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const upgradeButton = screen.getByRole("button", { name: "Upgrade" });
  expect(upgradeButton).toBeEnabled();

  await userEvent.click(upgradeButton);

  const upgradeOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === UPGRADE_DEPLOYMENT_MUTATION_NAME,
  );

  expect(upgradeOperation.request.variables).toEqual({
    id: "deployment-1",
    input: {
      target: "rel-3",
    },
  });

  act(() => {
    relayEnvironment.mock.resolve(upgradeOperation, {
      data: {
        upgradeDeployment: {
          result: {
            id: "deployment-2",
            state: "SUCCESS",
            containerDeployments: { edges: [] },
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() => {
    expect(onToggleModal).toHaveBeenCalledWith(false);
  });
  expect(setErrorFeedback).toHaveBeenCalledWith(null);
});

it("shows per-container strategy and editor in env override mode", async () => {
  const { relayEnvironment } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const envToggle = await screen.findByRole("button", {
    name: "Environment configuration",
  });
  await userEvent.click(envToggle);

  await userEvent.click(screen.getByRole("radio", { name: "Env override" }));

  expect(screen.getByText("Env Strategy")).toBeVisible();
  expect(screen.getByText("Environment")).toBeVisible();

  await userEvent.click(screen.getByRole("button", { name: "Upgrade" }));

  const upgradeOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === UPGRADE_DEPLOYMENT_MUTATION_NAME,
  );

  expect(upgradeOperation.request.variables).toEqual({
    id: "deployment-1",
    input: {
      target: "rel-3",
    },
  });
});

it("upgrades with an env file in env file mode", async () => {
  const { relayEnvironment } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const envToggle = await screen.findByRole("button", {
    name: "Environment configuration",
  });
  await userEvent.click(envToggle);

  await userEvent.click(screen.getByRole("radio", { name: "Env file" }));

  expect(screen.queryByText("Environment")).not.toBeInTheDocument();
  await screen.findByTestId("container-env-files-container-1");

  const envFileCombobox = screen.getAllByRole("combobox")[1];
  await selectEvent.select(envFileCombobox, "Device File: /data/.env", {
    container: document.body,
  });

  const upgradeButton = screen.getByRole("button", { name: "Upgrade" });
  expect(upgradeButton).toBeEnabled();

  await userEvent.click(upgradeButton);

  const upgradeOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === UPGRADE_DEPLOYMENT_MUTATION_NAME,
  );

  expect(upgradeOperation.request.variables).toEqual({
    id: "deployment-1",
    input: {
      target: "rel-3",
      configs: [
        {
          containerId: "container-1",
          envStrategy: "merge",
          envFiles: [{ deviceFileId: "device-file-1" }],
        },
      ],
    },
  });
});

it("upgrades with file mounts configured", async () => {
  const { relayEnvironment } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const mountsToggle = await screen.findByRole("button", {
    name: "File Mounts Configuration",
  });
  await userEvent.click(mountsToggle);

  const mountCombobox = screen.getAllByRole("combobox")[1];
  await selectEvent.select(mountCombobox, "Device File: /etc/app.conf", {
    container: document.body,
  });

  const upgradeButton = screen.getByRole("button", { name: "Upgrade" });
  expect(upgradeButton).toBeEnabled();

  await userEvent.click(upgradeButton);

  const upgradeOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === UPGRADE_DEPLOYMENT_MUTATION_NAME,
  );

  expect(upgradeOperation.request.variables).toEqual({
    id: "deployment-1",
    input: {
      target: "rel-3",
      configs: [
        {
          containerId: "container-1",
          envStrategy: "merge",
          fileBinds: [
            {
              deviceFileId: "device-file-2",
              fileMountId: "mount-1",
            },
          ],
        },
      ],
    },
  });
});

it("uploads an env file via presigned URL and marks it as uploaded", async () => {
  const fetchMock = vi
    .fn()
    .mockResolvedValue(new Response(null, { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);

  const { relayEnvironment, onToggleModal } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const envToggle = await screen.findByRole("button", {
    name: "Environment configuration",
  });
  await userEvent.click(envToggle);

  await userEvent.click(screen.getByRole("radio", { name: "Env file" }));

  const envCard = await screen.findByTestId("container-env-files-container-1");
  await userEvent.click(within(envCard).getByRole("radio", { name: "Upload" }));
  await userEvent.click(within(envCard).getByText("File Picker"));
  // eslint-disable-next-line testing-library/no-node-access
  const fileInput = envCard.querySelector(
    'input[type="file"]',
  ) as HTMLInputElement;
  expect(fileInput).not.toBeNull();
  const file = new File(["FOO=bar"], ".env", { type: "text/plain" });
  await userEvent.upload(fileInput, file);

  const upgradeButton = screen.getByRole("button", { name: "Upgrade" });
  await userEvent.click(upgradeButton);

  const upgradeOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === UPGRADE_DEPLOYMENT_MUTATION_NAME,
  );

  expect(upgradeOperation.request.variables.input.configs).toEqual([
    {
      containerId: "container-1",
      envStrategy: "merge",
      envFiles: [{}],
    },
  ]);

  act(() => {
    relayEnvironment.mock.resolve(upgradeOperation, {
      data: {
        upgradeDeployment: {
          result: {
            id: "deployment-2",
            state: "SUCCESS",
            containerDeployments: {
              edges: [
                {
                  node: {
                    id: "cd-1",
                    container: { id: "container-1" },
                    fileBinds: [],
                    envFiles: [
                      {
                        id: "env-file-1",
                        uploaded: false,
                        uploadUrl: "https://s3.example.com/upload-env",
                      },
                    ],
                  },
                },
              ],
            },
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() =>
    expect(fetchMock).toHaveBeenCalledWith(
      "https://s3.example.com/upload-env",
      expect.objectContaining({
        method: "PUT",
        headers: { "Content-Type": "text/plain" },
      }),
    ),
  );
  expect((fetchMock.mock.calls[0] as any)?.[1]?.body).toBeInstanceOf(File);

  const markUploadedOperation = relayEnvironment.mock.findOperation(
    (op) =>
      op.request.node.params.name === MARK_ENV_FILE_AS_UPLOADED_MUTATION_NAME,
  );

  expect(markUploadedOperation.request.variables).toEqual({
    id: "env-file-1",
    input: {
      fileName: ".env",
      uncompressedFileSizeBytes: 7,
      digest: expect.stringMatching(/^sha256:[0-9a-f]{64}$/),
      encoding: "",
    },
  });

  act(() => {
    relayEnvironment.mock.resolve(markUploadedOperation, {
      data: {
        markEnvFileAsUploaded: {
          result: {
            id: "env-file-1",
            uploaded: true,
            state: "SUCCESS",
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() => {
    expect(onToggleModal).toHaveBeenCalledWith(false);
  });
});

it("uploads a file mount via presigned URL and marks it as uploaded", async () => {
  const fetchMock = vi
    .fn()
    .mockResolvedValue(new Response(null, { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);

  const { relayEnvironment, onToggleModal } = renderModal();
  resolveUpgradeDataQuery(relayEnvironment);

  await screen.findByText("Upgrade Deployment");

  const [releaseCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(releaseCombobox, "3.0.0", {
    container: document.body,
  });

  const mountsToggle = await screen.findByRole("button", {
    name: "File Mounts Configuration",
  });
  await userEvent.click(mountsToggle);

  const uploadRadio = screen.getByRole("radio", { name: "Upload" });
  await userEvent.click(uploadRadio);
  await userEvent.click(screen.getByText("File Picker"));

  // eslint-disable-next-line testing-library/no-node-access
  const fileInput = document.querySelector(
    'input[type="file"]',
  ) as HTMLInputElement;
  expect(fileInput).not.toBeNull();
  const file = new File(["CONFIG=1"], "app.conf", { type: "text/plain" });
  await userEvent.upload(fileInput, file);

  const upgradeButton = screen.getByRole("button", { name: "Upgrade" });
  await userEvent.click(upgradeButton);

  const upgradeOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === UPGRADE_DEPLOYMENT_MUTATION_NAME,
  );

  expect(upgradeOperation.request.variables.input.configs).toEqual([
    {
      containerId: "container-1",
      envStrategy: "merge",
      fileBinds: [
        {
          fileMountId: "mount-1",
        },
      ],
    },
  ]);

  act(() => {
    relayEnvironment.mock.resolve(upgradeOperation, {
      data: {
        upgradeDeployment: {
          result: {
            id: "deployment-2",
            state: "SUCCESS",
            containerDeployments: {
              edges: [
                {
                  node: {
                    id: "cd-1",
                    container: { id: "container-1" },
                    fileBinds: [
                      {
                        id: "file-bind-1",
                        fileMountId: "mount-1",
                        uploaded: false,
                        uploadUrl: "https://s3.example.com/upload-bind",
                      },
                    ],
                    envFiles: [],
                  },
                },
              ],
            },
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() =>
    expect(fetchMock).toHaveBeenCalledWith(
      "https://s3.example.com/upload-bind",
      expect.objectContaining({
        method: "PUT",
        headers: { "Content-Type": "text/plain" },
      }),
    ),
  );
  expect((fetchMock.mock.calls[0] as any)?.[1]?.body).toBeInstanceOf(File);

  const markUploadedOperation = relayEnvironment.mock.findOperation(
    (op) =>
      op.request.node.params.name === MARK_FILE_BIND_AS_UPLOADED_MUTATION_NAME,
  );

  expect(markUploadedOperation.request.variables).toEqual({
    id: "file-bind-1",
    input: {
      fileName: "app.conf",
      uncompressedFileSizeBytes: 8,
      digest: expect.stringMatching(/^sha256:[0-9a-f]{64}$/),
      encoding: "",
    },
  });

  act(() => {
    relayEnvironment.mock.resolve(markUploadedOperation, {
      data: {
        markFileBindAsUploaded: {
          result: {
            id: "file-bind-1",
            uploaded: true,
            state: "SUCCESS",
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() => {
    expect(onToggleModal).toHaveBeenCalledWith(false);
  });
});
