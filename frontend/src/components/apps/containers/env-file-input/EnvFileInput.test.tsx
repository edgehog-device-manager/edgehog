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

import { it, expect, vi } from "vitest";
import { act, screen } from "@testing-library/react";
import selectEvent from "react-select-event";
import { createMockEnvironment } from "relay-test-utils";

import { renderWithProviders } from "@/setupTests";
import EnvFileInput, { EnvFileInputRef, EnvFileResult } from "./EnvFileInput";

const renderInput = ({
  deviceFiles = [
    { id: "device-file-1", pathOnDevice: "/data/.env", deleted: false },
  ],
  fileDownloadRequests = [],
}: {
  deviceFiles?: { id: string; pathOnDevice: string; deleted: boolean }[];
  fileDownloadRequests?: never[];
} = {}) => {
  const relayEnvironment = createMockEnvironment();
  const ref = vi.fn<(instance: EnvFileInputRef | null) => void>();

  let refValue: EnvFileInputRef | null = null;
  const refCallback = (instance: EnvFileInputRef | null) => {
    refValue = instance;
    ref(instance);
  };

  renderWithProviders(
    <EnvFileInput
      ref={refCallback}
      containerId="container-1"
      deviceId="device-1"
      deviceFiles={deviceFiles}
      fileDownloadRequests={fileDownloadRequests}
    />,
    { relayEnvironment },
  );

  return {
    relayEnvironment,
    getRef: () => refValue as EnvFileInputRef | null,
  };
};

const getSpec = async (
  getRef: () => EnvFileInputRef | null,
): Promise<EnvFileResult | null> => {
  let result: EnvFileResult | null = null;
  await act(async () => {
    result = (await getRef()?.getEnvFileSpec()) ?? null;
  });
  return result;
};

it("renders unconfigured and yields no spec", async () => {
  const { getRef } = renderInput();

  expect(await screen.findByText("Env file")).toBeVisible();
  expect(getRef()?.isValid()).toBe(true);
  expect(await getSpec(getRef)).toBeNull();
});

it("yields a device file spec once a device file is selected", async () => {
  const { getRef } = renderInput();

  await screen.findByText("Env file");

  const [combobox] = screen.getAllByRole("combobox");
  await selectEvent.select(combobox, "Device File: /data/.env", {
    container: document.body,
  });

  expect(await getSpec(getRef)).toEqual({
    spec: {
      deviceFileId: "device-file-1",
    },
  });
});
