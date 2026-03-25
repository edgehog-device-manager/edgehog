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

import type { ReactNode } from "react";
import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";

import type { FileDownloadCampaignCreate_createCampaign_Mutation } from "@/api/__generated__/FileDownloadCampaignCreate_createCampaign_Mutation.graphql";
import type {
  FileDownloadCampaignCreate_getOptions_Query,
  FileDownloadCampaignCreate_getOptions_Query$data,
} from "@/api/__generated__/FileDownloadCampaignCreate_getOptions_Query.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import type { FileDownloadCampaignOutputData } from "@/forms/CreateFileDownloadCampaign";
import CreateFileDownloadCampaignForm from "@/forms/CreateFileDownloadCampaign";
import { Link, Route, useNavigate } from "@/Navigation";

const GET_CREATE_CAMPAIGN_OPTIONS_QUERY = graphql`
  query FileDownloadCampaignCreate_getOptions_Query(
    $first: Int
    $after: String
    $filterRepositories: RepositoryFilterInput = {}
    $filterChannels: ChannelFilterInput = {}
  ) {
    repositories(first: $first, after: $after, filter: $filterRepositories) {
      count
    }
    channels(first: $first, after: $after, filter: $filterChannels) {
      count
    }
    ...CreateFileDownloadCampaign_RepositoryOptionsFragment
      @arguments(filter: $filterRepositories)
    ...CreateFileDownloadCampaign_ChannelOptionsFragment
      @arguments(filter: $filterChannels)
  }
`;

const CREATE_CAMPAIGN_MUTATION = graphql`
  mutation FileDownloadCampaignCreate_createCampaign_Mutation(
    $input: CreateCampaignInput!
  ) {
    createCampaign(input: $input) {
      result {
        id
      }
    }
  }
`;

type FileDownloadCampaignProps = {
  campaignOptions: FileDownloadCampaignCreate_getOptions_Query$data;
};

const FileDownloadCampaign = ({
  campaignOptions,
}: FileDownloadCampaignProps) => {
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

  const [createCampaign, isCreatingCampaign] =
    useMutation<FileDownloadCampaignCreate_createCampaign_Mutation>(
      CREATE_CAMPAIGN_MUTATION,
    );

  const handleCreateCampaign = useCallback(
    (fileDownloadCampaign: FileDownloadCampaignOutputData) => {
      createCampaign({
        variables: { input: fileDownloadCampaign },
        onCompleted(data, errors) {
          if (data.createCampaign?.result) {
            const fileDownloadCampaignId = data.createCampaign.result.id;
            navigate({
              route: Route.fileDownloadCampaignsEdit,
              params: { fileDownloadCampaignId },
            });
          }

          if (errors) {
            const formattedError = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(formattedError);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.FileDownloadCampaignCreate.creationErrorFeedback"
              defaultMessage="Could not create the File Download Campaign, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createCampaign?.result) {
            return;
          }

          const fileDownloadCampaign = store
            .getRootField("createCampaign")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const fileDownloadCampaigns = root.getLinkedRecords(
            "fileDownloadCampaigns",
          );

          if (fileDownloadCampaigns) {
            root.setLinkedRecords(
              [...fileDownloadCampaigns, fileDownloadCampaign],
              "fileDownloadCampaigns",
            );
          }
        },
      });
    },
    [createCampaign, navigate],
  );

  return (
    <>
      <Alert
        show={!!errorFeedback}
        variant="danger"
        onClose={() => setErrorFeedback(null)}
        dismissible
      >
        {errorFeedback}
      </Alert>
      <CreateFileDownloadCampaignForm
        campaignOptionsRef={campaignOptions}
        onSubmit={handleCreateCampaign}
        isLoading={isCreatingCampaign}
      />
    </>
  );
};

const NoRepositories = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.FileDownloadCampaignCreate.noRepository.title"
        defaultMessage="You haven't created any Repository yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.FileDownloadCampaignCreate.noRepository.message"
        defaultMessage="You need at least one Repository with one File to create a File Download Campaign"
      />
    </p>
    <Button as={Link} route={Route.repositoryNew}>
      <FormattedMessage
        id="pages.FileDownloadCampaignCreate.noRepository.createButton"
        defaultMessage="Create Repository"
      />
    </Button>
  </Result.EmptyList>
);

const NoChannels = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.FileDownloadCampaignCreate.noChannel.title"
        defaultMessage="You haven't created any Channel yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.FileDownloadCampaignCreate.noChannel.message"
        defaultMessage="You need at least one Channel to create a File Download Campaign"
      />
    </p>
    <Button as={Link} route={Route.channelsNew}>
      <FormattedMessage
        id="pages.FileDownloadCampaignCreate.noChannel.createButton"
        defaultMessage="Create Channel"
      />
    </Button>
  </Result.EmptyList>
);

type FileDownloadCampaignWrapperProps = {
  getCreateCampaignOptionsQuery: PreloadedQuery<FileDownloadCampaignCreate_getOptions_Query>;
};

const FileDownloadCampaignWrapper = ({
  getCreateCampaignOptionsQuery,
}: FileDownloadCampaignWrapperProps) => {
  const campaignOptions = usePreloadedQuery(
    GET_CREATE_CAMPAIGN_OPTIONS_QUERY,
    getCreateCampaignOptionsQuery,
  );

  const { repositories, channels } = campaignOptions;

  if (repositories?.count === 0) {
    return <NoRepositories />;
  }

  if (channels?.count === 0) {
    return <NoChannels />;
  }

  return <FileDownloadCampaign campaignOptions={campaignOptions} />;
};

const FileDownloadCampaignCreatePage = () => {
  const [getCreateCampaignOptionsQuery, getCreateCampaignOptions] =
    useQueryLoader<FileDownloadCampaignCreate_getOptions_Query>(
      GET_CREATE_CAMPAIGN_OPTIONS_QUERY,
    );

  const fetchCreateCampaignOptions = useCallback(
    () =>
      getCreateCampaignOptions(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "network-only" },
      ),
    [getCreateCampaignOptions],
  );

  useEffect(fetchCreateCampaignOptions, [fetchCreateCampaignOptions]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchCreateCampaignOptions}
      >
        {getCreateCampaignOptionsQuery && (
          <Page>
            <Page.Header
              title={
                <FormattedMessage
                  id="pages.FileDownloadCampaignCreate.title"
                  defaultMessage="Create File Download Campaign"
                />
              }
            />
            <Page.Main>
              <FileDownloadCampaignWrapper
                getCreateCampaignOptionsQuery={getCreateCampaignOptionsQuery}
              />
            </Page.Main>
          </Page>
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default FileDownloadCampaignCreatePage;
