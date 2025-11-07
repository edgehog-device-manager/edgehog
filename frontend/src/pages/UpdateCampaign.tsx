/*
  This file is part of Edgehog.

  Copyright 2023 - 2025 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  fetchQuery,
  graphql,
  useFragment,
  usePreloadedQuery,
  useRelayEnvironment,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import type { Subscription } from "relay-runtime";

import type { UpdateCampaign_getUpdateCampaign_Query } from "api/__generated__/UpdateCampaign_getUpdateCampaign_Query.graphql";
import type { UpdateCampaign_RefreshFragment$key } from "api/__generated__/UpdateCampaign_RefreshFragment.graphql";

import Center from "components/Center";
import Col from "components/Col";
import Page from "components/Page";
import Result from "components/Result";
import Row from "components/Row";
import Spinner from "components/Spinner";
import UpdateCampaignStatsChart from "components/UpdateCampaignStatsChart";
import UpdateTargetsTabs from "components/UpdateTargetsTabs";
import UpdateCampaignForm from "forms/UpdateCampaignForm";
import { Link, Route } from "Navigation";
import { RECORDS_TO_LOAD_FIRST } from "constants";

const GET_UPDATE_CAMPAIGN_QUERY = graphql`
  query UpdateCampaign_getUpdateCampaign_Query(
    $updateCampaignId: ID!
    $first: Int!
  ) {
    updateCampaign(id: $updateCampaignId) {
      name
      ...UpdateCampaignForm_UpdateCampaignFragment
      ...UpdateCampaignStatsChart_UpdateCampaignStatsChartFragment
      ...UpdateCampaign_RefreshFragment
      ...UpdateTargetsTabs_SuccessfulFragment @arguments(first: $first)
      ...UpdateTargetsTabs_FailedFragment @arguments(first: $first)
      ...UpdateTargetsTabs_InProgressFragment @arguments(first: $first)
      ...UpdateTargetsTabs_IdleFragment @arguments(first: $first)
    }
  }
`;

const UPDATE_CAMPAIGN_REFRESH_FRAGMENT = graphql`
  fragment UpdateCampaign_RefreshFragment on UpdateCampaign {
    id
    status
  }
`;

type UpdateCampaignRefreshProps = {
  updateCampaignRef: UpdateCampaign_RefreshFragment$key;
};
const UpdateCampaignRefresh = ({
  updateCampaignRef,
}: UpdateCampaignRefreshProps) => {
  const relayEnvironment = useRelayEnvironment();
  const { id, status } = useFragment(
    UPDATE_CAMPAIGN_REFRESH_FRAGMENT,
    updateCampaignRef,
  );
  const [isRefreshing, setIsRefreshing] = useState(false);

  // TODO: use GraphQL subscription (when available) to get updates about Update Campaign
  const subscriptionRef = useRef<Subscription | null>(null);
  useEffect(() => {
    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
      }
    };
  }, []);

  useEffect(() => {
    if (status === "FINISHED" || isRefreshing) {
      return;
    }
    const refreshTimerId = setTimeout(() => {
      setIsRefreshing(true);
      subscriptionRef.current = fetchQuery(
        relayEnvironment,
        GET_UPDATE_CAMPAIGN_QUERY,
        { updateCampaignId: id, first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "network-only" },
      ).subscribe({
        complete: () => {
          setIsRefreshing(false);
        },
        error: () => {
          setIsRefreshing(false);
        },
      });
    }, 10000);

    return () => {
      clearTimeout(refreshTimerId);
    };
  }, [id, status, relayEnvironment, isRefreshing, setIsRefreshing]);

  return isRefreshing ? <Spinner className="ms-2 mx-auto" /> : null;
};

type UpdateCampaignContentProps = {
  getUpdateCampaignQuery: PreloadedQuery<UpdateCampaign_getUpdateCampaign_Query>;
};

const UpdateCampaignContent = ({
  getUpdateCampaignQuery,
}: UpdateCampaignContentProps) => {
  const { updateCampaign } = usePreloadedQuery(
    GET_UPDATE_CAMPAIGN_QUERY,
    getUpdateCampaignQuery,
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
      <Page.Header title={updateCampaign.name}>
        <UpdateCampaignRefresh updateCampaignRef={updateCampaign} />
      </Page.Header>
      <Page.Main>
        <Row>
          <Col lg={9}>
            <UpdateCampaignForm updateCampaignRef={updateCampaign} />
          </Col>
          <Col lg={3}>
            <UpdateCampaignStatsChart updateCampaignRef={updateCampaign} />
          </Col>
        </Row>
        <hr className="bg-secondary border-2 border-top border-secondary" />
        <UpdateTargetsTabs updateCampaignRef={updateCampaign} />
      </Page.Main>
    </Page>
  );
};

const UpdateCampaignPage = () => {
  const { updateCampaignId = "" } = useParams();

  const [getUpdateCampaignQuery, getUpdateCampaign] =
    useQueryLoader<UpdateCampaign_getUpdateCampaign_Query>(
      GET_UPDATE_CAMPAIGN_QUERY,
    );

  const fetchUpdateCampaign = useCallback(() => {
    getUpdateCampaign(
      { updateCampaignId, first: RECORDS_TO_LOAD_FIRST },
      { fetchPolicy: "network-only" },
    );
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
