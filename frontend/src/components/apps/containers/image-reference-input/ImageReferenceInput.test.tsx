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

import { zodResolver } from "@hookform/resolvers/zod";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useForm } from "react-hook-form";
import { describe, expect, it } from "vitest";

import { mapContainerToFormData } from "@/components/apps/containers/reuse-container-modal/ReuseContainerModal";
import {
  containerSchema,
  imageSchema,
  type ContainerInputData,
} from "@/forms/validation";
import { renderWithProviders } from "@/setupTests";
import ImageReferenceInput from "./ImageReferenceInput";

const VALID_DIGEST =
  "sha256:4c0fdaa8b6341bfdeca5f18f7837462c80cff90527ee35ef185571e1c327beac";

const TestFormWrapper = ({
  defaultValues = { name: "test-container" },
}: {
  defaultValues?: Partial<ContainerInputData>;
}) => {
  const form = useForm<ContainerInputData>({
    mode: "onTouched",
    resolver: zodResolver(containerSchema) as never,
    defaultValues,
  });

  return <ImageReferenceInput form={form} />;
};

describe("imageSchema validation", () => {
  it("accepts minimal image and full discrete segments", () => {
    expect(imageSchema.safeParse({ image: "nginx" }).success).toBe(true);

    const parsed = imageSchema.safeParse({
      registryHost: "registry.example.com",
      registryPort: 5000,
      repository: "my-org/backend",
      image: "api",
      tag: "1.2.3-alpine",
      imageCredentialsId: "cred-1",
    });
    expect(parsed.success).toBe(true);
  });

  it("rejects blank or missing image name", () => {
    expect(imageSchema.safeParse({ image: "" }).success).toBe(false);
    expect(imageSchema.safeParse({ image: "   " }).success).toBe(false);
  });

  it("rejects registryPort outside 1..65535 or without registryHost", () => {
    expect(
      imageSchema.safeParse({
        registryHost: "localhost",
        registryPort: 0,
        image: "nginx",
      }).success,
    ).toBe(false);

    expect(
      imageSchema.safeParse({
        registryHost: "localhost",
        registryPort: 65536,
        image: "nginx",
      }).success,
    ).toBe(false);

    const missingHost = imageSchema.safeParse({
      registryPort: 5000,
      image: "nginx",
    });
    expect(missingHost.success).toBe(false);
    if (!missingHost.success) {
      expect(missingHost.error.issues[0].path).toEqual(["registryPort"]);
    }
  });

  it("validates tag and digest formats and mutual exclusivity", () => {
    expect(
      imageSchema.safeParse({
        image: "nginx",
        tag: "-invalid-tag",
      }).success,
    ).toBe(false);

    expect(
      imageSchema.safeParse({
        image: "nginx",
        digest: "sha256:short",
      }).success,
    ).toBe(false);

    expect(
      imageSchema.safeParse({
        image: "nginx",
        digest: VALID_DIGEST,
      }).success,
    ).toBe(true);

    const bothSet = imageSchema.safeParse({
      image: "nginx",
      tag: "latest",
      digest: VALID_DIGEST,
    });
    expect(bothSet.success).toBe(false);
    if (!bothSet.success) {
      expect(bothSet.error.issues[0].path).toEqual(["digest"]);
    }
  });
});

describe("ImageReferenceInput", () => {
  it("updates live reference preview and manages registryPort disabled state", async () => {
    const user = userEvent.setup();
    renderWithProviders(<TestFormWrapper />);

    const hostInput = screen.getByLabelText("Registry Host");
    const portInput = screen.getByLabelText("Registry Port");
    const repoInput = screen.getByLabelText("Repository");
    const imageInput = screen.getByLabelText("Image Name");
    const versionInput = screen.getByPlaceholderText("e.g. latest");
    const previewInput = screen.getByTestId("image-reference-preview");

    expect(portInput).toBeDisabled();
    expect(previewInput).toHaveValue("");

    await user.type(imageInput, "nginx");
    expect(previewInput).toHaveValue("nginx");

    await user.type(hostInput, "registry.local");
    expect(portInput).not.toBeDisabled();

    await user.type(portInput, "5000");
    await user.type(repoInput, "library");
    await user.type(versionInput, "1.25");

    expect(previewInput).toHaveValue("registry.local:5000/library/nginx:1.25");

    await user.clear(hostInput);
    expect(portInput).toBeDisabled();
    expect(previewInput).toHaveValue("library/nginx:1.25");
  });

  it("switches between Tag and Digest modes and clears the inactive field", async () => {
    const user = userEvent.setup();
    renderWithProviders(<TestFormWrapper />);

    const imageInput = screen.getByLabelText("Image Name");
    const tagButton = screen.getByRole("button", { name: "Tag" });
    const digestButton = screen.getByRole("button", { name: "Digest" });
    const previewInput = screen.getByTestId("image-reference-preview");

    await user.type(imageInput, "busybox");
    const tagInput = screen.getByPlaceholderText("e.g. latest");
    await user.type(tagInput, "1.36");
    expect(previewInput).toHaveValue("busybox:1.36");

    await user.click(digestButton);
    expect(digestButton).toHaveAttribute("aria-pressed", "true");
    expect(previewInput).toHaveValue("busybox");

    const digestInput = screen.getByPlaceholderText(/sha256:/);
    await user.type(digestInput, VALID_DIGEST);
    expect(previewInput).toHaveValue(`busybox@${VALID_DIGEST}`);

    await user.click(tagButton);
    expect(tagButton).toHaveAttribute("aria-pressed", "true");
    expect(previewInput).toHaveValue("busybox");
  });

  it("initializes in Digest mode when initialData has a digest", () => {
    renderWithProviders(
      <TestFormWrapper
        defaultValues={{
          name: "digest-container",
          image: {
            image: "alpine",
            digest: VALID_DIGEST,
          },
        }}
      />,
    );

    const digestButton = screen.getByRole("button", { name: "Digest" });
    expect(digestButton).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByTestId("image-reference-preview")).toHaveValue(
      `alpine@${VALID_DIGEST}`,
    );
  });
});

describe("mapContainerToFormData", () => {
  it("maps discrete image segments and credentials from GraphQL fragment", () => {
    const mapped = mapContainerToFormData(
      {
        id: "container-1",
        name: "my-container",
        image: {
          registryHost: "ghcr.io",
          registryPort: 443,
          repository: "seco",
          image: "edgehog",
          tag: "0.14.0",
          digest: null,
          credentials: {
            id: "cred-123",
            label: "GHCR",
            username: "bot",
          },
        },
      } as never,
      true,
    );

    expect(mapped.name).toBe("my-container");
    expect(mapped.image).toEqual({
      registryHost: "ghcr.io",
      registryPort: 443,
      repository: "seco",
      image: "edgehog",
      tag: "0.14.0",
      digest: undefined,
      imageCredentialsId: "cred-123",
    });
  });
});
