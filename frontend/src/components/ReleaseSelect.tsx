/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import _ from "lodash";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import type { FallbackProps } from "react-error-boundary";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import Select from "react-select";
import semver from "semver";

import { ReleaseSelect_getApplication_Query } from "api/__generated__/ReleaseSelect_getApplication_Query.graphql";
import { ReleaseSelect_ReleasePaginationQuery } from "api/__generated__/ReleaseSelect_ReleasePaginationQuery.graphql";
import {
  ReleaseSelect_ReleasesFragment$data,
  ReleaseSelect_ReleasesFragment$key,
} from "api/__generated__/ReleaseSelect_ReleasesFragment.graphql";

import Button from "components/Button";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "constants";
import { ApplicationRecord } from "forms/CreateDeploymentCampaign";

const GET_APPLICATION_QUERY = graphql`
  query ReleaseSelect_getApplication_Query(
    $applicationId: ID!
    $first: Int
    $after: String
    $filter: ReleaseFilterInput = {}
  ) {
    application(id: $applicationId) {
      ...ReleaseSelect_ReleasesFragment @arguments(filter: $filter)
    }
  }
`;

const RELEASE_SELECT_OPTIONS_FRAGMENT = graphql`
  fragment ReleaseSelect_ReleasesFragment on Application
  @refetchable(queryName: "ReleaseSelect_ReleasePaginationQuery")
  @argumentDefinitions(filter: { type: "ReleaseFilterInput" }) {
    releases(first: $first, after: $after, filter: $filter)
      @connection(key: "ReleaseSelect_releases") {
      edges {
        node {
          id
          version
        }
      }
    }
  }
`;

export type ReleaseRecord = NonNullable<
  NonNullable<ReleaseSelect_ReleasesFragment$data["releases"]>["edges"]
>[number]["node"];

type ReleaseSelectProps = {
  isTarget: boolean;
  selectedApp: ApplicationRecord;
  selectedRelease?: ReleaseRecord;
  deploymentCampaignReleaseOptionsRef: ReleaseSelect_ReleasesFragment$key | null;
  controllerProps: ControllerProps;
};

const ReleaseSelect = ({
  isTarget,
  selectedApp,
  selectedRelease,
  deploymentCampaignReleaseOptionsRef,
  controllerProps,
}: ReleaseSelectProps) => {
  const intl = useIntl();

  const {
    data: paginationData,
    loadNext: loadNext,
    hasNext: hasNext,
    isLoadingNext: isLoadingNext,
    refetch: refetch,
  } = usePaginationFragment<
    ReleaseSelect_ReleasePaginationQuery,
    ReleaseSelect_ReleasesFragment$key
  >(RELEASE_SELECT_OPTIONS_FRAGMENT, deploymentCampaignReleaseOptionsRef);

  const [searchText, setSearchText] = useState<string | null>(null);

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
              filter: { version: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextOptions = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const releaseOptions = useMemo(() => {
    const releases =
      paginationData?.releases?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is ReleaseRecord => node != null) ?? [];

    if (isTarget && selectedApp && selectedRelease) {
      const targetReleases =
        releases.filter((release) =>
          semver.gt(release.version, selectedRelease.version || "0.0.0"),
        ) ?? [];
      return targetReleases;
    }

    return releases;
  }, [paginationData, isTarget, selectedApp, selectedRelease]);

  const getReleaseLabel = (release: ReleaseRecord) => release.version;
  const getReleaseValue = (release: ReleaseRecord) => release.id;
  const noReleaseOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "components.ReleaseSelect.noReleasesFoundMatching",
            defaultMessage: 'No releases found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "components.ReleaseSelect.noReleasesAvailable",
          defaultMessage: "No releases available",
        });

  return (
    <Select
      value={controllerProps.value}
      onChange={controllerProps.onChange}
      className={controllerProps.invalid ? "is-invalid" : ""}
      placeholder={intl.formatMessage({
        id: "components.ReleaseSelect.releaseOption",
        defaultMessage: "Search or select a release...",
      })}
      isClearable
      options={releaseOptions}
      getOptionLabel={getReleaseLabel}
      getOptionValue={getReleaseValue}
      noOptionsMessage={({ inputValue }) => noReleaseOptionsMessage(inputValue)}
      isLoading={isLoadingNext}
      onMenuScrollToBottom={hasNext ? loadNextOptions : undefined}
      onInputChange={(text) => setSearchText(text)}
    />
  );
};

type ReleaseSelectContentProps = {
  isTarget: boolean;
  selectedApp: ApplicationRecord;
  selectedRelease?: ReleaseRecord;
  applicationQuery: PreloadedQuery<ReleaseSelect_getApplication_Query>;
  controllerProps: ControllerProps;
};

const ReleaseSelectContent = ({
  isTarget,
  selectedApp,
  selectedRelease,
  applicationQuery,
  controllerProps,
}: ReleaseSelectContentProps) => {
  const { application } = usePreloadedQuery(
    GET_APPLICATION_QUERY,
    applicationQuery,
  );

  return (
    <ReleaseSelect
      isTarget={isTarget}
      selectedApp={selectedApp}
      selectedRelease={selectedRelease}
      deploymentCampaignReleaseOptionsRef={application}
      controllerProps={controllerProps}
    />
  );
};

const ErrorFallback = ({ resetErrorBoundary }: FallbackProps) => (
  <Stack direction="horizontal">
    <span>
      <FormattedMessage
        id="components.ReleaseSelect.ErrorFallback.message"
        defaultMessage="Failed to load Releases list."
      />
    </span>
    <Button variant="link" onClick={resetErrorBoundary}>
      <FormattedMessage
        id="components.ReleaseSelect.ErrorFallback.reloadButton"
        defaultMessage="Reload"
      />
    </Button>
  </Stack>
);

type ControllerProps = {
  value?: ReleaseRecord;
  invalid: boolean;
  onChange: (...event: any[]) => void;
};

type ReleaseSelectWrapperProps = {
  isTarget?: boolean;
  selectedApp: ApplicationRecord;
  selectedRelease?: ReleaseRecord;
  controllerProps: ControllerProps;
};

const ReleaseSelectWrapper = ({
  isTarget = false,
  selectedApp,
  selectedRelease,
  controllerProps,
}: ReleaseSelectWrapperProps) => {
  const [getApplicationQuery, getApplication] =
    useQueryLoader<ReleaseSelect_getApplication_Query>(GET_APPLICATION_QUERY);

  const fetchApplication = useCallback(() => {
    getApplication(
      {
        applicationId: selectedApp.id,
        first: RECORDS_TO_LOAD_FIRST,
      },
      { fetchPolicy: "network-only" },
    );
  }, [getApplication, selectedApp]);

  useEffect(fetchApplication, [fetchApplication]);

  // Clear selected target release if selectedRelease is >= currently selected target release
  useEffect(() => {
    if (
      controllerProps.value &&
      selectedRelease &&
      semver.gte(selectedRelease.version, controllerProps.value.version)
    ) {
      controllerProps.onChange(null);
    }
  }, [selectedRelease, controllerProps.value, controllerProps]);

  return (
    <ErrorBoundary onReset={fetchApplication} FallbackComponent={ErrorFallback}>
      <Suspense fallback={<Spinner />}>
        {getApplicationQuery && (
          <ReleaseSelectContent
            isTarget={isTarget}
            selectedApp={selectedApp}
            selectedRelease={selectedRelease}
            applicationQuery={getApplicationQuery}
            controllerProps={controllerProps}
          />
        )}
      </Suspense>
    </ErrorBoundary>
  );
};

export default ReleaseSelectWrapper;
