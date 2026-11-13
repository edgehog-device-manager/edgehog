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

import { describe, expect, it } from "vitest";
import { screen } from "@testing-library/react";
import selectEvent from "react-select-event";

import { renderWithProviders } from "@/setupTests";
import type { Event } from "@/components/apps/deployments/deployment-details/DeploymentDetails";
import DeploymentEventsCard from "./DeploymentEventsCard";

const SAMPLE_EVENTS: Event[] = [
  {
    __typename: "DeploymentEvent",
    resourceId: "dep-1",
    status: "STARTED",
    message: "Deployment started",
    addInfo: [],
    timestamp: "2026-01-01T10:07:00.000Z",
  },
  {
    __typename: "ContainerDeploymentEvent",
    resourceId: "cnt-1",
    status: "OOM",
    message: "Container ran out of memory",
    addInfo: ["exitCode=137"],
    timestamp: "2026-01-01T10:06:00.000Z",
  },
  {
    __typename: "ImageDeploymentEvent",
    resourceId: "img-1",
    status: "PULL",
    message: "Pulled image nginx:latest",
    addInfo: [],
    timestamp: "2026-01-01T10:05:00.000Z",
  },
  {
    __typename: "VolumeDeploymentEvent",
    resourceId: "vol-1",
    status: "MOUNT",
    message: "Mounted volume data",
    addInfo: [],
    timestamp: "2026-01-01T10:04:00.000Z",
  },
  {
    __typename: "NetworkDeploymentEvent",
    resourceId: "net-1",
    status: "CONNECT",
    message: "Connected container to network",
    addInfo: [],
    timestamp: "2026-01-01T10:03:00.000Z",
  },
  {
    __typename: "EnvFileEvent",
    resourceId: "env-1",
    status: "ERROR",
    message: "Failed to write env file",
    addInfo: [],
    timestamp: "2026-01-01T10:02:00.000Z",
  },
  {
    __typename: "FileBindEvent",
    resourceId: "fb-1",
    status: "ERROR",
    message: "",
    addInfo: [],
    timestamp: "2026-01-01T10:01:00.000Z",
  },
];

describe("DeploymentEventsCard", () => {
  it("renders events from all 7 resource types with badges and messages", () => {
    renderWithProviders(<DeploymentEventsCard events={SAMPLE_EVENTS} />);

    const resourceBadges = screen.getAllByTestId("event-resource-type");
    expect(resourceBadges.map((el) => el.textContent)).toEqual([
      "Deployment",
      "Container",
      "Image",
      "Volume",
      "Network",
      "Env File",
      "File Bind",
    ]);

    const statusBadges = screen.getAllByTestId("event-status-type");
    expect(statusBadges.map((el) => el.textContent)).toEqual([
      "Started",
      "Out of Memory",
      "Pull",
      "Mount",
      "Connect",
      "Error",
      "Error",
    ]);

    expect(screen.getByText("Deployment started")).toBeVisible();
    expect(screen.getByText("Container ran out of memory")).toBeVisible();
    expect(screen.getByText("Pulled image nginx:latest")).toBeVisible();
    expect(screen.getByText("Mounted volume data")).toBeVisible();
    expect(screen.getByText("Connected container to network")).toBeVisible();
    expect(screen.getByText("Failed to write env file")).toBeVisible();
    expect(screen.getByText("No message in event.")).toBeVisible();
  });

  it("filters events by resource type", async () => {
    renderWithProviders(<DeploymentEventsCard events={SAMPLE_EVENTS} />);

    const [resourceTypeInput] = screen.getAllByRole("combobox");
    await selectEvent.select(resourceTypeInput, "Image");

    expect(screen.getByText("Pulled image nginx:latest")).toBeVisible();
    expect(screen.queryByText("Deployment started")).not.toBeInTheDocument();
    expect(
      screen.queryByText("Container ran out of memory"),
    ).not.toBeInTheDocument();
  });

  it("filters events by event status", async () => {
    renderWithProviders(<DeploymentEventsCard events={SAMPLE_EVENTS} />);

    const [, eventTypeInput] = screen.getAllByRole("combobox");
    await selectEvent.select(eventTypeInput, "Error");

    expect(screen.getByText("Failed to write env file")).toBeVisible();
    expect(screen.getByText("No message in event.")).toBeVisible();
    expect(screen.queryByText("Deployment started")).not.toBeInTheDocument();
    expect(
      screen.queryByText("Pulled image nginx:latest"),
    ).not.toBeInTheDocument();
  });

  it("combines resource type and event status filters and prunes incompatible statuses", async () => {
    renderWithProviders(<DeploymentEventsCard events={SAMPLE_EVENTS} />);

    const [resourceTypeInput, eventTypeInput] = screen.getAllByRole("combobox");

    await selectEvent.select(resourceTypeInput, ["Env File", "Image"]);
    await selectEvent.select(eventTypeInput, "Error");

    expect(screen.getByText("Failed to write env file")).toBeVisible();
    expect(
      screen.queryByText("Pulled image nginx:latest"),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("No message in event.")).not.toBeInTheDocument();
  });
});
