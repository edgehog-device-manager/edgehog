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
import { useForm, useFieldArray, Controller, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";
import type { UseFormRegister } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";

import type {
  CreateRelease_ImageCredentialsOptionsFragment$key,
  CreateRelease_ImageCredentialsOptionsFragment$data,
} from "api/__generated__/CreateRelease_ImageCredentialsOptionsFragment.graphql";
import type {
  CreateRelease_NetworksOptionsFragment$key,
  CreateRelease_NetworksOptionsFragment$data,
} from "api/__generated__/CreateRelease_NetworksOptionsFragment.graphql";
import type {
  CreateRelease_VolumesOptionsFragment$key,
  CreateRelease_VolumesOptionsFragment$data,
} from "api/__generated__/CreateRelease_VolumesOptionsFragment.graphql";
import {
  ContainerCreateWithNestedNetworksInput,
  ContainerCreateWithNestedVolumesInput,
} from "api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import Button from "components/Button";
import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { yup, envSchema, portBindingsSchema } from "./index";
import MultiSelect from "components/MultiSelect";
import Select from "react-select";
import Icon from "components/Icon";

const IMAGE_CREDENTIALS_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_ImageCredentialsOptionsFragment on RootQueryType {
    listImageCredentials {
      results {
        id
        label
        username
      }
    }
  }
`;

const NETWORKS_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_NetworksOptionsFragment on RootQueryType {
    networks {
      results {
        id
        label
      }
    }
  }
`;

const VOLUMES_OPTIONS_FRAGMENT = graphql`
  fragment CreateRelease_VolumesOptionsFragment on RootQueryType {
    volumes {
      results {
        id
        label
      }
    }
  }
`;

const NetworksErrors = ({ errors }: { errors: unknown }) => {
  if (errors == null) {
    return null;
  }
  if (typeof errors === "object" && !Array.isArray(errors)) {
    if (
      "message" in errors &&
      typeof (errors as Record<"message", unknown>).message === "string"
    ) {
      const message = (errors as Record<"message", string>).message;
      return <FormattedMessage id={message} />;
    }
  }
  return null;
};

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
  networks: ContainerCreateWithNestedNetworksInput[];
  volumes: ContainerCreateWithNestedVolumesInput[];
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
          networks: yup.array(
            yup.object({
              id: yup.string().required(),
            }),
          ),
          volumes: yup.array(
            yup
              .object({
                id: yup.string(),
                target: yup.string().required(),
              })
              .required(),
          ),
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
  imageCredentialsOptionsRef: CreateRelease_ImageCredentialsOptionsFragment$key;
  networksOptionsRef: CreateRelease_NetworksOptionsFragment$key;
  volumesOptionsRef: CreateRelease_VolumesOptionsFragment$key;
  isLoading?: boolean;
  onSubmit: (data: ReleaseData) => void;
};

type ContainerFormProps = {
  index: number;
  register: UseFormRegister<ReleaseData>;
  errors: any;
  remove: (index: number) => void;
  listImageCredentials: CreateRelease_ImageCredentialsOptionsFragment$data["listImageCredentials"];
  networks: CreateRelease_NetworksOptionsFragment$data["networks"];
  volumes: CreateRelease_VolumesOptionsFragment$data["volumes"];
  intl: ReturnType<typeof useIntl>;
  control: any;
};

const ContainerForm = ({
  index,
  register,
  errors,
  remove,
  listImageCredentials,
  networks,
  volumes,
  intl,
  control,
}: ContainerFormProps) => {
  const volumesForm = useFieldArray({
    control,
    name: `containers.${index}.volumes`,
    keyName: "id",
  });
  const volumesValues: ContainerCreateWithNestedVolumesInput[] =
    useWatch({
      control,
      name: `containers.${index}.volumes`,
    }) ?? [];

  const canAddVolume = volumesValues.every(
    (v) => v.id?.trim() && v.target?.trim(),
  );

  return (
    <div className="border p-3 mb-3">
      <h5>
        <FormattedMessage
          id="components.CreateRelease.containerTitle"
          defaultMessage="Container {containerNumber}"
          values={{ containerNumber: index + 1 }}
        />
      </h5>{" "}
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
          id={`containers-${index}-networks`}
          label={
            <FormattedMessage
              id="components.CreateRelease.networksLabel"
              defaultMessage="Networks"
            />
          }
        >
          <Controller
            name={`containers.${index}.networks`}
            control={control}
            render={({
              field: { value, onChange, onBlur },
              fieldState: { invalid },
            }) => (
              <MultiSelect
                invalid={invalid}
                value={value}
                onChange={onChange}
                onBlur={onBlur}
                options={networks?.results || []}
                getOptionValue={(option) => option.id!}
              />
            )}
          />
          <Form.Control.Feedback type="invalid">
            {errors.containers?.[index]?.networks && (
              <NetworksErrors errors={errors.containers[index].networks} />
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
          id={`containers-${index}-volumes`}
          label={
            <FormattedMessage
              id="forms.CreateRelease.volumesLabel"
              defaultMessage="Volumes"
            />
          }
        >
          <div className="p-3 mb-3 bg-light border rounded">
            <Stack gap={3}>
              {volumesForm.fields.map((volume, volIndex) => {
                const selectedIds = volumesValues
                  .map((v, i) => (i !== volIndex ? v.id : null))
                  .filter(Boolean) as string[];

                const availableOptions = volumes?.results?.filter(
                  (vol) => !selectedIds.includes(vol.id),
                );

                const fieldErrors =
                  errors.containers?.[index]?.volumes?.[volIndex];

                return (
                  <Stack
                    direction="horizontal"
                    gap={3}
                    key={volume.id}
                    className="align-items-start"
                  >
                    <Stack
                      direction="horizontal"
                      gap={3}
                      className="align-items-start"
                    >
                      <FormRow
                        id={`containers-${index}-volumeId`}
                        label={
                          <FormattedMessage
                            id="components.CreateRelease.volumeSelectLabel"
                            defaultMessage="Volume:"
                          />
                        }
                      >
                        <div style={{ width: "250px", margin: "0 auto" }}>
                          <Controller
                            name={`containers.${index}.volumes.${volIndex}.id`}
                            control={control}
                            render={({ field }) => {
                              const selectOptions =
                                availableOptions?.map((vol) => ({
                                  value: vol.id,
                                  label: vol.label,
                                })) || [];
                              return (
                                <Select
                                  name={field.name}
                                  value={
                                    selectOptions.find(
                                      (opt) => opt.value === field.value,
                                    ) || null
                                  }
                                  onChange={(selected) =>
                                    field.onChange(selected?.value)
                                  }
                                  onBlur={field.onBlur}
                                  options={selectOptions}
                                  noOptionsMessage={() => (
                                    <FormattedMessage
                                      id="components.CreateRelease.noVolumesMessage"
                                      defaultMessage="No volumes available"
                                    />
                                  )}
                                  className="basic-single"
                                  classNamePrefix="select"
                                  isSearchable
                                />
                              );
                            }}
                          />
                        </div>

                        <Form.Control.Feedback type="invalid">
                          {fieldErrors?.id?.message && (
                            <FormattedMessage id={fieldErrors.id.message} />
                          )}
                        </Form.Control.Feedback>
                      </FormRow>

                      <FormRow
                        id={`containers-${index}-volumeTarget`}
                        label={
                          <FormattedMessage
                            id="components.CreateRelease.volumeTargetLabel"
                            defaultMessage="Target:"
                          />
                        }
                      >
                        <Form.Control
                          {...register(
                            `containers.${index}.volumes.${volIndex}.target` as const,
                          )}
                          placeholder="Target"
                          isInvalid={!!fieldErrors?.target}
                        />
                        <Form.Control.Feedback type="invalid">
                          {fieldErrors?.target?.message && (
                            <FormattedMessage id={fieldErrors.target.message} />
                          )}
                        </Form.Control.Feedback>
                      </FormRow>
                    </Stack>

                    <Button
                      variant="shadow-danger"
                      type="button"
                      onClick={() => volumesForm.remove(volIndex)}
                      className="align-self-start"
                    >
                      <Icon className="text-danger" icon={"delete"} />
                    </Button>
                  </Stack>
                );
              })}

              <div>
                <Button
                  variant="outline-primary"
                  onClick={() => volumesForm.append({ id: "", target: "" })}
                  disabled={!canAddVolume}
                >
                  <FormattedMessage
                    id="forms.CreateRelease.addVolumeButton"
                    defaultMessage="Add Volume"
                  />
                </Button>
              </div>
            </Stack>
          </div>
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
  imageCredentialsOptionsRef,
  networksOptionsRef,
  volumesOptionsRef,
  isLoading = false,
  onSubmit,
}: CreateReleaseProps) => {
  const intl = useIntl();

  const { listImageCredentials } = useFragment(
    IMAGE_CREDENTIALS_OPTIONS_FRAGMENT,
    imageCredentialsOptionsRef,
  );

  const { networks } = useFragment(
    NETWORKS_OPTIONS_FRAGMENT,
    networksOptionsRef,
  );
  const { volumes } = useFragment(VOLUMES_OPTIONS_FRAGMENT, volumesOptionsRef);

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
            networks: container.networks?.map((n) => ({ id: n.id })) || [],
            volumes: container.volumes?.map((v) => ({
              id: v.id,
              target: v.target,
            })),
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
            networks={networks}
            volumes={volumes}
            intl={intl}
            control={control}
          />
        ))}

        <div className="d-flex justify-content-start align-items-center">
          <Button
            variant="secondary"
            onClick={() =>
              append({
                image: { reference: "" },
                networks: [],
                volumes: [],
              })
            }
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
