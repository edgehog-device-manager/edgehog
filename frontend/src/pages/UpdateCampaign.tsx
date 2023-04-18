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

import { Suspense, useCallback, useEffect } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { UpdateCampaign_getUpdateCampaign_Query } from "api/__generated__/UpdateCampaign_getUpdateCampaign_Query.graphql";

import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateTargetsTable from "components/UpdateTargetsTable";
import UpdateCampaignForm from "forms/UpdateCampaignForm";
import { Link, Route } from "Navigation";

const GET_UPDATE_CAMPAIGN_QUERY = graphql`
  query UpdateCampaign_getUpdateCampaign_Query($updateCampaignId: ID!) {
    updateCampaign(id: $updateCampaignId) {
      name
      ...UpdateCampaignForm_UpdateCampaignFragment
      ...UpdateTargetsTable_UpdateTargetsFragment
    }
  }
`;

type UpdateCampaignContentProps = {
  getUpdateCampaignQuery: PreloadedQuery<UpdateCampaign_getUpdateCampaign_Query>;
};

const UpdateCampaignContent = ({
  getUpdateCampaignQuery,
}: UpdateCampaignContentProps) => {
  const { updateCampaign } = usePreloadedQuery(
    GET_UPDATE_CAMPAIGN_QUERY,
    getUpdateCampaignQuery
  );

  if (!updateCampaign) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.UpdateCampaign.updateCampaignNotFound.title"
            defaultMessage="Update Campaign not found."
          />
        }
      >
        <Link route={Route.updateCampaigns}>
          <FormattedMessage
            id="pages.UpdateCampaign.updateCampaignNotFound.message"
            defaultMessage="Return to the Update Campaign list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={updateCampaign.name} />
      <Page.Main>
        <div className="mb-3">
          <UpdateCampaignForm updateCampaignRef={updateCampaign} />
        </div>
        <hr className="bg-secondary border-2 border-top border-secondary" />
        <div className="d-flex justify-content-between align-items-center gap-2">
          <h3>
            <FormattedMessage
              id="pages.UpdateCampaign.updateTargetsLabel"
              defaultMessage="Update Targets"
            />
          </h3>
        </div>
        <UpdateTargetsTable updateCampaignRef={updateCampaign} />
      </Page.Main>
    </Page>
  );
};

const UpdateCampaignPage = () => {
  const { updateCampaignId = "" } = useParams();

  const [getUpdateCampaignQuery, getUpdateCampaign] =
    useQueryLoader<UpdateCampaign_getUpdateCampaign_Query>(
      GET_UPDATE_CAMPAIGN_QUERY
    );

  const fetchUpdateCampaign = useCallback(() => {
    getUpdateCampaign({ updateCampaignId }, { fetchPolicy: "network-only" });
  }, [getUpdateCampaign, updateCampaignId]);

  useEffect(fetchUpdateCampaign, [fetchUpdateCampaign]);

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
        onReset={fetchUpdateCampaign}
      >
        {getUpdateCampaignQuery && (
          <UpdateCampaignContent
            getUpdateCampaignQuery={getUpdateCampaignQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateCampaignPage;
