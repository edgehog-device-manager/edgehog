/*
  This file is part of Edgehog.

  Copyright 2024 - 2025 SECO Mind Srl

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
import { useForm, useFieldArray } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import type { UseFormRegister } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";

import type { CreateRelease_OptionsFragment$key } from "api/__generated__/CreateRelease_OptionsFragment.graphql";
import type { CreateRelease_OptionsFragment$data } from "api/__generated__/CreateRelease_OptionsFragment.graphql";
import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { yup, envSchema, portBindingsSchema } from "./index";

const CREATE_RELEASE_FRAGMENT = graphql`
  fragment CreateRelease_OptionsFragment on RootQueryType {
    listImageCredentials {
      results {
        id
        label
        username
      }
    }
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

type ContainerInput = {
  env?: string;
  image: {
    reference: string;
    imageCredentialsId?: string;
  };
  hostname?: string;
  privileged?: boolean;
  restartPolicy?: string;
  networkMode?: string;
  portBindings?: string[];
};

type ReleaseData = {
  version: string;
  containers?: ContainerInput[] | null;
};

// Yup schema for form validation
const applicationSchema = yup
  .object({
    version: yup.string().required(),
    containers: yup
      .array(
        yup.object({
          env: envSchema,
          image: yup.object({
            reference: yup.string().required(),
            imageCredentialsId: yup.string().nullable(),
          }),
          hostname: yup
            .string()
            .nullable()
            .transform((value) => value?.trim()),
          privileged: yup.boolean().nullable(),
          restartPolicy: yup
            .string()
            .nullable()
            .transform((value) => value?.trim()),
          networkMode: yup
            .string()
            .nullable()
            .transform((value) => value?.trim()),
          portBindings: portBindingsSchema,
        }),
      )
      .nullable(),
  })
  .required();

const initialData: ReleaseData = {
  version: "",
  containers: null,
};

const restartPolicyOptions = [
  { value: "no", label: "No" },
  { value: "always", label: "Always" },
  { value: "on_failure", label: "On Failure" },
  { value: "unless_stopped", label: "Unless Stopped" },
];

type CreateReleaseProps = {
  optionsRef: CreateRelease_OptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ReleaseData) => void;
};

type ContainerFormProps = {
  index: number;
  register: UseFormRegister<ReleaseData>;
  errors: any;
  remove: (index: number) => void;
  listImageCredentials: CreateRelease_OptionsFragment$data["listImageCredentials"];
  intl: ReturnType<typeof useIntl>;
};

const ContainerForm = ({
  index,
  register,
  errors,
  remove,
  listImageCredentials,
  intl,
}: ContainerFormProps) => {
  return (
    <div className="border p-3 mb-3">
      <h5>Container {index + 1}</h5>
      <Stack gap={2}>
        <FormRow
          id={`containers-${index}-env`}
          label={
            <FormattedMessage
              id="components.CreateRelease.envLabel"
              defaultMessage="Environment (JSON String)"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.env` as const)}
            isInvalid={!!errors.containers?.[index]?.env}
            placeholder='e.g., {"KEY": "value"}'
            as="textarea"
            rows={3}
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.env?.message && (
              <FormattedMessage id={errors.containers[index].env.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-image-reference`}
          label={
            <FormattedMessage
              id="components.CreateRelease.imageReferenceLabel"
              defaultMessage="Image Reference"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.image.reference` as const)}
            isInvalid={!!errors.containers?.[index]?.image?.reference}
            placeholder="e.g., my-image:latest"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.image?.reference?.message && (
              <FormattedMessage
                id={errors.containers[index].image.reference.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-image-credentials`}
          label={
            <FormattedMessage
              id="components.CreateRelease.imageCredentialsLabel"
              defaultMessage="Image Credentials"
            />
          }
        >
          <Form.Select
            {...register(
              `containers.${index}.image.imageCredentialsId` as const,
            )}
            isInvalid={!!errors.containers?.[index]?.image?.imageCredentialsId}
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "components.CreateRelease.imageCredentialOption",
                defaultMessage: "Select Image Credentials",
              })}
            </option>
            {listImageCredentials?.results?.map((imageCredential) => (
              <option key={imageCredential.id} value={imageCredential.id}>
                {imageCredential.label} ({imageCredential.username})
              </option>
            ))}
          </Form.Select>
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.image?.imageCredentialsId?.message && (
              <FormattedMessage
                id={errors.containers[index].image.imageCredentialsId.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-hostname`}
          label={
            <FormattedMessage
              id="components.CreateRelease.hostnameLabel"
              defaultMessage="Hostname"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.hostname` as const)}
            isInvalid={!!errors.containers?.[index]?.hostname}
            placeholder="Optional"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.hostname?.message && (
              <FormattedMessage
                id={errors.containers[index].hostname.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-networkMode`}
          label={
            <FormattedMessage
              id="components.CreateRelease.networkModeLabel"
              defaultMessage="Network Mode"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.networkMode` as const)}
            isInvalid={!!errors.containers?.[index]?.networkMode}
            placeholder="e.g., bridge"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.networkMode?.message && (
              <FormattedMessage
                id={errors.containers[index].networkMode.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-portBindings`}
          label={
            <FormattedMessage
              id="components.CreateRelease.portBindingsLabel"
              defaultMessage="Port Bindings"
            />
          }
        >
          <Form.Control
            {...register(`containers.${index}.portBindings` as const)}
            type="text"
            isInvalid={!!errors.containers?.[index]?.portBindings}
            placeholder="e.g., 8080:80, 443:443"
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.portBindings?.message && (
              <FormattedMessage
                id={errors.containers[index].portBindings.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-restartPolicy`}
          label={
            <FormattedMessage
              id="components.CreateRelease.restartPolicyLabel"
              defaultMessage="Restart Policy"
            />
          }
        >
          <Form.Select
            {...register(`containers.${index}.restartPolicy` as const)}
            isInvalid={!!errors.containers?.[index]?.restartPolicy}
            defaultValue=""
          >
            <option value="" disabled>
              {intl.formatMessage({
                id: "components.CreateRelease.restartPolicyOption",
                defaultMessage: "Select a Restart Policy",
              })}
            </option>
            {restartPolicyOptions.map((option) => (
              <option
                key={option.value}
                value={option.value}
                disabled={option.value === ""}
              >
                {option.label}
              </option>
            ))}
          </Form.Select>
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.restartPolicy?.message && (
              <FormattedMessage
                id={errors.containers[index].restartPolicy.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <FormRow
          id={`containers-${index}-privileged`}
          label={
            <FormattedMessage
              id="components.CreateRelease.privilegedLabel"
              defaultMessage="Privileged"
            />
          }
        >
          <Form.Check
            type="checkbox"
            {...register(`containers.${index}.privileged` as const)}
            isInvalid={!!errors.containers?.[index]?.privileged}
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.privileged?.message && (
              <FormattedMessage
                id={errors.containers[index].privileged.message}
              />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <div className="d-flex justify-content-start align-items-center">
          <Button
            variant="danger"
            onClick={() => remove(index)}
            className="mt-3"
          >
            <FormattedMessage
              id="components.CreateRelease.removeContainerButton"
              defaultMessage="Remove Container"
            />
          </Button>
        </div>
      </Stack>
    </div>
  );
};

const CreateRelease = ({
  optionsRef,
  isLoading = false,
  onSubmit,
}: CreateReleaseProps) => {
  const intl = useIntl();

  const { listImageCredentials } = useFragment(
    CREATE_RELEASE_FRAGMENT,
    optionsRef,
  );

  const {
    register,
    handleSubmit,
    control,
    formState: { errors },
  } = useForm<ReleaseData>({
    mode: "onTouched",
    defaultValues: initialData,
    resolver: yupResolver(applicationSchema),
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "containers",
  });

  return (
    <form
      onSubmit={handleSubmit((data) => {
        const cleanedData: ReleaseData = {
          ...data,
          containers: data.containers?.map((container) => ({
            env: container.env || undefined,
            image: {
              reference: container.image.reference,
              imageCredentialsId:
                container.image.imageCredentialsId || undefined,
            },
            hostname: container.hostname || undefined,
            privileged: container.privileged || undefined,
            restartPolicy: container.restartPolicy || undefined,
            networkMode: container.networkMode || undefined,
            portBindings: container.portBindings || undefined,
          })),
        };

        onSubmit(cleanedData);
      })}
    >
      <Stack gap={2}>
        <FormRow
          id="application-form-version"
          label={
            <FormattedMessage
              id="components.CreateRelease.versionLabel"
              defaultMessage="Version"
            />
          }
        >
          <Form.Control
            {...register("version")}
            isInvalid={!!errors.version}
            placeholder="e.g., 1.0.0"
          />
          <Form.Control.Feedback type="invalid">
            {errors.version?.message && (
              <FormattedMessage id={errors.version.message} />
            )}
          </Form.Control.Feedback>
        </FormRow>

        <Stack className="mt-3">
          <h5>
            <FormattedMessage
              id="components.CreateRelease.containersTitle"
              defaultMessage="Containers"
            />
          </h5>
          {fields.length === 0 && (
            <p>
              <FormattedMessage
                id="components.CreateRelease.noContainersFeedback"
                defaultMessage="The release does not include any container."
              />
            </p>
          )}
        </Stack>

        {fields.map((field, index) => (
          <ContainerForm
            key={field.id}
            index={index}
            register={register}
            errors={errors}
            remove={remove}
            listImageCredentials={listImageCredentials}
            intl={intl}
          />
        ))}

        <div className="d-flex justify-content-start align-items-center">
          <Button
            variant="secondary"
            onClick={() => append({ image: { reference: "" } })}
          >
            <FormattedMessage
              id="components.CreateRelease.addContainerButton"
              defaultMessage="Add Container"
            />
          </Button>
        </div>

        <div className="d-flex justify-content-end align-items-center">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="components.CreateRelease.submitButton"
              defaultMessage="Create"
            />
          </Button>
        </div>
      </Stack>
    </form>
  );
};

export type { ReleaseData };

export default CreateRelease;
