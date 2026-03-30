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
import _ from "lodash";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, usePaginationFragment } from "react-relay";
import Select from "react-select";

import type { ManualFileDownloadRequestFromRepositoryForm_RepositoriesPagination_Query } from "@/api/__generated__/ManualFileDownloadRequestFromRepositoryForm_RepositoriesPagination_Query.graphql";
import type {
  ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment$data,
  ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment$key,
} from "@/api/__generated__/ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment.graphql";

import Button from "@/components/Button";
import Col from "@/components/Col";
import CollapseItem, { useCollapseToggle } from "@/components/CollapseItem";
import type { DestinationTypeOption } from "@/components/DeviceTabs/FilesUploadTab";
import FileSelect from "@/components/FileSelect";
import Form from "@/components/Form";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import FormFeedback from "@/forms/FormFeedback";
import {
  ManualFileDownloadRequestFromRepositoryData,
  manualFileDownloadRequestFromRepositorySchema,
} from "@/forms/validation";

const REPOSITORIES_FRAGMENT = graphql`
  fragment ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment on RootQueryType
  @refetchable(
    queryName: "ManualFileDownloadRequestFromRepositoryForm_RepositoriesPagination_Query"
  )
  @argumentDefinitions(filter: { type: "RepositoryFilterInput" }) {
    repositories(first: $first, after: $after, filter: $filter)
      @connection(
        key: "ManualFileDownloadRequestFromRepositoryForm_repositories"
      ) {
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
    ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment$data["repositories"]
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

type ManualFileDownloadRequestFromRepositoryFormProps = {
  className?: string;
  repositoriesData?: ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment$key;
  isLoading: boolean;
  onFileSubmit: (values: ManualFileDownloadRequestFromRepositoryData) => void;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
};

const ManualFileDownloadRequestFromRepositoryForm = ({
  repositoriesData,
  className,
  isLoading,
  onFileSubmit,
  showAdvancedOptions,
  destinationTypeOptions,
}: ManualFileDownloadRequestFromRepositoryFormProps) => {
  const intl = useIntl();
  const { open: advancedOptionsOpen, toggle: toggleAdvancedOptions } =
    useCollapseToggle();

  const {
    control,
    formState: { errors },
    handleSubmit,
    register,
    resetField,
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
    ManualFileDownloadRequestFromRepositoryForm_RepositoriesPagination_Query,
    ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment$key
  >(REPOSITORIES_FRAGMENT, repositoriesData);

  const [searchRepositoryText, setSearchRepositoryText] = useState<
    string | null
  >(null);

  const debounceRepositoryRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetchRepositories(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetchRepositories(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetchRepositories],
  );

  useEffect(() => {
    if (searchRepositoryText !== null) {
      debounceRepositoryRefetch(searchRepositoryText);
    }
  }, [debounceRepositoryRefetch, searchRepositoryText]);

  const loadNextRepositoryOptions = useCallback(() => {
    if (hasNextRepository && !isLoadingNextRepository) {
      loadNextRepositories(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNextRepository, isLoadingNextRepository, loadNextRepositories]);

  const repositories = useMemo(
    () =>
      repositoryPaginationData?.repositories?.edges?.map(
        (edge) => edge?.node,
      ) ?? [],
    [repositoryPaginationData],
  );

  const noRepositoryOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "forms.ManualFileDownloadRequestFromRepositoryForm.noRepositoriesFoundMatching",
            defaultMessage: 'No repositories found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "forms.ManualFileDownloadRequestFromRepositoryForm.noRepositoriesAvailable",
          defaultMessage: "No repositories available",
        });

  const { onChange: onRepositoryChange } = register("repository");
  const { onChange: onFileChange } = register("file");

  const onSubmit = handleSubmit((data) => {
    onFileSubmit(data);
  });

  return (
    <form className={className} onSubmit={onSubmit}>
      <FormRow
        id="repository"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestFromRepositoryForm.repositoryLabel"
            defaultMessage="Repository"
          />
        }
      >
        <Controller
          name="repository"
          control={control}
          render={({ field: { value, onChange }, fieldState: { invalid } }) => (
            <Select
              value={value}
              onChange={(e) => {
                onChange(e);
                onRepositoryChange({ target: e });
                resetField("file");
              }}
              className={invalid ? "is-invalid" : ""}
              placeholder={intl.formatMessage({
                id: "forms.ManualFileDownloadRequestFromRepositoryForm.repositoryOption",
                defaultMessage: "Search or select a repository...",
              })}
              options={repositories}
              getOptionLabel={(opt) => opt.name}
              getOptionValue={(opt) => opt.id}
              noOptionsMessage={({ inputValue }) =>
                noRepositoryOptionsMessage(inputValue)
              }
              isLoading={isLoadingNextRepository}
              onMenuScrollToBottom={
                hasNextRepository ? loadNextRepositoryOptions : undefined
              }
              onInputChange={(text) => setSearchRepositoryText(text)}
            />
          )}
        />
        <FormFeedback feedback={errors.repository?.id?.message} />
      </FormRow>

      <FormRow
        id="file"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestFromRepositoryForm.fileLabel"
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
                    onChange: (e) => {
                      onChange(e);
                      onFileChange(e);
                    },
                  }}
                />
              )}
            />
            <FormFeedback feedback={errors.file?.id?.message} />
          </>
        ) : (
          <div className="d-flex align-content-center fst-italic text-muted">
            <FormattedMessage
              id="forms.ManualFileDownloadRequestFromRepositoryForm.selectRepositoryHint"
              defaultMessage="Select a repository before selecting a file..."
            />
          </div>
        )}
      </FormRow>

      <FormRow
        id="destinationType"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestFromRepositoryForm.destinationLabel"
            defaultMessage="Destination"
          />
        }
      >
        <Controller
          control={control}
          name="destinationType"
          render={({ field }) => {
            const selectedOption =
              destinationTypeOptions.find((opt) => opt.value === field.value) ||
              null;

            return (
              <Select
                value={selectedOption}
                onChange={(option) => {
                  field.onChange(option ? option.value : null);
                }}
                options={destinationTypeOptions}
              />
            );
          }}
        />
      </FormRow>

      {selectedDestinationType === "FILESYSTEM" && (
        <FormRow
          id="destination"
          label={
            <FormattedMessage
              id="forms.ManualFileDownloadRequestFromRepositoryForm.destinationPathLabel"
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
                id="forms.ManualFileDownloadRequestFromRepositoryForm.destinationPathHint"
                defaultMessage="Absolute path on the target device where the file should be written."
              />
            </Form.Text>
          )}
        </FormRow>
      )}

      <FormRow
        id="ttlSeconds"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestFromRepositoryForm.ttlLabel"
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
              id="forms.ManualFileDownloadRequestFromRepositoryForm.ttlHint"
              defaultMessage="Set to 0 for no expiry."
            />
          </Form.Text>
        )}
      </FormRow>

      <FormRow
        id="progress"
        label={
          <FormattedMessage
            id="forms.ManualFileDownloadRequestFromRepositoryForm.progressLabel"
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
            type="flat"
            open={advancedOptionsOpen}
            onToggle={toggleAdvancedOptions}
            isInsideTable={true}
            title={
              <FormattedMessage
                id="forms.ManualFileDownloadRequestFromRepositoryForm.advancedOptionsTitle"
                defaultMessage="Advanced Options"
              />
            }
          >
            <FormRow
              id="userId"
              label={
                <FormattedMessage
                  id="forms.ManualFileDownloadRequestFromRepositoryForm.userIdLabel"
                  defaultMessage="User ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`userId` as const, {
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
                  id="forms.ManualFileDownloadRequestFromRepositoryForm.groupIdLabel"
                  defaultMessage="Group ID"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`groupId` as const, {
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
                  id="forms.ManualFileDownloadRequestFromRepositoryForm.fileModeLabel"
                  defaultMessage="File Mode"
                />
              }
            >
              <Form.Control
                type="text"
                {...register(`fileMode` as const, {
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
              id="forms.ManualFileDownloadRequestFromRepositoryForm.uploadButton"
              defaultMessage="Upload"
            />
          </Button>
        </Col>
      </Row>
    </form>
  );
};

export default ManualFileDownloadRequestFromRepositoryForm;
