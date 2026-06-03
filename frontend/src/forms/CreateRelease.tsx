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
import { useMemo } from "react";
import { Col, Container, Row } from "react-bootstrap";
import { useFieldArray, useForm, useWatch } from "react-hook-form";
import { FormattedMessage } from "react-intl";

import { hooks_ContainersOptionsFragment$key } from "@/api/__generated__/hooks_ContainersOptionsFragment.graphql";
import { hooks_SystemModelsOptionsFragment$key } from "@/api/__generated__/hooks_SystemModelsOptionsFragment.graphql";
import {
  ReleaseCreateContainerDependenciesInput,
  ReleaseCreateContainersInput,
  ReleaseCreateRequiredSystemModelsInput,
} from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import Button from "@/components/Button";
import Form from "@/components/Form";
import { FormRow } from "@/components/FormRow";
import Icon from "@/components/Icon";
import {
  useContainerOptions,
  useSystemModelOptions,
} from "@/components/options/hooks";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import FormFeedback from "@/forms/FormFeedback";
import MultiSelectFormField from "@/forms/MultiSelectFormField";
import SelectFormField from "@/forms/SelectFormFIeld";
import { ReleaseFormData, releaseSchema } from "@/forms/validation";

type ReleaseSubmitData = {
  version: string;
  containers?: ReleaseCreateContainersInput[];
  containerDependencies?: ReleaseCreateContainerDependenciesInput[];
  requiredSystemModels?: ReleaseCreateRequiredSystemModelsInput[];
};

const initialData: ReleaseFormData = {
  version: "",
  requiredSystemModels: [],
  containers: [],
  containerDependencies: [],
};

const transformOutputData = (data: ReleaseFormData): ReleaseSubmitData => {
  const containers = data.containers.map((container) => ({
    id: container.id,
    dependencies:
      data.containerDependencies?.find(
        (contDep) => contDep.containerId === container.id,
      )?.dependencies ?? [],
  }));

  const releaseContainers = containers.flatMap((container) =>
    container.dependencies.map((dependencyId) => ({
      containerId: container.id,
      dependencyId: dependencyId,
    })),
  );

  const release: ReleaseSubmitData = {
    version: data.version,
    containers: data.containers,
    containerDependencies: releaseContainers,
    requiredSystemModels: data.requiredSystemModels,
  };

  return release;
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

  const selectedContainers =
    useWatch({
      control,
      name: "containers",
    }) ?? [];

  const dependencyFieldArray = useFieldArray({
    control,
    name: "containerDependencies",
    keyName: "key",
  });

  const watchedDependencies =
    useWatch({
      control,
      name: "containerDependencies",
    }) ?? [];

  const containerDependenciesOptions = useMemo(() => {
    const selectedContainerIds = new Set(selectedContainers.map((c) => c.id));

    return containerOptions.filter((option) =>
      selectedContainerIds.has(option.value),
    );
  }, [selectedContainers, containerOptions]);

  const selectedDependencyContainerIds = watchedDependencies.flatMap((d) =>
    d?.containerId ? [d.containerId] : [],
  );

  const canAddDependencies =
    selectedContainers.length > 1 &&
    watchedDependencies.every(
      (v) => v?.containerId?.trim() && v?.dependencies?.length > 0,
    );

  const onFormSubmit = (data: ReleaseFormData) =>
    onSubmit(transformOutputData(data));

  return (
    <Form onSubmit={handleSubmit(onFormSubmit)}>
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

        <FormRow
          id="container-dependencies"
          label={
            <FormattedMessage
              id="forms.CreateRelease.containerDependenciesLabel"
              defaultMessage="Container Dependencies"
            />
          }
        >
          <div className="p-3 border rounded">
            <Container fluid>
              {dependencyFieldArray.fields.length > 0 && (
                <Row className="mb-3 align-items-center">
                  <Col md={5}>
                    <FormattedMessage
                      id="forms.CreateRelease.containerLabel"
                      defaultMessage="Container"
                    />
                  </Col>

                  <Col md={6}>
                    <FormattedMessage
                      id="forms.CreateRelease.dependsOnLabel"
                      defaultMessage="Depends on"
                    />
                  </Col>

                  <Col md={1} />
                </Row>
              )}

              {dependencyFieldArray.fields.map((field, i) => {
                const error = errors.containerDependencies?.[i];
                const currentContainerId = watchedDependencies[i]?.containerId;

                const availableContainers = containerDependenciesOptions.filter(
                  (c) =>
                    c.value === currentContainerId ||
                    !selectedDependencyContainerIds.includes(c.value),
                );

                const availableDependencies =
                  containerDependenciesOptions.reduce<
                    { value: string; label: string }[]
                  >((dependencies, c) => {
                    if (c.value !== currentContainerId) {
                      dependencies.push({
                        value: c.value,
                        label: c.label,
                      });
                    }

                    return dependencies;
                  }, []);

                return (
                  <Row className="mb-3 align-items-start" key={field.key}>
                    <Col md={5} xs={5}>
                      <SelectFormField
                        control={control}
                        options={availableContainers}
                        name={`containerDependencies.${i}.containerId`}
                      />
                      <FormFeedback feedback={error?.containerId?.message} />
                    </Col>

                    <Col md={6} xs={6}>
                      <MultiSelectFormField
                        control={control}
                        name={`containerDependencies.${i}.dependencies`}
                        options={availableDependencies}
                        transformValue={(selected) =>
                          selected.map((s) => s.value)
                        }
                      />
                      <FormFeedback feedback={error?.dependencies?.message} />
                    </Col>

                    <Col md={1} xs={1} className="d-flex p-0 pt-1">
                      <Button
                        variant="shadow-danger"
                        type="button"
                        onClick={() => dependencyFieldArray.remove(i)}
                      >
                        <Icon className="text-danger" icon="delete" />
                      </Button>
                    </Col>
                  </Row>
                );
              })}
            </Container>

            <Button
              className="mt-2"
              variant="outline-primary"
              type="button"
              disabled={!canAddDependencies}
              onClick={() =>
                dependencyFieldArray.append({
                  containerId: "",
                  dependencies: [],
                })
              }
            >
              <FormattedMessage
                id="forms.CreateRelease.addDependenciesButton"
                defaultMessage="Add Dependencies"
              />
            </Button>
          </div>
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
