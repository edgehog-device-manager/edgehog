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
import { describe, it, expect, vi } from "vitest";
import { act, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import selectEvent from "react-select-event";
import { createMockEnvironment, type MockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import { renderWithProviders } from "@/setupTests";
import CreateDeploymentCampaignForm, {
  transformOutputData,
} from "./CreateDeploymentCampaign";
import type { CreateDeploymentCampaign_TestOptions_Query } from "@/api/__generated__/CreateDeploymentCampaign_TestOptions_Query.graphql";

// The release picker fetches its own paginated query; stub it so this test
// exercises the campaign form's file mount wiring only.
vi.mock("@/components/apps/releases/release-select/ReleaseSelect", () => ({
  default: ({
    isTarget,
    selectedApp,
    controllerProps,
  }: {
    isTarget?: boolean;
    selectedApp?: { id: string };
    controllerProps: {
      value?: { id: string; version: string } | null;
      onChange: (value: { id: string; version: string } | null) => void;
    };
  }) =>
    selectedApp ? (
      <select
        aria-label={isTarget ? "Target release" : "Release"}
        value={controllerProps.value?.id ?? ""}
        onChange={(event) => {
          const val = event.target.value;
          controllerProps.onChange(
            val === "rel-2"
              ? { id: "rel-2", version: "2.0.0" }
              : val
                ? { id: "rel-1", version: "1.0.0" }
                : null,
          );
        }}
      >
        <option value="">Select...</option>
        <option value="rel-1">1.0.0</option>
        <option value="rel-2">2.0.0</option>
      </select>
    ) : null,
}));

const TEST_OPTIONS_QUERY = graphql`
  query CreateDeploymentCampaign_TestOptions_Query(
    $first: Int
    $after: String
    $filterApplications: ApplicationFilterInput = {}
    $filterChannels: ChannelFilterInput = {}
  ) {
    applications(first: $first, after: $after, filter: $filterApplications) {
      __typename
    }
    channels(first: $first, after: $after, filter: $filterChannels) {
      __typename
    }
    ...CreateDeploymentCampaign_ApplicationOptionsFragment
      @arguments(filter: $filterApplications)
    ...CreateDeploymentCampaign_ChannelOptionsFragment
      @arguments(filter: $filterChannels)
  }
`;

const baseFormData = {
  name: "My Campaign",
  scheduledAtTimestamp: "",
  channel: { id: "channel-1", name: "Production" },
  application: { id: "app-1", name: "App One" },
  release: { id: "rel-1", version: "1.0.0" },
  operationType: "Deploy" as const,
  maxFailurePercentage: 10,
  maxInProgressOperations: 1,
  requestRetries: 3,
  requestTimeoutSeconds: 300,
};

const repositoryConfigs = [
  {
    containerId: "container-1",
    fileBinds: [{ fileMountId: "mount-1", fileId: "file-1" }],
  },
  {
    containerId: "container-2",
    fileBinds: [
      { fileMountId: "mount-2", fileId: "file-2" },
      { fileMountId: "mount-3", fileId: "file-3" },
    ],
  },
];

describe("transformOutputData", () => {
  it("attaches the file bind configs to the deploy mechanism", () => {
    const result = transformOutputData(baseFormData, repositoryConfigs);

    expect(result.campaignMechanism).toEqual({
      deploymentDeploy: {
        releaseId: "rel-1",
        maxFailurePercentage: 10,
        maxInProgressOperations: 1,
        requestRetries: 3,
        requestTimeoutSeconds: 300,
        configs: repositoryConfigs,
      },
    });
  });

  it("omits the configs when no file mounts were configured", () => {
    const result = transformOutputData(baseFormData, []);

    expect(result.campaignMechanism).toEqual({
      deploymentDeploy: {
        releaseId: "rel-1",
        maxFailurePercentage: 10,
        maxInProgressOperations: 1,
        requestRetries: 3,
        requestTimeoutSeconds: 300,
      },
    });
  });

  it("attaches the file bind configs to the upgrade mechanism", () => {
    const result = transformOutputData(
      { ...baseFormData, operationType: "Upgrade" },
      repositoryConfigs,
    );

    expect(result.campaignMechanism).toEqual({
      deploymentUpgrade: {
        releaseId: "rel-1",
        maxFailurePercentage: 10,
        maxInProgressOperations: 1,
        requestRetries: 3,
        requestTimeoutSeconds: 300,
        configs: repositoryConfigs,
      },
    });
  });

  it.each(["Start", "Stop", "Delete"] as const)(
    "never attaches the configs to the %s mechanism",
    (operationType) => {
      const result = transformOutputData(
        { ...baseFormData, operationType },
        repositoryConfigs,
      );

      expect(result.campaignMechanism).toEqual({
        [{
          Start: "deploymentStart",
          Stop: "deploymentStop",
          Delete: "deploymentDelete",
        }[operationType]]: {
          releaseId: "rel-1",
          maxFailurePercentage: 10,
          maxInProgressOperations: 1,
          requestRetries: 3,
          requestTimeoutSeconds: 300,
        },
      });
    },
  );

  it("keeps the target release alongside the configs", () => {
    const result = transformOutputData(
      { ...baseFormData, targetRelease: { id: "rel-2", version: "2.0.0" } },
      repositoryConfigs,
    );

    expect(result.campaignMechanism).toEqual({
      deploymentDeploy: {
        releaseId: "rel-1",
        targetReleaseId: "rel-2",
        maxFailurePercentage: 10,
        maxInProgressOperations: 1,
        requestRetries: 3,
        requestTimeoutSeconds: 300,
        configs: repositoryConfigs,
      },
    });
  });

  it("serializes the scheduled timestamp when present", () => {
    const result = transformOutputData(
      { ...baseFormData, scheduledAtTimestamp: "2026-05-04T10:00:00Z" },
      [],
    );

    expect(result.scheduledAtTimestamp).toBe(
      new Date("2026-05-04T10:00:00Z").toISOString(),
    );
  });
});

const connectionPageInfo = {
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: "cursor-1",
  endCursor: "cursor-1",
};

const optionsData = {
  applications: {
    __typename: "ApplicationConnection",
    count: 1,
    pageInfo: connectionPageInfo,
    edges: [
      {
        cursor: "cursor-1",
        node: {
          __typename: "Application",
          id: "app-1",
          name: "App One",
          releases: {
            edges: [
              {
                node: {
                  __typename: "Release",
                  id: "rel-1",
                  version: "1.0.0",
                  containers: {
                    edges: [
                      {
                        node: {
                          __typename: "Container",
                          id: "container-1",
                          name: "main",
                          fileMounts: {
                            edges: [
                              {
                                node: {
                                  __typename: "FileMount",
                                  id: "mount-1",
                                  mountpoint: "/opt/config.yaml",
                                  required: true,
                                  defaultFileId: null,
                                  fileMode: 493,
                                  userId: 0,
                                  groupId: 0,
                                  defaultFile: null,
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
              {
                node: {
                  __typename: "Release",
                  id: "rel-2",
                  version: "2.0.0",
                  containers: {
                    edges: [
                      {
                        node: {
                          __typename: "Container",
                          id: "container-2",
                          name: "worker",
                          fileMounts: {
                            edges: [
                              {
                                node: {
                                  __typename: "FileMount",
                                  id: "mount-2",
                                  mountpoint: "/etc/worker.conf",
                                  required: true,
                                  defaultFileId: null,
                                  defaultFile: null,
                                  fileMode: 420,
                                  userId: 1000,
                                  groupId: 1001,
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
      },
    ],
  },
  channels: {
    __typename: "ChannelConnection",
    count: 1,
    pageInfo: connectionPageInfo,
    edges: [
      {
        cursor: "cursor-1",
        node: {
          __typename: "Channel",
          id: "channel-1",
          name: "Production",
        },
      },
    ],
  },
};

const FormHarness = ({ onSubmit }: { onSubmit: () => void }) => {
  const data = useLazyLoadQuery<CreateDeploymentCampaign_TestOptions_Query>(
    TEST_OPTIONS_QUERY,
    { first: 20, after: null },
  );

  return (
    <CreateDeploymentCampaignForm
      campaignOptionsRef={data}
      onSubmit={onSubmit}
    />
  );
};

const renderForm = async () => {
  const relayEnvironment = createMockEnvironment();
  const onSubmit = vi.fn();

  renderWithProviders(
    <Suspense fallback={null}>
      <FormHarness onSubmit={onSubmit} />
    </Suspense>,
    { relayEnvironment },
  );

  await act(async () => {
    relayEnvironment.mock.resolveMostRecentOperation(() => ({
      data: optionsData,
    }));
  });

  return { relayEnvironment, onSubmit };
};

const resolveOperation = async (
  relayEnvironment: ReturnType<typeof createMockEnvironment>,
  name: string,
  data: Record<string, unknown>,
) => {
  await waitFor(
    () =>
      expect(
        relayEnvironment.mock
          .getAllOperations()
          .some((op) => op.request.node.params.name === name),
      ).toBe(true),
    { timeout: 5000 },
  );

  await act(async () => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === name,
    );

    relayEnvironment.mock.resolve(operation, { data });
  });
};

const repositoriesData = {
  repositories: {
    __typename: "RepositoryConnection",
    edges: [
      {
        node: { __typename: "Repository", id: "repo-1", name: "Configs" },
      },
    ],
  },
};

const repositoryFilesData = {
  repository: {
    __typename: "Repository",
    id: "repo-1",
    files: {
      __typename: "FileConnection",
      edges: [
        { node: { __typename: "File", id: "file-1", name: "config.yaml" } },
      ],
    },
  },
};

const selectApplicationAndRelease = async (releaseId = "rel-1") => {
  // combobox 0 is the operation type, 1 the application; the release picker is
  // a native select stubbed above.
  await waitFor(() => expect(screen.getAllByRole("combobox")).toHaveLength(3));

  await selectEvent.select(screen.getAllByRole("combobox")[1], "App One", {
    container: document.body,
  });

  await userEvent.selectOptions(screen.getByLabelText("Release"), releaseId);
};

describe("CreateDeploymentCampaignForm file mounts", { timeout: 15000 }, () => {
  // The channel picker is the last combobox outside the file mounts section,
  // since the mount repository/file pickers are react-selects too.
  const selectChannel = async () => {
    const mountsSection = screen.queryByTestId(
      "deployment-campaign-file-mounts",
    );
    const mountPickers = mountsSection
      ? within(mountsSection).queryAllByRole("combobox")
      : [];
    const formComboboxes = screen
      .getAllByRole("combobox")
      .filter((combobox) => !mountPickers.includes(combobox));
    const channelCombobox = formComboboxes[formComboboxes.length - 1];

    await selectEvent.select(channelCombobox, "Production", {
      container: document.body,
    });
  };

  const selectOperationType = async (operationType: string) => {
    await selectEvent.select(
      screen.getAllByRole("combobox")[0],
      operationType,
      {
        container: document.body,
      },
    );
  };

  // Fill in the fields react-hook-form validates before it hands the form over.
  const completeRequiredFields = async () => {
    await userEvent.type(screen.getByLabelText("Name"), "Campaign");
    await selectChannel();
  };

  // The repository picker is lazy: resolve its repositories first.
  const pickRepositoryFile = async (relayEnvironment: MockEnvironment) => {
    const mountsToggle = screen.queryByRole("button", {
      name: "File Mounts Configuration",
    });
    if (
      mountsToggle &&
      mountsToggle.getAttribute("aria-expanded") === "false"
    ) {
      await userEvent.click(mountsToggle);
    }

    await resolveOperation(
      relayEnvironment,
      "FileMountInput_GetRepositories_Query",
      repositoriesData,
    );

    const mountsSection = await screen.findByTestId(
      "deployment-campaign-file-mounts",
      {},
      { timeout: 5000 },
    );

    const repoCombobox = await within(mountsSection).findByRole(
      "combobox",
      {},
      { timeout: 5000 },
    );

    await selectEvent.select(repoCombobox, "Configs", {
      container: document.body,
    });

    await resolveOperation(
      relayEnvironment,
      "FileMountInput_GetRepositoryFiles_Query",
      repositoryFilesData,
    );

    const fileCombobox = await waitFor(
      () => {
        const comboboxes = within(mountsSection).getAllByRole("combobox");
        expect(comboboxes).toHaveLength(2);
        return comboboxes[1];
      },
      { timeout: 5000 },
    );

    await selectEvent.select(fileCombobox, "config.yaml", {
      container: document.body,
    });
  };
  it("renders one repository-only input per file mount without looping", async () => {
    await renderForm();
    await selectApplicationAndRelease();

    expect(
      await screen.findByTestId("deployment-campaign-file-mounts"),
    ).toBeVisible();
    expect(screen.getByTestId("container-mounts-container-1")).toBeVisible();
    expect(screen.getByText("/opt/config.yaml")).toBeVisible();

    // Only the repository mode is available without a device.
    expect(
      screen.getByRole("radio", { name: "Repository File" }),
    ).toBeVisible();
    expect(
      screen.queryByRole("radio", { name: "Device File" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("radio", { name: "Upload" }),
    ).not.toBeInTheDocument();
  });

  it("shows collapsed environment and file mounts sections after selecting a release", async () => {
    await renderForm();
    await selectApplicationAndRelease();

    const envToggle = await screen.findByRole("button", {
      name: "Environment Configuration",
    });
    expect(envToggle).toBeVisible();
    expect(envToggle).toHaveAttribute("aria-expanded", "false");

    const mountsToggle = await screen.findByRole("button", {
      name: "File Mounts Configuration",
    });
    expect(mountsToggle).toBeVisible();
    expect(mountsToggle).toHaveAttribute("aria-expanded", "false");

    await userEvent.click(mountsToggle);
    expect(mountsToggle).toHaveAttribute("aria-expanded", "true");
  });

  it("shows environment configuration section and allows selecting override mode", async () => {
    await renderForm();
    await selectApplicationAndRelease();

    const envToggle = await screen.findByRole("button", {
      name: "Environment Configuration",
    });
    await userEvent.click(envToggle);
    expect(envToggle).toHaveAttribute("aria-expanded", "true");

    await userEvent.click(screen.getByRole("radio", { name: "Env override" }));
    expect(screen.getByText("Environment strategy")).toBeInTheDocument();
    expect(screen.getByText("Environment variables")).toBeInTheDocument();
  });

  it("raises the missing binds feedback on submit attempt and clears it once configured", async () => {
    const { relayEnvironment, onSubmit } = await renderForm();

    await selectApplicationAndRelease();
    await screen.findByTestId("deployment-campaign-file-mounts");
    await completeRequiredFields();

    // The feedback is raised on submit attempt, not eagerly, so a pristine form
    // is not flagged for work the user has not started yet.
    expect(screen.queryByTestId("missing-required-binds-feedback")).toBeNull();

    // Submitting is allowed, but the form refuses the incomplete submission and
    // says which mountpoints are still missing.
    const submitButton = await screen.findByRole("button", {
      name: /Create deploy campaign/i,
    });
    expect(submitButton).toBeEnabled();

    await userEvent.click(submitButton);

    await waitFor(() => expect(onSubmit).not.toHaveBeenCalled());

    const feedback = await screen.findByTestId(
      "missing-required-binds-feedback",
      {},
      { timeout: 5000 },
    );
    expect(feedback).toBeVisible();
    expect(feedback).toHaveTextContent(
      "Please configure a file source for all required file mounts.",
    );
    // The offending mountpoint is named, not just flagged in bulk.
    expect(feedback).toHaveTextContent("/opt/config.yaml");

    // Configuring the mount clears the feedback again.
    await pickRepositoryFile(relayEnvironment);

    await waitFor(
      () =>
        expect(
          screen.queryByTestId("missing-required-binds-feedback"),
        ).toBeNull(),
      { timeout: 5000 },
    );
  });

  // The release configures fileMode/userId/groupId on this mount, so the input
  // must surface them instead of showing an empty (Default) permission set.
  it("prefills the permissions configured on the release", async () => {
    await renderForm();
    await selectApplicationAndRelease();
    await screen.findByTestId("deployment-campaign-file-mounts");

    expect(screen.queryByText("(Default)")).not.toBeInTheDocument();
    expect(screen.getByText("0755")).toBeInTheDocument();

    await userEvent.click(screen.getByRole("button", { name: /customize/i }));
    expect(screen.getByLabelText(/owner user id/i)).toHaveValue(0);
    expect(screen.getByLabelText(/group id/i)).toHaveValue(0);
  });

  it("enables submit and sends the repository file id once a file is picked", async () => {
    const { relayEnvironment, onSubmit } = await renderForm();

    await selectApplicationAndRelease();
    await screen.findByTestId("deployment-campaign-file-mounts");
    await completeRequiredFields();

    await pickRepositoryFile(relayEnvironment);

    const submitButton = await screen.findByRole("button", {
      name: /Create deploy campaign/i,
    });
    await waitFor(() => expect(submitButton).toBeEnabled(), { timeout: 5000 });

    await userEvent.click(submitButton);

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));

    const payload = onSubmit.mock.calls[0][0];

    expect(payload.campaignMechanism.deploymentDeploy.configs).toEqual([
      {
        containerId: "container-1",
        envStrategy: "merge",
        fileBinds: [
          {
            fileMountId: "mount-1",
            fileId: "file-1",
            fileMode: 493,
            userId: 0,
            groupId: 0,
          },
        ],
      },
    ]);
    expect(payload.campaignMechanism.deploymentDeploy.releaseId).toBe("rel-1");
    expect(payload.channelId).toBe("channel-1");
  });

  it("shows the file mounts section for upgrade campaigns", async () => {
    await renderForm();
    await selectOperationType("Upgrade");
    await selectApplicationAndRelease();

    expect(
      await screen.findByTestId("deployment-campaign-file-mounts"),
    ).toBeInTheDocument();
  });

  it("sends the repository file id for upgrade campaigns", async () => {
    const { relayEnvironment, onSubmit } = await renderForm();

    await selectOperationType("Upgrade");
    await selectApplicationAndRelease();
    await userEvent.selectOptions(
      screen.getByLabelText("Target release"),
      "rel-2",
    );
    await screen.findByTestId("deployment-campaign-file-mounts");
    await completeRequiredFields();
    await pickRepositoryFile(relayEnvironment);

    const submitButton = await screen.findByRole("button", {
      name: /Create upgrade campaign/i,
    });
    await waitFor(() => expect(submitButton).toBeEnabled(), { timeout: 5000 });
    await userEvent.click(submitButton);

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));

    expect(onSubmit.mock.calls[0][0].campaignMechanism).toEqual({
      deploymentUpgrade: expect.objectContaining({
        configs: [
          {
            containerId: "container-1",
            envStrategy: "merge",
            fileBinds: [
              {
                fileMountId: "mount-1",
                fileId: "file-1",
                fileMode: 493,
                userId: 0,
                groupId: 0,
              },
            ],
          },
        ],
      }),
    });
  });

  // Operations without configs have nothing to configure on the device, so an
  // unconfigured required mount must not block them.
  it.each(["Start", "Stop", "Delete"])(
    "submits a %s campaign with a required mount left unconfigured",
    async (operationType) => {
      const { onSubmit } = await renderForm();

      await selectOperationType(operationType);
      await selectApplicationAndRelease();
      await completeRequiredFields();

      expect(
        screen.queryByTestId("deployment-campaign-file-mounts"),
      ).not.toBeInTheDocument();

      await userEvent.click(
        screen.getByRole("button", {
          name: new RegExp(
            `Create ${operationType.toLowerCase()} campaign`,
            "i",
          ),
        }),
      );

      await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));

      const [mechanism] = Object.values(
        onSubmit.mock.calls[0][0].campaignMechanism,
      );
      expect(mechanism).not.toHaveProperty("configs");
      expect(
        screen.queryByTestId("missing-required-binds-feedback"),
      ).not.toBeInTheDocument();
    },
  );

  it("hides the file mounts section for non deploy operations", async () => {
    await renderForm();
    await selectApplicationAndRelease();
    await screen.findByTestId("deployment-campaign-file-mounts");

    await selectOperationType("Start");

    await waitFor(() =>
      expect(
        screen.queryByTestId("deployment-campaign-file-mounts"),
      ).not.toBeInTheDocument(),
    );
  });

  it("preserves default file mount permissions in campaign configs", async () => {
    const { relayEnvironment, onSubmit } = await renderForm();

    await selectApplicationAndRelease("rel-2");
    await screen.findByTestId("deployment-campaign-file-mounts");
    await completeRequiredFields();

    await pickRepositoryFile(relayEnvironment);

    const submitButton = await screen.findByRole("button", {
      name: /Create deploy campaign/i,
    });
    await waitFor(() => expect(submitButton).toBeEnabled(), { timeout: 5000 });

    await userEvent.click(submitButton);

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));

    const payload = onSubmit.mock.calls[0][0];

    expect(payload.campaignMechanism.deploymentDeploy.configs).toEqual([
      {
        containerId: "container-2",
        envStrategy: "merge",
        fileBinds: [
          {
            fileMountId: "mount-2",
            fileId: "file-1",
            fileMode: 420,
            userId: 1000,
            groupId: 1001,
          },
        ],
      },
    ]);
  });

  it("updates file bind permissions when customized", async () => {
    const { relayEnvironment, onSubmit } = await renderForm();

    await selectApplicationAndRelease("rel-1");
    await screen.findByTestId("deployment-campaign-file-mounts");
    await completeRequiredFields();

    await pickRepositoryFile(relayEnvironment);

    const customizeButton = await screen.findByRole(
      "button",
      { name: "Customize" },
      { timeout: 5000 },
    );
    await userEvent.click(customizeButton);

    const uidInput = await screen.findByLabelText(
      /Owner User ID/i,
      {},
      { timeout: 5000 },
    );
    await userEvent.clear(uidInput);
    await userEvent.type(uidInput, "1234");

    const submitButton = await screen.findByRole("button", {
      name: /Create deploy campaign/i,
    });
    await waitFor(() => expect(submitButton).toBeEnabled(), { timeout: 5000 });

    await userEvent.click(submitButton);

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));

    const payload = onSubmit.mock.calls[0][0];

    expect(payload.campaignMechanism.deploymentDeploy.configs).toEqual([
      {
        containerId: "container-1",
        envStrategy: "merge",
        fileBinds: [
          {
            fileMountId: "mount-1",
            fileId: "file-1",
            fileMode: 493,
            userId: 1234,
            groupId: 0,
          },
        ],
      },
    ]);
  });
});
