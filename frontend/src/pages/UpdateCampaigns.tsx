/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { Suspense, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { UpdateCampaigns_getUpdateCampaigns_Query } from "api/__generated__/UpdateCampaigns_getUpdateCampaigns_Query.graphql";
import Button from "components/Button";
import Center from "components/Center";
import Page from "components/Page";
import Spinner from "components/Spinner";
import UpdateCampaignsTable from "components/UpdateCampaignsTable";
import { Link, Route } from "Navigation";

const GET_UPDATE_CAMPAIGNS_QUERY = graphql`
  query UpdateCampaigns_getUpdateCampaigns_Query {
    updateCampaigns {
      ...UpdateCampaignsTable_UpdateCampaignFragment
    }
  }
`;

type UpdateCampaignsContentProps = {
  getUpdateCampaignsQuery: PreloadedQuery<UpdateCampaigns_getUpdateCampaigns_Query>;
};

const UpdateCampaignsContent = ({
  getUpdateCampaignsQuery,
}: UpdateCampaignsContentProps) => {
  const { updateCampaigns } = usePreloadedQuery(
    GET_UPDATE_CAMPAIGNS_QUERY,
    getUpdateCampaignsQuery
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
        <UpdateCampaignsTable updateCampaignsRef={updateCampaigns} />
      </Page.Main>
    </Page>
  );
};

const UpdateCampaignsPage = () => {
  const [getUpdateCampaignsQuery, getUpdateCampaigns] =
    useQueryLoader<UpdateCampaigns_getUpdateCampaigns_Query>(
      GET_UPDATE_CAMPAIGNS_QUERY
    );

  useEffect(() => getUpdateCampaigns({}), [getUpdateCampaigns]);

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
        onReset={() => getUpdateCampaigns({})}
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
