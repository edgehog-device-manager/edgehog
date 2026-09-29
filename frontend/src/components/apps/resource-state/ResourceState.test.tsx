// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { it, expect } from "vitest";
import { screen, render } from "@testing-library/react";

import ResourceState from "./ResourceState";

it("renders ready state in green when isReady", () => {
  render(<ResourceState state="RUNNING" isReady={true} />);
  const el = screen.getByText("RUNNING");
  expect(el).toBeInTheDocument();
  expect(el.className).toContain("font-monospace");
  expect(el.className).toContain("fw-bold");
  expect(el.className).toContain("text-uppercase");
  expect(el.className).toContain("small");
  expect(el.className).toContain("text-success");
  expect(el.className).toContain("ms-auto");
});

it("renders not-ready state in muted color when not ready", () => {
  render(<ResourceState state="CREATED" isReady={false} />);
  const el = screen.getByText("CREATED");
  expect(el).toBeInTheDocument();
  expect(el.className).toContain("text-body-tertiary");
});

it("renders error state in red", () => {
  render(<ResourceState state="ERROR" isReady={false} />);
  const el = screen.getByText("ERROR");
  expect(el).toBeInTheDocument();
  expect(el.className).toContain("text-danger");
});

it("renders nothing when state is missing and not ready", () => {
  const { container } = render(
    <ResourceState state={undefined} isReady={null} />,
  );
  expect(container).toBeEmptyDOMElement();
});

it("renders READY when state is missing but isReady is true", () => {
  render(<ResourceState state={null} isReady={true} />);
  const el = screen.getByText("READY");
  expect(el).toBeInTheDocument();
  expect(el.className).toContain("text-success");
});
