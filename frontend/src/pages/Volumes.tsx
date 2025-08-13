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

import { Suspense, useCallback, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { Volumes_getVolumes_Query } from "api/__generated__/Volumes_getVolumes_Query.graphql";

import Page from "components/Page";
import Center from "components/Center";
import Spinner from "components/Spinner";
import VolumesTable from "components/VolumesTable";
import Button from "components/Button";
import { Link, Route } from "Navigation";

const GET_VOLUMES_QUERY = graphql`
  query Volumes_getVolumes_Query {
    volumes {
      results {
        ...VolumesTable_VolumeFragment
      }
    }
  }
`;

interface VolumesContentProps {
  getVolumesQuery: PreloadedQuery<Volumes_getVolumes_Query>;
}

const VolumesContent = ({ getVolumesQuery }: VolumesContentProps) => {
  const { volumes } = usePreloadedQuery(GET_VOLUMES_QUERY, getVolumesQuery);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage id="pages.Volumes.title" defaultMessage="Volumes" />
        }
      >
        <Button as={Link} route={Route.volumesNew}>
          <FormattedMessage
            id="pages.Volumes.createButton"
            defaultMessage="Create Volume"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <VolumesTable volumesRef={volumes?.results ?? []} />
      </Page.Main>
    </Page>
  );
};

const VolumesPage = () => {
  const [getVolumesQuery, getVolumes] =
    useQueryLoader<Volumes_getVolumes_Query>(GET_VOLUMES_QUERY);

  const fetchVolumes = useCallback(
    () => getVolumes({}, { fetchPolicy: "store-and-network" }),
    [getVolumes],
  );

  useEffect(fetchVolumes, [fetchVolumes]);

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
        onReset={fetchVolumes}
      >
        {getVolumesQuery && (
          <VolumesContent getVolumesQuery={getVolumesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default VolumesPage;
