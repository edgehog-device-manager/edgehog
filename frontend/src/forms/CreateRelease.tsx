// This file is part of Edgehog.
//
// Copyright 2024 - 2026 SECO Mind Srl
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
import { useForm } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import { hooks_ContainersOptionsFragment$key } from "@/api/__generated__/hooks_ContainersOptionsFragment.graphql";
import { hooks_SystemModelsOptionsFragment$key } from "@/api/__generated__/hooks_SystemModelsOptionsFragment.graphql";
import {
  ReleaseCreateContainersInput,
  ReleaseCreateRequiredSystemModelsInput,
} from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import {
  useContainerOptions,
  useSystemModelOptions,
} from "@/components/options/hooks";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import FormFeedback from "@/forms/FormFeedback";
import MultiSelectFormField from "@/forms/MultiSelectFormField";
import { ReleaseFormData, releaseSchema } from "@/forms/validation";

type ReleaseSubmitData = {
  version: string;
  containers?: ReleaseCreateContainersInput[];
  requiredSystemModels?: ReleaseCreateRequiredSystemModelsInput[];
};

const initialData: ReleaseFormData = {
  version: "",
  containers: [],
};

type CreateReleaseProps = {
  requiredSystemModelsOptionsRef: hooks_SystemModelsOptionsFragment$key;
  containersOptionsRef: hooks_ContainersOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ReleaseSubmitData) => void;
};

const CreateRelease = ({
  isLoading = false,
  requiredSystemModelsOptionsRef,
  containersOptionsRef,
  onSubmit,
}: CreateReleaseProps) => {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors },
  } = useForm<ReleaseFormData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: zodResolver(releaseSchema),
  });

  const systemModelOptions = useSystemModelOptions(
    requiredSystemModelsOptionsRef,
  );

  const containerOptions = useContainerOptions(containersOptionsRef);

  return (
    <Form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap={3}>
        <FormRow
          id="version"
          label={
            <FormattedMessage
              id="forms.CreateRelease.versionLabel"
              defaultMessage="Version"
            />
          }
        >
          <Form.Control
            {...register("version")}
            isInvalid={!!errors.version}
            placeholder="e.g., 1.0.0"
          />
          <FormFeedback feedback={errors.version?.message} />
        </FormRow>

        <FormRow
          id="system-models"
          label={
            <FormattedMessage
              id="forms.CreateRelease.supportedSystemModelsLabels"
              defaultMessage="Supported System Models"
            />
          }
        >
          <MultiSelectFormField
            control={control}
            name={"requiredSystemModels"}
            options={systemModelOptions}
          />
        </FormRow>

        <FormRow
          id="containers"
          label={
            <FormattedMessage
              id="forms.CreateRelease.containersLabel"
              defaultMessage="Containers"
            />
          }
        >
          <MultiSelectFormField
            control={control}
            name="containers"
            options={containerOptions}
          />
        </FormRow>

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.CreateRelease.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </Form>
  );
};

export default CreateRelease;
