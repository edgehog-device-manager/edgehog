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

import { zodResolver } from "@hookform/resolvers/zod";
import { useMemo, useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay";

import type { ManualFilesServerToDeviceRepositoryForm_RepositoriesPagination_Query } from "@/api/__generated__/ManualFilesServerToDeviceRepositoryForm_RepositoriesPagination_Query.graphql";
import type {
  ManualFilesServerToDeviceRepositoryForm_repositories_Fragment$data,
  ManualFilesServerToDeviceRepositoryForm_repositories_Fragment$key,
} from "@/api/__generated__/ManualFilesServerToDeviceRepositoryForm_repositories_Fragment.graphql";

import Button from "@/components/Button";
import Col from "@/components/Col";
import CollapseItem, { useCollapseToggle } from "@/components/CollapseItem";
import type { DestinationTypeOption } from "@/components/DeviceTabs/FilesServerToDeviceTab";
import FileSelect from "@/components/FileSelect";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import FormFeedback from "@/forms/FormFeedback";
import {
  ManualFileDownloadRequestFromRepositoryData,
  manualFileDownloadRequestFromRepositorySchema,
} from "@/forms/validation";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import SelectFormField from "@/forms/SelectFormFIeld";

const REPOSITORIES_FRAGMENT = graphql`
  fragment ManualFilesServerToDeviceRepositoryForm_repositories_Fragment on RootQueryType
  @refetchable(
    queryName: "ManualFilesServerToDeviceRepositoryForm_RepositoriesPagination_Query"
  )
  @argumentDefinitions(filter: { type: "RepositoryFilterInput" }) {
    repositories(first: $first, after: $after, filter: $filter)
      @connection(key: "ManualFilesServerToDeviceRepositoryForm_repositories") {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

export type RepositoryRecord = NonNullable<
  NonNullable<
    ManualFilesServerToDeviceRepositoryForm_repositories_Fragment$data["repositories"]
  >["edges"]
>[number]["node"];

const fromRepositoryInitialData: ManualFileDownloadRequestFromRepositoryData = {
  repository: { id: "", name: "" },
  file: { id: "", name: "" },
  destinationType: "STORAGE",
  destination: null,
  ttlSeconds: 0,
  progressTracked: false,
  fileMode: undefined,
  userId: undefined,
  groupId: undefined,
};

const getNoRepositoryOptionsMessage = (
  intl: ReturnType<typeof useIntl>,
  inputValue: string,
) =>
  inputValue
    ? intl.formatMessage(
        {
          id: "forms.ManualFilesServerToDeviceRepositoryForm.noRepositoriesFoundMatching",
          defaultMessage: 'No repositories found matching "{inputValue}"',
        },
        { inputValue },
      )
    : intl.formatMessage({
        id: "forms.ManualFilesServerToDeviceRepositoryForm.noRepositoriesAvailable",
        defaultMessage: "No repositories available",
      });

type ManualFilesServerToDeviceRepositoryFormProps = {
  className?: string;
  repositoriesData?: ManualFilesServerToDeviceRepositoryForm_repositories_Fragment$key;
  isLoading: boolean;
  onFileSubmit: (values: ManualFileDownloadRequestFromRepositoryData) => void;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
};

const ManualFilesServerToDeviceRepositoryForm = ({
  repositoriesData,
  className,
  isLoading,
  onFileSubmit,
  showAdvancedOptions,
  destinationTypeOptions,
}: ManualFilesServerToDeviceRepositoryFormProps) => {
  const intl = useIntl();
  const { open: advancedOptionsOpen, toggle: toggleAdvancedOptions } =
    useCollapseToggle();

  const {
    control,
    formState: { errors },
    handleSubmit,
    register,
    resetField,
    setValue,
    reset,
  } = useForm({
    mode: "onTouched",
    defaultValues: fromRepositoryInitialData,
    resolver: zodResolver(manualFileDownloadRequestFromRepositorySchema),
  });

  const selectedRepository = useWatch({ control, name: "repository" });
  const selectedDestinationType = useWatch({
    control,
    name: "destinationType",
  });

  const {
    data: repositoryPaginationData,
    loadNext: loadNextRepositories,
    hasNext: hasNextRepository,
    isLoadingNext: isLoadingNextRepository,
    refetch: refetchRepositories,
  } = usePaginationFragment<
    ManualFilesServerToDeviceRepositoryForm_RepositoriesPagination_Query,
    ManualFilesServerToDeviceRepositoryForm_repositories_Fragment$key
  >(REPOSITORIES_FRAGMENT, repositoriesData);

  const [searchRepositoryText, setSearchRepositoryText] = useState<
    string | null
  >(null);

  const { onLoadMore: onLoadMoreRepositoryOptions } =
    useRelayConnectionPagination({
      hasNext: hasNextRepository,
      isLoadingNext: isLoadingNextRepository,
      loadNext: loadNextRepositories,
      refetch: refetchRepositories,
      searchText: searchRepositoryText,
      buildFilter: (text) => {
        if (text === "") {
          return undefined;
        }

        return {
          name: {
            ilike: `%${text}%`,
          },
        };
      },
    });

  const repositories = useMemo(
    () =>
      repositoryPaginationData?.repositories?.edges?.flatMap((edge) =>
        edge?.node ? [edge.node] : [],
      ) ?? [],
    [repositoryPaginationData],
  );

  const onSubmit = handleSubmit((data) => {
    onFileSubmit(data);
    reset();
  });

  return (
    <form className={className} onSubmit={onSubmit}>
      <FormRow
        id="destinationType"
        label={
          <FormattedMessage
            id="forms.ManualFilesServerToDeviceRepositoryForm.destinationLabel"
            defaultMessage="Destination"
          />
        }
      >
        <SelectFormField
          control={control}
          name="destinationType"
          options={destinationTypeOptions}
          onChange={() => setValue("destination", null)}
        />
      </FormRow>

      {selectedDestinationType === "FILESYSTEM" && (
        <FormRow
          id="destination"
          label={
            <FormattedMessage
              id="forms.ManualFilesServerToDeviceRepositoryForm.destinationPathLabel"
              defaultMessage="Destination Path"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("destination")}
            placeholder="/tmp/file.bin"
            isInvalid={!!errors.destination}
          />

          {errors.destination ? (
            <FormFeedback feedback={errors.destination.message} />
          ) : (
            <Form.Text muted>
              <FormattedMessage
                id="forms.ManualFilesServerToDeviceRepositoryForm.destinationPathHint"
                defaultMessage="Absolute path on the target device where the file should be written."
              />
            </Form.Text>
          )}
        </FormRow>
      )}

      <FormRow
        id="repository"
        label={
          <FormattedMessage
            id="forms.ManualFilesServerToDeviceRepositoryForm.repositoryLabel"
            defaultMessage="Repository"
          />
        }
      >
        <SelectFormField
          control={control}
          name="repository"
          options={repositories.map((r) => ({
            value: r.id,
            label: r.name,
          }))}
          isClearable
          placeholder={intl.formatMessage({
            id: "forms.ManualFilesServerToDeviceRepositoryForm.repositoryOption",
            defaultMessage: "Search or select a repository...",
          })}
          noOptionsMessage={({ inputValue }) =>
            getNoRepositoryOptionsMessage(intl, inputValue)
          }
          isLoading={isLoadingNextRepository}
          onMenuScrollToBottom={onLoadMoreRepositoryOptions}
          onInputChange={(text) => setSearchRepositoryText(text)}
          onChange={() => resetField("file")}
          valueType="object"
        />
        <FormFeedback feedback={errors.repository?.message} />
      </FormRow>

      <FormRow
        id="file"
        label={
          <FormattedMessage
            id="forms.ManualFilesServerToDeviceRepositoryForm.fileLabel"
            defaultMessage="File"
          />
        }
      >
        {selectedRepository?.id ? (
          <>
            <Controller
              name="file"
              control={control}
              render={({
                field: { value, onChange },
                fieldState: { invalid },
              }) => (
                <FileSelect
                  selectedRepository={selectedRepository}
                  controllerProps={{
                    value: value,
                    invalid: invalid,
                    onChange,
                  }}
                />
              )}
            />
            <FormFeedback feedback={errors.file?.message} />
          </>
        ) : (
          <div className="d-flex align-content-center fst-italic text-muted">
            <FormattedMessage
              id="forms.ManualFilesServerToDeviceRepositoryForm.selectRepositoryHint"
              defaultMessage="Select a repository before selecting a file..."
            />
          </div>
        )}
      </FormRow>

      {selectedDestinationType === "STORAGE" && (
        <FormRow
          id="ttlSeconds"
          label={
            <FormattedMessage
              id="forms.ManualFilesServerToDeviceRepositoryForm.ttlLabel"
              defaultMessage="TTL (seconds)"
            />
          }
        >
          <Form.Control
            type="text"
            {...register("ttlSeconds", {
              setValueAs: (v) => (v === "" ? undefined : Number(v)),
            })}
            isInvalid={!!errors.ttlSeconds}
          />

          {errors.ttlSeconds ? (
            <FormFeedback feedback={errors.ttlSeconds.message} />
          ) : (
            <Form.Text muted>
              <FormattedMessage
                id="forms.ManualFilesServerToDeviceRepositoryForm.ttlHint"
                defaultMessage="Set to 0 for no expiry."
              />
            </Form.Text>
          )}
        </FormRow>
      )}

      <FormRow
        id="progress"
        label={
          <FormattedMessage
            id="forms.ManualFilesServerToDeviceRepositoryForm.progressLabel"
            defaultMessage="Report Progress"
          />
        }
      >
        <Form.Check
          type="checkbox"
          {...register("progressTracked")}
          isInvalid={!!errors.progressTracked}
        />
        <FormFeedback feedback={errors.progressTracked?.message} />
      </FormRow>

      {showAdvancedOptions && (
        <div className="mb-3">
          <CollapseItem
            open={advancedOptionsOpen}
            onToggle={toggleAdvancedOptions}
            headerClassName="ps-0 border-0"
            style={{ backgroundColor: "transparent" }}
            caretPosition="right"
            title={
              <FormattedMessage
                id="forms.ManualFilesServerToDeviceRepositoryForm.advancedOptionsTitle"
                defaultMessage="Advanced Options"
              />
            }
          >
            <FormRow
              id="userId"
              label={
                <FormattedMessage
                  id="forms.ManualFilesServerToDeviceRepositoryForm.userIdLabel"
                  defaultMessage="User ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register("userId", {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.userId}
              />
              <FormFeedback feedback={errors.userId?.message} />
            </FormRow>

            <FormRow
              id="groupId"
              label={
                <FormattedMessage
                  id="forms.ManualFilesServerToDeviceRepositoryForm.groupIdLabel"
                  defaultMessage="Group ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register("groupId", {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.groupId}
              />
              <FormFeedback feedback={errors.groupId?.message} />
            </FormRow>

            <FormRow
              id="fileMode"
              label={
                <FormattedMessage
                  id="forms.ManualFilesServerToDeviceRepositoryForm.fileModeLabel"
                  defaultMessage="File Mode"
                />
              }
            >
              <Form.Control
                type="text"
                {...register("fileMode", {
                  setValueAs: (v) => (v === "" ? undefined : Number(v)),
                })}
                isInvalid={!!errors.fileMode}
              />
              <FormFeedback feedback={errors.fileMode?.message} />
            </FormRow>
          </CollapseItem>
        </div>
      )}

      <Row>
        <Col className="d-flex justify-content-end">
          <Button variant="primary" type="submit" disabled={isLoading}>
            {isLoading && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="forms.ManualFilesServerToDeviceRepositoryForm.downloadButton"
              defaultMessage="Request download"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export default ManualFilesServerToDeviceRepositoryForm;
