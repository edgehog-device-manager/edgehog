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

import _ from "lodash";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  ConnectionHandler,
  graphql,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
  useSubscription,
} from "react-relay/hooks";

import type { UpdateCampaigns_getCampaigns_Query } from "@/api/__generated__/UpdateCampaigns_getCampaigns_Query.graphql";
import { UpdateCampaigns_PaginationQuery } from "@/api/__generated__/UpdateCampaigns_PaginationQuery.graphql";
import { UpdateCampaigns_UpdateCampaignsFragment$key } from "@/api/__generated__/UpdateCampaigns_UpdateCampaignsFragment.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import UpdateCampaignsTable from "@/components/UpdateCampaignsTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_CAMPAIGNS_QUERY = graphql`
  query UpdateCampaigns_getCampaigns_Query(
    $first: Int
    $after: String
    $filter: CampaignFilterInput = {}
  ) {
    ...UpdateCampaigns_UpdateCampaignsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const CAMPAIGNS_FRAGMENT = graphql`
  fragment UpdateCampaigns_UpdateCampaignsFragment on RootQueryType
  @refetchable(queryName: "UpdateCampaigns_PaginationQuery") {
    updateCampaigns(first: $first, after: $after, filter: $filter)
      @connection(key: "UpdateCampaigns_updateCampaigns") {
      edges {
        node {
          __typename
        }
      }
      ...UpdateCampaignsTable_CampaignEdgeFragment
    }
  }
`;

const CAMPAIGN_UPDATED_SUBSCRIPTION = graphql`
  subscription UpdateCampaigns_campaign_updated_Subscription {
    updateCampaigns {
      updated {
        id
        status
        outcome
      }
    }
  }
`;

const CAMPAIGN_CREATED_SUBSCRIPTION = graphql`
  subscription UpdateCampaigns_campaign_created_Subscription {
    deploymentCampaigns {
      created {
        id
        name
        status
        outcome
        channel {
          id
          name
        }
      }
    }
  }
`;

const enumStatuses = [
  "FINISHED",
  "IDLE",
  "IN_PROGRESS",
  "PAUSED",
  "PAUSING",
] as const;
const enumOutcomes = ["FAILURE", "SUCCESS"] as const;

interface UpdateCampaignsLayoutContainerProps {
  campaignsData: UpdateCampaigns_getCampaigns_Query["response"];
  searchText: string | null;
}
const UpdateCampaignsLayoutContainer = ({
  campaignsData,
  searchText,
}: UpdateCampaignsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      UpdateCampaigns_PaginationQuery,
      UpdateCampaigns_UpdateCampaignsFragment$key
    >(CAMPAIGNS_FRAGMENT, campaignsData);

  const findMatches = <T extends readonly string[]>(
    enums: T,
    search: string,
  ): T[number][] => {
    const lower = search.toLowerCase();
    return enums.filter((value) => value.toLowerCase().includes(lower));
  };

  const normalizedSearchText = useMemo(
    () => (searchText ?? "").trim(),
    [searchText],
  );

  const connectionFilter = useMemo(() => {
    if (!normalizedSearchText) return {};

    return {
      or: [
        { name: { ilike: `%${normalizedSearchText}%` } },
        {
          channel: {
            name: { ilike: `%${normalizedSearchText}%` },
          },
        },
        ...findMatches(enumStatuses, normalizedSearchText).map((status) => ({
          status: { eq: status },
        })),
        ...findMatches(enumOutcomes, normalizedSearchText).map((outcome) => ({
          outcome: { eq: outcome },
        })),
      ],
    };
  }, [normalizedSearchText]);

  useSubscription(
    useMemo(
      () => ({
        subscription: CAMPAIGN_CREATED_SUBSCRIPTION,
        variables: {},
        updater: (store) => {
          const campaignRoot = store.getRootField("updateCampaigns");
          const newCampaign = campaignRoot?.getLinkedRecord("created");
          if (!newCampaign) return;

          if (normalizedSearchText !== "") {
            const search = normalizedSearchText.toLowerCase();

            const name = String(
              newCampaign.getValue("name") ?? "",
            ).toLowerCase();

            const channel = newCampaign.getLinkedRecord("channel");
            const channelName = String(
              channel?.getValue("name") ?? "",
            ).toLowerCase();

            const status = String(
              newCampaign.getValue("status") ?? "",
            ).toLowerCase();

            const outcome = String(
              newCampaign.getValue("outcome") ?? "",
            ).toLowerCase();

            const matchesText =
              name.includes(search) || channelName.includes(search);

            const matchesStatus = status.includes(search);
            const matchesOutcome = outcome.includes(search);

            if (!matchesText && !matchesStatus && !matchesOutcome) {
              return;
            }
          }

          const connection = ConnectionHandler.getConnection(
            store.getRoot(),
            "UpdateCampaigns_updateCampaigns",
            { filter: connectionFilter },
          );

          if (!connection) return;

          const newCampaignId = newCampaign.getDataID();

          const edges = connection.getLinkedRecords("edges") ?? [];
          const alreadyPresent = edges.some(
            (edge) =>
              edge.getLinkedRecord("node")?.getDataID() === newCampaignId,
          );

          if (alreadyPresent) return;

          const edge = ConnectionHandler.createEdge(
            store,
            connection,
            newCampaign,
            "CampaignEdge",
          );

          ConnectionHandler.insertEdgeAfter(connection, edge);
        },
      }),
      [connectionFilter, normalizedSearchText],
    ),
  );

  useSubscription(
    useMemo(
      () => ({
        subscription: CAMPAIGN_UPDATED_SUBSCRIPTION,
        variables: {},
      }),
      [],
    ),
  );

  useEffect(() => {
    const handler = _.debounce(() => {
      refetch(
        {
          first: RECORDS_TO_LOAD_FIRST,
          filter: connectionFilter,
        },
        { fetchPolicy: "network-only" },
      );
    }, 500);

    handler();

    return () => {
      handler.cancel();
    };
  }, [connectionFilter, refetch]);

  const loadNextUpdateCampaigns = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const updateCampaignsRef = data?.updateCampaigns || null;

  if (!updateCampaignsRef) {
    return null;
  }

  return (
    <UpdateCampaignsTable
      updateCampaignsRef={updateCampaignsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextUpdateCampaigns : undefined}
    />
  );
};

type UpdateCampaignsContentProps = {
  getCampaignsQuery: PreloadedQuery<UpdateCampaigns_getCampaigns_Query>;
};

const UpdateCampaignsContent = ({
  getCampaignsQuery,
}: UpdateCampaignsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const campaignsData = usePreloadedQuery(
    GET_CAMPAIGNS_QUERY,
    getCampaignsQuery,
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
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <UpdateCampaignsLayoutContainer
          campaignsData={campaignsData}
          searchText={searchText}
        />{" "}
      </Page.Main>
    </Page>
  );
};

const UpdateCampaignsPage = () => {
  const [getCampaignsQuery, getCampaigns] =
    useQueryLoader<UpdateCampaigns_getCampaigns_Query>(GET_CAMPAIGNS_QUERY);

  const fetchCampaigns = useCallback(
    () =>
      getCampaigns(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getCampaigns],
  );

  useEffect(fetchCampaigns, [fetchCampaigns]);

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
        onReset={fetchCampaigns}
      >
        {getCampaignsQuery && (
          <UpdateCampaignsContent getCampaignsQuery={getCampaignsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateCampaignsPage;
