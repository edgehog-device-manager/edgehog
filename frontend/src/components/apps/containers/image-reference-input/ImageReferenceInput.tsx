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

import { useEffect, useState } from "react";
import { ButtonGroup } from "react-bootstrap";
import { useWatch, type UseFormReturn } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import Button from "@/components/ui/button/Button";
import FieldHelp from "@/components/ui/field-help/FieldHelp";
import Form from "@/components/ui/form/Form";
import { FormRow } from "@/components/ui/form-row/FormRow";
import FormFeedback from "@/forms/FormFeedback";
import type { ContainerInputData } from "@/forms/validation";

type ImageSegments = {
  registryHost?: string | null;
  registryPort?: number | string | null;
  repository?: string | null;
  image?: string | null;
  tag?: string | null;
  digest?: string | null;
};

const formatImageReference = (segments?: ImageSegments | null): string => {
  const image = segments?.image?.trim() ?? "";
  if (!image) {
    return "";
  }

  const host = segments?.registryHost?.trim() ?? "";
  const portRaw = segments?.registryPort;
  const port =
    portRaw !== undefined &&
    portRaw !== null &&
    String(portRaw).trim() !== "" &&
    !Number.isNaN(Number(portRaw))
      ? Number(portRaw)
      : undefined;

  const registryPart = host
    ? port !== undefined
      ? `${host}:${port}/`
      : `${host}/`
    : "";

  const repo = segments?.repository?.trim() ?? "";
  const repoPart = repo ? `${repo}/` : "";

  const digest = segments?.digest?.trim() ?? "";
  const tag = segments?.tag?.trim() ?? "";
  const versionPart = digest ? `@${digest}` : tag ? `:${tag}` : "";

  return `${registryPart}${repoPart}${image}${versionPart}`;
};

export type ImageReferenceInputProps = {
  form: UseFormReturn<ContainerInputData>;
};

const ImageReferenceInput = ({ form }: ImageReferenceInputProps) => {
  const {
    register,
    control,
    setValue,
    formState: { errors },
  } = form;

  const watchedImage = useWatch({
    control,
    name: "image",
  });

  const [selectedMode, setSelectedMode] = useState<"tag" | "digest">("tag");

  const versionMode: "tag" | "digest" =
    watchedImage?.digest && !watchedImage?.tag
      ? "digest"
      : watchedImage?.tag && !watchedImage?.digest
        ? "tag"
        : selectedMode;

  const hasRegistryHost = Boolean(watchedImage?.registryHost?.trim());

  useEffect(() => {
    if (!hasRegistryHost && watchedImage?.registryPort !== undefined) {
      setValue("image.registryPort", undefined, { shouldValidate: true });
    }
  }, [hasRegistryHost, watchedImage?.registryPort, setValue]);

  const handleSelectTag = () => {
    setSelectedMode("tag");
    if (watchedImage?.digest) {
      setValue("image.digest", "", {
        shouldDirty: true,
        shouldValidate: true,
      });
    }
  };

  const handleSelectDigest = () => {
    setSelectedMode("digest");
    if (watchedImage?.tag) {
      setValue("image.tag", "", {
        shouldDirty: true,
        shouldValidate: true,
      });
    }
  };

  const computedReference = formatImageReference(watchedImage);

  return (
    <>
      <FormRow
        id="image-registry-host"
        label={
          <FormattedMessage
            id="components.apps.containers.image-reference-input.ImageReferenceInput.registryHostLabel"
            defaultMessage="Registry Host"
          />
        }
      >
        <FieldHelp id="imageRegistryHost">
          <Form.Control
            placeholder="e.g. docker.io"
            {...register("image.registryHost")}
            isInvalid={!!errors.image?.registryHost}
          />
          <FormFeedback feedback={errors.image?.registryHost?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="image-registry-port"
        label={
          <FormattedMessage
            id="components.apps.containers.image-reference-input.ImageReferenceInput.registryPortLabel"
            defaultMessage="Registry Port"
          />
        }
      >
        <FieldHelp id="imageRegistryPort">
          <Form.Control
            type="text"
            placeholder="e.g. 5000"
            disabled={!hasRegistryHost}
            {...register("image.registryPort", {
              setValueAs: (v: unknown) =>
                v === "" || v === null || v === undefined
                  ? undefined
                  : Number(v),
            })}
            isInvalid={!!errors.image?.registryPort}
          />
          <FormFeedback feedback={errors.image?.registryPort?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="image-repository"
        label={
          <FormattedMessage
            id="components.apps.containers.image-reference-input.ImageReferenceInput.repositoryLabel"
            defaultMessage="Repository"
          />
        }
      >
        <FieldHelp id="imageRepository">
          <Form.Control
            placeholder="e.g. library"
            {...register("image.repository")}
            isInvalid={!!errors.image?.repository}
          />
          <FormFeedback feedback={errors.image?.repository?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="image-name"
        label={
          <FormattedMessage
            id="components.apps.containers.image-reference-input.ImageReferenceInput.imageNameLabel"
            defaultMessage="Image Name"
          />
        }
      >
        <FieldHelp id="imageName">
          <Form.Control
            placeholder="e.g. nginx"
            {...register("image.image")}
            isInvalid={!!errors.image?.image}
          />
          <FormFeedback feedback={errors.image?.image?.message} />
        </FieldHelp>
      </FormRow>

      <FormRow
        id="image-version"
        label={
          <div className="d-flex align-items-center justify-content-between gap-2">
            <span>
              <FormattedMessage
                id="components.apps.containers.image-reference-input.ImageReferenceInput.versionLabel"
                defaultMessage="Image Version"
              />
            </span>
            <ButtonGroup size="sm" role="group" aria-label="Image version type">
              <Button
                type="button"
                variant={
                  versionMode === "tag" ? "primary" : "outline-secondary"
                }
                aria-pressed={versionMode === "tag"}
                onClick={handleSelectTag}
              >
                <FormattedMessage
                  id="components.apps.containers.image-reference-input.ImageReferenceInput.tagButton"
                  defaultMessage="Tag"
                />
              </Button>
              <Button
                type="button"
                variant={
                  versionMode === "digest" ? "primary" : "outline-secondary"
                }
                aria-pressed={versionMode === "digest"}
                onClick={handleSelectDigest}
              >
                <FormattedMessage
                  id="components.apps.containers.image-reference-input.ImageReferenceInput.digestButton"
                  defaultMessage="Digest"
                />
              </Button>
            </ButtonGroup>
          </div>
        }
      >
        {versionMode === "tag" ? (
          <FieldHelp id="imageTag">
            <Form.Control
              key="image-tag-input"
              placeholder="e.g. latest"
              {...register("image.tag")}
              isInvalid={!!errors.image?.tag}
            />
            <FormFeedback feedback={errors.image?.tag?.message} />
          </FieldHelp>
        ) : (
          <FieldHelp id="imageDigest">
            <Form.Control
              key="image-digest-input"
              placeholder="e.g. sha256:4c0fdaa8b6341bfdeca5f18f7837462c80cff90527ee35ef185571e1c327beac"
              {...register("image.digest")}
              isInvalid={!!errors.image?.digest}
            />
            <FormFeedback feedback={errors.image?.digest?.message} />
          </FieldHelp>
        )}
      </FormRow>

      <FormRow
        id="image-reference-preview"
        label={
          <FormattedMessage
            id="components.apps.containers.image-reference-input.ImageReferenceInput.referencePreviewLabel"
            defaultMessage="Reference Preview"
          />
        }
      >
        <Form.Control
          data-testid="image-reference-preview"
          className="font-monospace"
          value={computedReference}
          readOnly
        />
      </FormRow>
    </>
  );
};

export default ImageReferenceInput;
