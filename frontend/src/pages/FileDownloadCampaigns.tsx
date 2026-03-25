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

import type { FileDownloadCampaigns_FileDownloadCampaignsFragment$key } from "@/api/__generated__/FileDownloadCampaigns_FileDownloadCampaignsFragment.graphql";
import type { FileDownloadCampaigns_getCampaigns_Query } from "@/api/__generated__/FileDownloadCampaigns_getCampaigns_Query.graphql";
import type { FileDownloadCampaigns_PaginationQuery } from "@/api/__generated__/FileDownloadCampaigns_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import FileDownloadCampaignsTable from "@/components/FileDownloadCampaignsTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_CAMPAIGNS_QUERY = graphql`
  query FileDownloadCampaigns_getCampaigns_Query(
    $first: Int
    $after: String
    $filter: CampaignFilterInput = {}
  ) {
    ...FileDownloadCampaigns_FileDownloadCampaignsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const CAMPAIGNS_FRAGMENT = graphql`
  fragment FileDownloadCampaigns_FileDownloadCampaignsFragment on RootQueryType
  @refetchable(queryName: "FileDownloadCampaigns_PaginationQuery") {
    fileDownloadCampaigns(first: $first, after: $after, filter: $filter)
      @connection(key: "FileDownloadCampaigns_fileDownloadCampaigns") {
      edges {
        node {
          __typename
        }
      }
      ...FileDownloadCampaignsTable_CampaignEdgeFragment
    }
  }
`;

const CAMPAIGN_UPDATED_SUBSCRIPTION = graphql`
  subscription FileDownloadCampaigns_campaign_updated_Subscription {
    fileDownloadCampaigns {
      updated {
        id
        status
        outcome
      }
    }
  }
`;

const CAMPAIGN_CREATED_SUBSCRIPTION = graphql`
  subscription FileDownloadCampaigns_campaign_created_Subscription {
    fileDownloadCampaigns {
      created {
        id
        name
        status
        outcome
        channel {
          id
          name
        }
        campaignMechanism {
          __typename
          ... on FileDownload {
            destinationType
            file {
              id
              name
              repository {
                id
                name
              }
            }
          }
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

interface FileDownloadCampaignsLayoutContainerProps {
  campaignsData: FileDownloadCampaigns_getCampaigns_Query["response"];
  searchText: string | null;
}

const FileDownloadCampaignsLayoutContainer = ({
  campaignsData,
  searchText,
}: FileDownloadCampaignsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      FileDownloadCampaigns_PaginationQuery,
      FileDownloadCampaigns_FileDownloadCampaignsFragment$key
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
          const campaignRoot = store.getRootField("fileDownloadCampaigns");
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
            "FileDownloadCampaigns_fileDownloadCampaigns",
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

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: connectionFilter,
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch, connectionFilter],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextFileDownloadCampaigns = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const fileDownloadCampaignsRef = data?.fileDownloadCampaigns || null;

  if (!fileDownloadCampaignsRef) {
    return null;
  }

  return (
    <FileDownloadCampaignsTable
      fileDownloadCampaignsRef={fileDownloadCampaignsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextFileDownloadCampaigns : undefined}
    />
  );
};

interface FileDownloadCampaignsContentProps {
  getCampaignsQuery: PreloadedQuery<FileDownloadCampaigns_getCampaigns_Query>;
}

const FileDownloadCampaignsContent = ({
  getCampaignsQuery,
}: FileDownloadCampaignsContentProps) => {
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
            id="pages.FileDownloadCampaigns.title"
            defaultMessage="File Download Campaigns"
          />
        }
      >
        <Button as={Link} route={Route.fileDownloadCampaignsNew}>
          <FormattedMessage
            id="pages.FileDownloadCampaigns.createButton"
            defaultMessage="Create Campaign"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />

        <FileDownloadCampaignsLayoutContainer
          campaignsData={campaignsData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const FileDownloadCampaignsPage = () => {
  const [getCampaignsQuery, getCampaigns] =
    useQueryLoader<FileDownloadCampaigns_getCampaigns_Query>(
      GET_CAMPAIGNS_QUERY,
    );

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
          <FileDownloadCampaignsContent getCampaignsQuery={getCampaignsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default FileDownloadCampaignsPage;
