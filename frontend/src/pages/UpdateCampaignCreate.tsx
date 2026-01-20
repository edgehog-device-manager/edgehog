/*
 * This file is part of Edgehog.
 *
 * Copyright 2023 - 2026 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type {
  UpdateCampaignCreate_getOptions_Query,
  UpdateCampaignCreate_getOptions_Query$data,
} from "@/api/__generated__/UpdateCampaignCreate_getOptions_Query.graphql";
import type { UpdateCampaignCreate_createCampaign_Mutation } from "@/api/__generated__/UpdateCampaignCreate_createCampaign_Mutation.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import type { UpdateCampaignOutputData } from "@/forms/CreateUpdateCampaign";
import CreateUpdateCampaignForm from "@/forms/CreateUpdateCampaign";
import { Link, Route, useNavigate } from "@/Navigation";

const GET_CREATE_CAMPAIGN_OPTIONS_QUERY = graphql`
  query UpdateCampaignCreate_getOptions_Query(
    $first: Int
    $after: String
    $filterBaseImageCollections: BaseImageCollectionFilterInput = {}
    $filterChannels: ChannelFilterInput = {}
  ) {
    baseImageCollections(
      first: $first
      after: $after
      filter: $filterBaseImageCollections
    ) {
      count
    }
    channels(first: $first, after: $after, filter: $filterChannels) {
      count
    }
    ...CreateUpdateCampaign_BaseImageCollOptionsFragment
      @arguments(filter: $filterBaseImageCollections)
    ...CreateUpdateCampaign_ChannelOptionsFragment
      @arguments(filter: $filterChannels)
  }
`;

const CREATE_CAMPAIGN_MUTATION = graphql`
  mutation UpdateCampaignCreate_createCampaign_Mutation(
    $input: CreateCampaignInput!
  ) {
    createCampaign(input: $input) {
      result {
        id
      }
    }
  }
`;

type UpdateCampaignProps = {
  campaignOptions: UpdateCampaignCreate_getOptions_Query$data;
};

const UpdateCampaign = ({ campaignOptions }: UpdateCampaignProps) => {
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

  const [createCampaign, isCreatingUpdateCampaign] =
    useMutation<UpdateCampaignCreate_createCampaign_Mutation>(
      CREATE_CAMPAIGN_MUTATION,
    );

  const handleCreateCampaign = useCallback(
    (updateCampaign: UpdateCampaignOutputData) => {
      createCampaign({
        variables: { input: updateCampaign },
        onCompleted(data, errors) {
          if (data.createCampaign?.result) {
            const updateCampaignId = data.createCampaign.result.id;
            navigate({
              route: Route.updateCampaignsEdit,
              params: { updateCampaignId },
            });
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.UpdateCampaignCreate.creationErrorFeedback"
              defaultMessage="Could not create the Update Campaign, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createCampaign?.result) {
            return;
          }

          const updateCampaign = store
            .getRootField("createCampaign")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const updateCampaigns = root.getLinkedRecords("updateCampaigns");
          if (updateCampaigns) {
            root.setLinkedRecords(
              [...updateCampaigns, updateCampaign],
              "updateCampaigns",
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
      <CreateUpdateCampaignForm
        campaignOptionsRef={campaignOptions}
        onSubmit={handleCreateCampaign}
        isLoading={isCreatingUpdateCampaign}
      />
    </>
  );
};

const NoBaseImageCollections = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.UpdateCampaignCreate.noBaseImageCollection.title"
        defaultMessage="You haven't created any Base Image Collection yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.UpdateCampaignCreate.noBaseImageCollection.message"
        defaultMessage="You need at least one Base Image Collection with Base Image to create an Update Campaign"
      />
    </p>
    <Button as={Link} route={Route.baseImageCollectionsNew}>
      <FormattedMessage
        id="pages.UpdateCampaignCreate.noBaseImageCollection.createButton"
        defaultMessage="Create Base Image Collection"
      />
    </Button>
  </Result.EmptyList>
);

const NoChannels = () => (
  <Result.EmptyList
    title={
      <FormattedMessage
        id="pages.UpdateCampaignCreate.noChannel.title"
        defaultMessage="You haven't created any Channel yet"
      />
    }
  >
    <p>
      <FormattedMessage
        id="pages.UpdateCampaignCreate.noChannel.message"
        defaultMessage="You need at least one Channel to create an Update Campaign"
      />
    </p>
    <Button as={Link} route={Route.channelsNew}>
      <FormattedMessage
        id="pages.UpdateCampaignCreate.noChannel.createButton"
        defaultMessage="Create Channel"
      />
    </Button>
  </Result.EmptyList>
);

type UpdateCampaignWrapperProps = {
  getCreateCampaignOptionsQuery: PreloadedQuery<UpdateCampaignCreate_getOptions_Query>;
};

const UpdateCampaignWrapper = ({
  getCreateCampaignOptionsQuery,
}: UpdateCampaignWrapperProps) => {
  const campaignOptions = usePreloadedQuery(
    GET_CREATE_CAMPAIGN_OPTIONS_QUERY,
    getCreateCampaignOptionsQuery,
  );
  const { baseImageCollections, channels } = campaignOptions;

  if (baseImageCollections?.count === 0) {
    return <NoBaseImageCollections />;
  }
  if (channels?.count === 0) {
    return <NoChannels />;
  }

  return <UpdateCampaign campaignOptions={campaignOptions} />;
};

const UpdateCampaignCreatePage = () => {
  const [getCreateCampaignOptionsQuery, getCreateCampaignOptions] =
    useQueryLoader<UpdateCampaignCreate_getOptions_Query>(
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
                  id="pages.UpdateCampaignCreate.title"
                  defaultMessage="Create Update Campaign"
                />
              }
            />
            <Page.Main>
              <UpdateCampaignWrapper
                getCreateCampaignOptionsQuery={getCreateCampaignOptionsQuery}
              />
            </Page.Main>
          </Page>
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateCampaignCreatePage;
