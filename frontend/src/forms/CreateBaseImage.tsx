/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2025 SECO Mind Srl
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

import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import { zodResolver } from "@hookform/resolvers/zod";

import Button from "@/components/Button";
import Form from "@/components/Form";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { FormRow } from "@/components/FormRow";

import type {
  CreateBaseImage_BaseImageCollectionFragment$key,
  CreateBaseImage_BaseImageCollectionFragment$data,
} from "@/api/__generated__/CreateBaseImage_BaseImageCollectionFragment.graphql";
import type { CreateBaseImage_OptionsFragment$key } from "@/api/__generated__/CreateBaseImage_OptionsFragment.graphql";
import { BaseImageFormData, baseImageSchema } from "@/forms/validation";

const CREATE_BASE_IMAGE_FRAGMENT = graphql`
  fragment CreateBaseImage_BaseImageCollectionFragment on BaseImageCollection {
    id
    name
  }
`;

const CREATE_BASE_IMAGE_OPTIONS_FRAGMENT = graphql`
  fragment CreateBaseImage_OptionsFragment on RootQueryType {
    tenantInfo {
      defaultLocale
    }
  }
`;

type BaseImageOutputData = {
  baseImageCollectionId: string;
  file: File;
  version: string;
  startingVersionRequirement: string;
  localizedReleaseDisplayNames?: {
    languageTag: string;
    value: string;
  }[];
  localizedDescriptions?: {
    languageTag: string;
    value: string;
  }[];
};

const transformInputData = (
  baseImageCollection: CreateBaseImage_BaseImageCollectionFragment$data,
): BaseImageFormData => ({
  baseImageCollection: baseImageCollection.name,
  file: undefined,
  version: "",
  startingVersionRequirement: "",
  description: "",
  releaseDisplayName: "",
});

type FormOutput = BaseImageFormData & {
  file: FileList;
};

const transformOutputData = (
  baseImageCollection: CreateBaseImage_BaseImageCollectionFragment$data,
  locale: string,
  data: FormOutput,
): BaseImageOutputData => {
  const baseImage: BaseImageOutputData = {
    baseImageCollectionId: baseImageCollection.id,
    file: data.file[0],
    version: data.version,
    startingVersionRequirement: data.startingVersionRequirement,
  };

  if (data.releaseDisplayName) {
    baseImage.localizedReleaseDisplayNames = [
      {
        languageTag: locale,
        value: data.releaseDisplayName,
      },
    ];
  }

  if (data.description) {
    baseImage.localizedDescriptions = [
      {
        languageTag: locale,
        value: data.description,
      },
    ];
  }

  return baseImage;
};

type Props = {
  baseImageCollectionRef: CreateBaseImage_BaseImageCollectionFragment$key;
  optionsRef: CreateBaseImage_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: BaseImageOutputData) => void;
};

const CreateBaseImageForm = ({
  baseImageCollectionRef,
  optionsRef,
  isLoading = false,
  onSubmit,
}: Props) => {
  const baseImageCollectionData = useFragment(
    CREATE_BASE_IMAGE_FRAGMENT,
    baseImageCollectionRef,
  );
  const {
    tenantInfo: { defaultLocale: locale },
  } = useFragment(CREATE_BASE_IMAGE_OPTIONS_FRAGMENT, optionsRef);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<BaseImageFormData>({
    mode: "onTouched",
    defaultValues: transformInputData(baseImageCollectionData),
    resolver: zodResolver(baseImageSchema),
  });

  const onFormSubmit = (data: BaseImageFormData) => {
    if (data.file instanceof FileList && data.file[0]) {
      const baseImageOutputData = {
        ...data,
        file: data.file,
      };
      onSubmit(
        transformOutputData(
          baseImageCollectionData,
          locale,
          baseImageOutputData,
        ),
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

export type { BaseImageOutputData };

export default CreateBaseImageForm;
