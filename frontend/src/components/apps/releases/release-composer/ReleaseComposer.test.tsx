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

import { describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import type { CreateReleaseInput } from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";
import type { ReleaseCreate_getOptions_Query } from "@/api/__generated__/ReleaseCreate_getOptions_Query.graphql";

import { renderWithProviders } from "@/setupTests";

import ReleaseComposer from "./ReleaseComposer";

vi.mock("@/components/ui/monaco-editor/MonacoEditor", () => ({
  default: ({
    value,
    language,
    onChange,
  }: {
    value: string;
    language?: string;
    onChange?: (text?: string) => void;
  }) => (
    <textarea
      data-testid={`editor-${language ?? "default"}`}
      value={value}
      onChange={(event) => onChange?.(event.target.value)}
    />
  ),
}));

const GET_OPTIONS_QUERY = graphql`
  query ReleaseComposer_getOptions_Test_Query($applicationId: ID!)
  @relay_test_operation {
    application(id: $applicationId) {
      name
    }
    ...hooks_SystemModelsOptionsFragment
    ...hooks_NetworksOptionsFragment
    ...hooks_VolumesOptionsFragment
    ...hooks_ImageCredentialsOptionsFragment
  }
`;

const ComponentWithQuery = ({
  onSubmit,
}: {
  onSubmit: (release: CreateReleaseInput) => void;
}) => {
  const data = useLazyLoadQuery<ReleaseCreate_getOptions_Query>(
    GET_OPTIONS_QUERY,
    { applicationId: "app-1" },
  );

  return (
    <ReleaseComposer queryRef={data} onSubmit={onSubmit} isLoading={false} />
  );
};

const renderComposer = () => {
  const relayEnvironment = createMockEnvironment();
  const onSubmit = vi.fn();

  relayEnvironment.mock.queueOperationResolver(() => ({
    errors: undefined,
    data: {
      application: { id: "app-1", name: "My App" },
      systemModels: { edges: [] },
      networks: { edges: [] },
      volumes: { edges: [] },
      listImageCredentials: { edges: [] },
    },
  }));

  relayEnvironment.mock.queuePendingOperation(GET_OPTIONS_QUERY, {
    applicationId: "app-1",
  });

  renderWithProviders(<ComponentWithQuery onSubmit={onSubmit} />, {
    relayEnvironment,
  });

  return { onSubmit };
};

const addContainer = () =>
  fireEvent.click(screen.getByRole("button", { name: /add container/i }));

const getYamlEditor = () =>
  screen.getByTestId("editor-yaml") as HTMLTextAreaElement;

const getNameInputs = () =>
  screen.getAllByLabelText("Container Name") as HTMLInputElement[];

describe("ReleaseComposer sync", () => {
  it("updates the YAML when adding a container", () => {
    renderComposer();

    expect(getYamlEditor().value).toBe("services: {}\n");

    addContainer();

    expect(getYamlEditor().value).not.toBe("services: {}\n");
    expect(getYamlEditor().value).toContain('""');
  });

  it("updates the YAML when editing the form", () => {
    renderComposer();

    addContainer();

    fireEvent.change(getNameInputs()[0], { target: { value: "web" } });
    fireEvent.change(screen.getByLabelText("Image Reference"), {
      target: { value: "nginx:1.27" },
    });

    expect(getYamlEditor().value).toContain("web");
    expect(getYamlEditor().value).toContain("nginx:1.27");
  });

  it("updates the panes when editing the YAML without rewriting the buffer", () => {
    renderComposer();

    const userYaml = [
      "services:",
      "    web:",
      "        image: nginx:1.27",
      "",
    ].join("\n");

    fireEvent.change(getYamlEditor(), { target: { value: userYaml } });

    expect(screen.getByText("web")).toBeInTheDocument();
    expect(
      (screen.getByLabelText("Image Reference") as HTMLInputElement).value,
    ).toBe("nginx:1.27");
    expect(getYamlEditor().value).toBe(userYaml);
  });

  it("converges immediately when form and YAML edits alternate", () => {
    renderComposer();

    addContainer();

    fireEvent.change(getNameInputs()[0], { target: { value: "api" } });

    expect(getYamlEditor().value).toContain("api");

    const userYaml = [
      "services:",
      "    worker:",
      "        image: busybox:1.36",
      "",
    ].join("\n");

    fireEvent.change(getYamlEditor(), { target: { value: userYaml } });

    expect(screen.getByText("worker")).toBeInTheDocument();
    expect(
      (screen.getByLabelText("Image Reference") as HTMLInputElement).value,
    ).toBe("busybox:1.36");
  });

  it("drops echoes of YAML-driven resets instead of rewriting the YAML", () => {
    renderComposer();

    const userYaml = [
      "services:",
      "    web:",
      "        image: nginx:1.27",
      "        ports:",
      '            - "8080:80"',
      "",
    ].join("\n");

    fireEvent.change(getYamlEditor(), { target: { value: userYaml } });

    expect(screen.getByText("web")).toBeInTheDocument();
    expect(getYamlEditor().value).toBe(userYaml);

    fireEvent.change(getNameInputs()[0], { target: { value: "frontend" } });

    expect(getYamlEditor().value).toContain("frontend");
  });

  it("keeps unrelated panes undisturbed while editing the YAML", () => {
    renderComposer();

    fireEvent.change(getYamlEditor(), {
      target: {
        value:
          "services:\n  web:\n    image: nginx:1.27\n  api:\n    image: myorg/api:2.0.0\n",
      },
    });

    const webName = getNameInputs()[0];

    webName.focus();
    expect(webName).toHaveFocus();

    fireEvent.change(getYamlEditor(), {
      target: {
        value:
          "services:\n  web:\n    image: nginx:1.27\n  api:\n    image: myorg/api:3.0.0\n",
      },
    });

    expect(webName).toHaveFocus();
    expect(webName.value).toBe("web");
    expect(getYamlEditor().value).toContain("myorg/api:3.0.0");
  });

  it("updates the YAML when removing a container", () => {
    renderComposer();

    fireEvent.change(getYamlEditor(), {
      target: {
        value:
          "services:\n  web:\n    image: nginx:1.27\n  api:\n    image: myorg/api:2.0.0\n",
      },
    });

    expect(screen.getAllByTitle("Remove")).toHaveLength(2);

    fireEvent.click(screen.getAllByTitle("Remove")[1]);

    expect(getYamlEditor().value).toContain("web");
    expect(getYamlEditor().value).not.toContain("api");
  });

  it("submits the state matching the visible YAML", () => {
    const { onSubmit } = renderComposer();

    addContainer();

    fireEvent.change(getNameInputs()[0], { target: { value: "web" } });
    fireEvent.change(screen.getByLabelText("Image Reference"), {
      target: { value: "nginx:1.26" },
    });

    expect(getYamlEditor().value).toContain("nginx:1.26");

    fireEvent.change(getYamlEditor(), {
      target: {
        value: "services:\n  web:\n    image: nginx:1.27\n",
      },
    });

    fireEvent.change(screen.getByLabelText("Release Version"), {
      target: { value: "1.0.0" },
    });
    fireEvent.click(screen.getByRole("button", { name: /create release/i }));

    expect(onSubmit).toHaveBeenCalledTimes(1);

    const release = onSubmit.mock.calls[0][0] as CreateReleaseInput;

    expect(release.version).toBe("1.0.0");
    expect(release.containers ?? []).toHaveLength(1);

    const [container] = release.containers ?? [];

    expect(container?.name).toBe("web");
    expect(container?.image?.reference).toBe("nginx:1.27");
  });
});

describe("ReleaseComposer collapsible panes", () => {
  const toggleFirstPane = () =>
    fireEvent.click(screen.getAllByTitle("Toggle container details")[0]);

  it("collapses and expands a container pane", async () => {
    renderComposer();

    addContainer();

    const imageInput = screen.getByLabelText("Image Reference");
    const paneBody = () => screen.getByTestId("service-pane-body");

    // react-bootstrap Collapse: open = "collapse show"
    expect(paneBody()).toHaveClass("collapse", "show");
    expect(screen.getAllByTitle("Toggle container details")[0]).toHaveAttribute(
      "aria-expanded",
      "true",
    );

    toggleFirstPane();

    expect(screen.getAllByTitle("Toggle container details")[0]).toHaveAttribute(
      "aria-expanded",
      "false",
    );

    // settle the closing transition manually: jsdom emits no transitionend
    fireEvent.transitionEnd(paneBody());

    await waitFor(() => expect(paneBody()).toHaveClass("collapse"));
    await waitFor(() => expect(paneBody()).not.toHaveClass("show"));

    // content stays mounted while hidden
    expect(imageInput).toBeInTheDocument();

    toggleFirstPane();

    await waitFor(() => expect(paneBody()).toHaveClass("collapse", "show"));
  });

  it("still syncs YAML edits into a collapsed pane", () => {
    renderComposer();

    fireEvent.change(getYamlEditor(), {
      target: { value: "services:\n  web:\n    image: nginx:1.27\n" },
    });

    toggleFirstPane();

    fireEvent.change(getYamlEditor(), {
      target: { value: "services:\n  web:\n    image: nginx:1.28\n" },
    });

    toggleFirstPane();

    expect(
      (screen.getByLabelText("Image Reference") as HTMLInputElement).value,
    ).toBe("nginx:1.28");
  });

  it("removes a container while another pane is collapsed", () => {
    renderComposer();

    fireEvent.change(getYamlEditor(), {
      target: {
        value:
          "services:\n  web:\n    image: nginx:1.27\n  api:\n    image: myorg/api:2.0.0\n",
      },
    });

    toggleFirstPane();

    fireEvent.click(screen.getAllByTitle("Remove")[1]);

    expect(getYamlEditor().value).toContain("web");
    expect(getYamlEditor().value).not.toContain("api");

    toggleFirstPane();

    expect(
      (screen.getByLabelText("Image Reference") as HTMLInputElement).value,
    ).toBe("nginx:1.27");
  });

  it("shows the invalid badge only for incomplete containers", () => {
    renderComposer();

    addContainer();

    const badge = "This container has missing or invalid settings";

    expect(screen.getByTitle(badge)).toBeInTheDocument();

    fireEvent.change(getNameInputs()[0], { target: { value: "web" } });
    fireEvent.change(screen.getByLabelText("Image Reference"), {
      target: { value: "nginx:1.27" },
    });

    expect(screen.queryByTitle(badge)).not.toBeInTheDocument();
  });

  it("does not show the invalid badge for a complete valid YAML pasted in", () => {
    renderComposer();

    const badge = "This container has missing or invalid settings";

    expect(screen.queryByTitle(badge)).not.toBeInTheDocument();

    fireEvent.change(getYamlEditor(), {
      target: {
        value: "services:\n  nginx:\n    image: nginx:latest\n",
      },
    });

    expect(screen.getByText("nginx")).toBeInTheDocument();
    expect(screen.queryByTitle(badge)).not.toBeInTheDocument();
  });

  it("clears the invalid badge for a complete YAML after switching back to an incomplete one", () => {
    renderComposer();

    const badge = "This container has missing or invalid settings";

    fireEvent.change(getYamlEditor(), {
      target: {
        value: "services:\n  nginx:\n    image: nginx:latest\n",
      },
    });

    expect(screen.queryByTitle(badge)).not.toBeInTheDocument();

    fireEvent.change(getYamlEditor(), {
      target: {
        value: 'services:\n  nginx:\n    image: ""\n',
      },
    });

    expect(screen.getByTitle(badge)).toBeInTheDocument();
  });

  it("shows an error alert when the YAML is invalid", () => {
    renderComposer();

    expect(
      screen.queryByText(/Invalid docker-compose file:/i),
    ).not.toBeInTheDocument();

    fireEvent.change(getYamlEditor(), {
      target: {
        value: "services:\n  nginx: [unclosed",
      },
    });

    expect(
      screen.getByText(/Invalid docker-compose file:/i),
    ).toBeInTheDocument();
  });

  it("shows a warning alert when settings cannot be represented", () => {
    renderComposer();

    expect(
      screen.queryByText(/Some settings could not be represented:/i),
    ).not.toBeInTheDocument();

    fireEvent.change(getYamlEditor(), {
      target: {
        value:
          'services:\n  nginx:\n    image: nginx:latest\n    healthcheck:\n      test: ["CMD", "curl", "-f", "http://localhost"]\n',
      },
    });

    expect(
      screen.getByText(/Some settings could not be represented:/i),
    ).toBeInTheDocument();
  });
});
