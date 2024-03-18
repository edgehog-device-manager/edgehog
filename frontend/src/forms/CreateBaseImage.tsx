/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import React from "react";
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { yupResolver } from "@hookform/resolvers/yup";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import {
  baseImageFileSchema,
  baseImageVersionSchema,
  baseImageStartingVersionRequirementSchema,
  yup,
} from "forms";
import { graphql, useFragment } from "react-relay/hooks";
import type { CreateBaseImage_BaseImageCollectionFragment$key } from "api/__generated__/CreateBaseImage_BaseImageCollectionFragment.graphql";

const CREATE_BASE_IMAGE_FRAGMENT = graphql`
  fragment CreateBaseImage_BaseImageCollectionFragment on BaseImageCollection {
    id
    name
  }
`;

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
  baseImageCollectionId: string;
  file: File;
  version: string;
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

type FormData = {
  baseImageCollection: string;
  file: FileList | null;
  version: string;
  startingVersionRequirement: string;
  releaseDisplayName: string;
  description: string;
};

const baseImageSchema = yup
  .object({
    baseImageCollection: yup.string().required(),
    file: baseImageFileSchema.required(),
    version: baseImageVersionSchema.required(),
    startingVersionRequirement: baseImageStartingVersionRequirementSchema,
    releaseDisplayName: yup.string(),
    description: yup.string(),
  })
  .required();

const transformInputData = (
  baseImageCollection: BaseImageCollection,
): FormData => ({
  baseImageCollection: baseImageCollection.name,
  file: null,
  version: "",
  startingVersionRequirement: "",
  description: "",
  releaseDisplayName: "",
});

type FormOutput = FormData & {
  file: FileList;
};

const transformOutputData = (
  baseImageCollection: BaseImageCollection,
  locale: string,
  data: FormOutput,
): BaseImageData => ({
  baseImageCollectionId: baseImageCollection.id,
  file: data.file[0],
  version: data.version,
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

type BaseImageCollection = {
  id: string;
  name: string;
};

type Props = {
  baseImageCollectionRef: CreateBaseImage_BaseImageCollectionFragment$key;
  locale: string;
  isLoading?: boolean;
  onSubmit: (data: BaseImageData) => void;
};

const CreateBaseImageForm = ({
  baseImageCollectionRef,
  locale,
  isLoading = false,
  onSubmit,
}: Props) => {
  const baseImageCollectionData = useFragment(
    CREATE_BASE_IMAGE_FRAGMENT,
    baseImageCollectionRef,
  );
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    mode: "onTouched",
    defaultValues: transformInputData(baseImageCollectionData),
    resolver: yupResolver(baseImageSchema),
  });

  const onFormSubmit = (data: FormData) => {
    if (data.file instanceof FileList && data.file[0]) {
      const baseImageData = {
        ...data,
        file: data.file,
      };
      onSubmit(
        transformOutputData(baseImageCollectionData, locale, baseImageData),
      );
    }
  };

  return (
    <form onSubmit={handleSubmit(onFormSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="create-base-image-form-base-image-collection"
          label={
            <FormattedMessage
              id="forms.CreateBaseImage.baseImageCollectionLabel"
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
          id="create-base-image-form-file"
          label={
            <FormattedMessage
              id="forms.CreateBaseImage.fileLabel"
              defaultMessage="Base Image File"
            />
          }
        >
          <Form.Control
            type="file"
            {...register("file")}
            isInvalid={!!errors.file}
          />
          <Form.Control.Feedback type="invalid">
            {errors.file?.message && (
              <FormattedMessage id={errors.file?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-base-image-form-version"
          label={
            <FormattedMessage
              id="forms.CreateBaseImage.versionLabel"
              defaultMessage="Version"
            />
          }
        >
          <Form.Control {...register("version")} isInvalid={!!errors.version} />
          <Form.Control.Feedback type="invalid">
            {errors.version?.message && (
              <FormattedMessage id={errors.version?.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>
        <FormRow
          id="create-base-image-form-starting-version-requirement"
          label={
            <FormattedMessage
              id="forms.CreateBaseImage.startingVersionRequirementLabel"
              defaultMessage="Supported Starting Versions"
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
          id="create-base-image-form-release-display-name"
          label={
            <>
              <FormattedMessage
                id="forms.CreateBaseImage.releaseDisplayNameLabel"
                defaultMessage="Release Display Name"
              />
              <span className="small text-muted"> ({locale})</span>
            </>
          }
        >
          <Form.Control {...register("releaseDisplayName")} />
        </FormRow>
        <FormRow
          id="create-base-image-form-description"
          label={
            <>
              <FormattedMessage
                id="forms.CreateBaseImage.descriptionLabel"
                defaultMessage="Description"
              />
              <span className="small text-muted"> ({locale})</span>
            </>
          }
        >
          <Form.Control as="textarea" {...register("description")} />
        </FormRow>
        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateBaseImage.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { BaseImageData };

export default CreateBaseImageForm;
