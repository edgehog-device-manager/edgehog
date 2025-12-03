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

import { Suspense, useEffect, useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { UpdateCampaigns_getUpdateCampaigns_Query } from "@/api/__generated__/UpdateCampaigns_getUpdateCampaigns_Query.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Spinner from "@/components/Spinner";
import UpdateCampaignsTable from "@/components/UpdateCampaignsTable";
import { Link, Route } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const GET_UPDATE_CAMPAIGNS_QUERY = graphql`
  query UpdateCampaigns_getUpdateCampaigns_Query(
    $first: Int
    $after: String
    $filter: UpdateCampaignFilterInput = {}
  ) {
    ...UpdateCampaignsTable_UpdateCampaignFragment @arguments(filter: $filter)
  }
`;

type UpdateCampaignsContentProps = {
  getUpdateCampaignsQuery: PreloadedQuery<UpdateCampaigns_getUpdateCampaigns_Query>;
};

const UpdateCampaignsContent = ({
  getUpdateCampaignsQuery,
}: UpdateCampaignsContentProps) => {
  const updateCampaignsData = usePreloadedQuery(
    GET_UPDATE_CAMPAIGNS_QUERY,
    getUpdateCampaignsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.UpdateCampaigns.title"
            defaultMessage="Update Campaigns"
          />
        }
      >
        <Button as={Link} route={Route.updateCampaignsNew}>
          <FormattedMessage
            id="pages.UpdateCampaigns.createButton"
            defaultMessage="Create Update Campaign"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <UpdateCampaignsTable updateCampaignsData={updateCampaignsData} />
      </Page.Main>
    </Page>
  );
};

const UpdateCampaignsPage = () => {
  const [getUpdateCampaignsQuery, getUpdateCampaigns] =
    useQueryLoader<UpdateCampaigns_getUpdateCampaigns_Query>(
      GET_UPDATE_CAMPAIGNS_QUERY,
    );

  const fetchUpdateCampaigns = useCallback(
    () =>
      getUpdateCampaigns(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getUpdateCampaigns],
  );

  useEffect(fetchUpdateCampaigns, [fetchUpdateCampaigns]);

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
        onReset={fetchUpdateCampaigns}
      >
        {getUpdateCampaignsQuery && (
          <UpdateCampaignsContent
            getUpdateCampaignsQuery={getUpdateCampaignsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateCampaignsPage;
