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
import { act, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import selectEvent from "react-select-event";
import { createMockEnvironment } from "relay-test-utils";

import { renderWithProviders } from "@/setupTests";
import InstallApplicationModal from "./InstallApplicationModal";

const APPLICATIONS_QUERY_NAME =
  "InstallApplicationModal_GetApplicationsWithReleases_Query";
const DEPLOY_RELEASE_MUTATION_NAME =
  "InstallApplicationModal_DeployRelease_Mutation";
const MARK_ENV_FILE_AS_UPLOADED_MUTATION_NAME =
  "InstallApplicationModal_markEnvFileAsUploaded_Mutation";

const applicationsData = {
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
      ],
    },
    fileDownloadRequests: {
      edges: [],
    },
  },
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
                  containers: {
                    edges: [],
                  },
                },
              },
              {
                node: {
                  id: "rel-2",
                  version: "2.0.0",
                  systemModels: [],
                  containers: {
                    edges: [],
                  },
                },
              },
              {
                node: {
                  id: "rel-3",
                  version: "3.0.0",
                  systemModels: [],
                  containers: {
                    edges: [
                      {
                        node: {
                          id: "container-1",
                          name: "app",
                          fileMounts: {
                            edges: [],
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

it("renders the selects and disables the deploy button until a release is selected", async () => {
  const { relayEnvironment } = renderModal();
  resolveApplicationsQuery(relayEnvironment);

  expect(await screen.findByText("Install Application")).toBeVisible();
  expect(screen.getByText("Application")).toBeVisible();
  expect(screen.getByText("Release")).toBeVisible();
  expect(screen.getByText("Env Strategy")).toBeVisible();
  expect(screen.getByText("Environment")).toBeVisible();
  expect(screen.getByRole("button", { name: "Deploy" })).toBeDisabled();
});

it("enables deploy after selecting an application and a release, then deploys", async () => {
  const { relayEnvironment, onToggleModal, setErrorFeedback } = renderModal();
  resolveApplicationsQuery(relayEnvironment);

  await screen.findByText("Install Application");

  const [appCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(appCombobox, "App One", {
    container: document.body,
  });
  await selectEvent.select(screen.getAllByRole("combobox")[1], "2.0.0", {
    container: document.body,
  });

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
  await selectEvent.select(appCombobox, "App One", {
    container: document.body,
  });

  expect(setErrorFeedback).toHaveBeenCalledTimes(1);
  expect(screen.getByRole("button", { name: "Deploy" })).toBeDisabled();
});

it("deploys with an env file instead of env vars in env file mode", async () => {
  const { relayEnvironment, onToggleModal } = renderModal();
  resolveApplicationsQuery(relayEnvironment);

  await screen.findByText("Install Application");

  const [appCombobox] = screen.getAllByRole("combobox");
  await selectEvent.select(appCombobox, "App One", {
    container: document.body,
  });
  await selectEvent.select(screen.getAllByRole("combobox")[1], "3.0.0", {
    container: document.body,
  });

  // Switch from the default env override mode to env file mode
  await userEvent.click(screen.getByRole("radio", { name: "Env file" }));

  // The env JSON editor is hidden and the per-container env file section shows
  expect(screen.queryByText("Environment")).not.toBeInTheDocument();
  expect(
    await screen.findByTestId("container-env-files-container-1"),
  ).toBeVisible();

  // Pick the device file as the container env file source
  const envFileCombobox = screen.getAllByRole("combobox")[2];
  await selectEvent.select(envFileCombobox, "Device File: /data/.env", {
    container: document.body,
  });

  await userEvent.click(screen.getByRole("button", { name: "Deploy" }));

  const mutationOperation = relayEnvironment.mock.findOperation(
    (op) => op.request.node.params.name === DEPLOY_RELEASE_MUTATION_NAME,
  );
  expect(mutationOperation.request.variables).toEqual({
    input: {
      deviceId: "device-1",
      releaseId: "rel-3",
      configs: [
        {
          containerId: "container-1",
          envStrategy: "merge",
          envFiles: [{ deviceFileId: "device-file-1" }],
        },
      ],
    },
  });

  act(() => {
    relayEnvironment.mock.resolve(mutationOperation, {
      data: {
        deployRelease: {
          result: {
            id: "deployment-1",
            state: "STARTED",
          },
          errors: [],
        },
      },
    });
  });

  await waitFor(() => expect(onToggleModal).toHaveBeenCalledWith(false));
});

it("uploads an env file via presigned URL and marks it as uploaded", async () => {
  const fetchMock = vi.fn(async () => ({ ok: true, statusText: "OK" }));
  vi.stubGlobal("fetch", fetchMock);

  try {
    const { relayEnvironment, onToggleModal } = renderModal();
    resolveApplicationsQuery(relayEnvironment);

    await screen.findByText("Install Application");

    const [appCombobox] = screen.getAllByRole("combobox");
    await selectEvent.select(appCombobox, "App One", {
      container: document.body,
    });
    await selectEvent.select(screen.getAllByRole("combobox")[1], "3.0.0", {
      container: document.body,
    });

    await userEvent.click(screen.getByRole("radio", { name: "Env file" }));
    await userEvent.click(screen.getByRole("radio", { name: "Upload" }));
    await userEvent.click(screen.getByText("File Picker"));

    const envCard = await screen.findByTestId(
      "container-env-files-container-1",
    );
    // The dropzone's hidden file input has no accessible name, so it cannot
    // be queried via Testing Library roles.
    // eslint-disable-next-line testing-library/no-node-access
    const fileInput = envCard.querySelector(
      'input[type="file"]',
    ) as HTMLInputElement;
    expect(fileInput).not.toBeNull();
    const file = new File(["FOO=bar"], ".env", { type: "text/plain" });
    await userEvent.upload(fileInput, file);

    await userEvent.click(screen.getByRole("button", { name: "Deploy" }));

    const mutationOperation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === DEPLOY_RELEASE_MUTATION_NAME,
    );
    expect(mutationOperation.request.variables).toEqual({
      input: {
        deviceId: "device-1",
        releaseId: "rel-3",
        configs: [
          {
            containerId: "container-1",
            envStrategy: "merge",
            envFiles: [{}],
          },
        ],
      },
    });

    act(() => {
      relayEnvironment.mock.resolve(mutationOperation, {
        data: {
          deployRelease: {
            result: {
              id: "deployment-1",
              state: "STARTED",
              containerDeployments: {
                edges: [
                  {
                    node: {
                      id: "container-deployment-1",
                      container: { id: "container-1" },
                      fileBinds: [],
                      envFiles: [
                        {
                          id: "env-file-1",
                          uploaded: false,
                          uploadUrl: "https://s3.example/upload",
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
        "https://s3.example/upload",
        expect.objectContaining({
          method: "PUT",
          headers: { "Content-Type": "text/plain" },
        }),
      ),
    );
    expect(fetchMock.mock.calls[0][1].body).toBeInstanceOf(File);

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
            result: { id: "env-file-1", uploaded: true, state: "CREATED" },
            errors: [],
          },
        },
      });
    });

    await waitFor(() => expect(onToggleModal).toHaveBeenCalledWith(false));
  } finally {
    vi.unstubAllGlobals();
  }
});
