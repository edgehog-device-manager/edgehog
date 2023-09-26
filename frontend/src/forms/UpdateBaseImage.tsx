/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import React, { useEffect, useMemo } from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { baseImageStartingVersionRequirementSchema, yup } from "forms";

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <Form.Group as={Row} controlId={id}>
    <Form.Label column sm={3}>
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

type BaseImageData = {
  baseImageCollection: {
    name: string;
  };
  version: string;
  url: string;
  startingVersionRequirement: string | null;
  releaseDisplayName: string | null;
  description: string | null;
};

type FormData = {
  baseImageCollection: string;
  version: string;
  startingVersionRequirement: string;
  releaseDisplayName: string;
  description: string;
};

type BaseImageChanges = {
  startingVersionRequirement: string;
  releaseDisplayName: {
    locale: string;
    text: string;
  };
  description: {
    locale: string;
    text: string;
  };
};

const baseImageSchema = yup
  .object({
    startingVersionRequirement: baseImageStartingVersionRequirementSchema,
    releaseDisplayName: yup.string(),
    description: yup.string(),
  })
  .required();

const transformOutputData = (
  locale: string,
  data: FormData,
): BaseImageChanges => ({
  startingVersionRequirement: data.startingVersionRequirement,
  releaseDisplayName: {
    locale,
    text: data.releaseDisplayName,
  },
  description: {
    locale,
    text: data.description,
  },
});

type UpdateBaseImageProps = {
  baseImage: BaseImageData;
  locale: string;
  isLoading?: boolean;
  onSubmit: (data: BaseImageChanges) => void;
  onDelete: () => void;
};

const UpdateBaseImage = ({
  baseImage,
  locale,
  isLoading = false,
  onSubmit,
  onDelete,
}: UpdateBaseImageProps) => {
  const defaultValues = useMemo(
    () => ({
      baseImageCollection: baseImage.baseImageCollection.name,
      version: baseImage.version,
      startingVersionRequirement: baseImage.startingVersionRequirement || "",
      releaseDisplayName: baseImage.releaseDisplayName || "",
      description: baseImage.description || "",
    }),
    [baseImage],
  );

  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues,
    resolver: yupResolver(baseImageSchema),
  });

  useEffect(() => {
    reset(defaultValues);
  }, [reset, defaultValues]);

  const onFormSubmit = (data: FormData) =>
    onSubmit(transformOutputData(locale, data));

  const canSubmit = !isLoading && isDirty;

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="update-base-image-form-base-image-collection"
          label={
            <FormattedMessage
              id="forms.UpdateBaseImage.baseImageCollectionLabel"
              defaultMessage="Base Image Collection"
            />
          }
        >
          <Form.Control
            {...register("baseImageCollection")}
            plaintext
            readOnly
          />
        </FormRow>
        <FormRow
          id="update-base-image-form-file"
          label={
            <FormattedMessage
              id="forms.UpdateBaseImage.fileLabel"
              defaultMessage="Base Image file"
            />
          }
        >
          <FormattedMessage
            id="forms.UpdateBaseImage.file"
            defaultMessage="<a>{baseImageName}</a>"
            values={{
              a: (chunks: React.ReactNode) => (
                <a target="_blank" rel="noreferrer" href={baseImage.url}>
                  {chunks}
                </a>
              ),
              baseImageName: baseImage.url.split("/").pop(),
            }}
          />
        </FormRow>
        <FormRow
          id="update-base-image-form-version"
          label={
            <FormattedMessage
              id="forms.UpdateBaseImage.versionLabel"
              defaultMessage="Version"
            />
          }
        >
          <Form.Control {...register("version")} plaintext readOnly />
        </FormRow>
        <FormRow
          id="update-base-image-form-starting-version-requirement"
          label={
            <FormattedMessage
              id="forms.UpdateBaseImage.starting-version-requirementLabel"
              defaultMessage="Supported starting versions"
            />
          }
        >
          <Form.Control
            {...register("startingVersionRequirement")}
            isInvalid={!!errors.startingVersionRequirement}
          />
          <Form.Control.Feedback type="invalid">
            {errors.startingVersionRequirement?.message && (
              <FormattedMessage
                id={errors.startingVersionRequirement?.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="update-base-image-form-release-display-name"
          label={
            <>
              <FormattedMessage
                id="forms.UpdateBaseImage.releaseDisplayNameLabel"
                defaultMessage="Release Display Name"
              />
              <span className="small text-muted"> ({locale})</span>
            </>
          }
        >
          <Form.Control {...register("releaseDisplayName")} />
        </FormRow>
        <FormRow
          id="update-base-image-form-description"
          label={
            <>
              <FormattedMessage
                id="forms.UpdateBaseImage.descriptionLabel"
                defaultMessage="Description"
              />
              <span className="small text-muted"> ({locale})</span>
            </>
          }
        >
          <Form.Control as="textarea" {...register("description")} />
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Stack direction="horizontal" gap={3}>
            <Button variant="primary" type="submit" disabled={!canSubmit}>
              {isLoading && <Spinner size="sm" className="me-2" />}
              <FormattedMessage
                id="forms.UpdateBaseImage.submitButton"
                defaultMessage="Update"
              />
            </Button>
            <Button variant="danger" onClick={onDelete}>
              <FormattedMessage
                id="forms.UpdateBaseImage.deleteButton"
                defaultMessage="Delete"
              />
            </Button>
          </Stack>
        </div>
      </Stack>
    </form>
  );
};

export type { BaseImageData, BaseImageChanges };

export default UpdateBaseImage;
