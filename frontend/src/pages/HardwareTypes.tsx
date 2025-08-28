/*
  This file is part of Edgehog.

  Copyright 2021-2025 SECO Mind Srl

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

import { Suspense, useEffect, useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { HardwareTypes_getHardwareTypes_Query } from "api/__generated__/HardwareTypes_getHardwareTypes_Query.graphql";

import Button from "components/Button";
import Center from "components/Center";
import HardwareTypesTable from "components/HardwareTypesTable";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import { Link, Route } from "Navigation";

const HARDWARE_TYPES_TO_LOAD_FIRST = 40;

const GET_HARDWARE_TYPES_QUERY = graphql`
  query HardwareTypes_getHardwareTypes_Query(
    $first: Int
    $after: String
    $filter: HardwareTypeFilterInput
  ) {
    hardwareTypes(first: $first, after: $after, filter: $filter) {
      count
    }
    ...HardwareTypesTable_HardwareTypesFragment @arguments(filter: $filter)
  }
`;

interface HardwareTypesContentProps {
  getHardwareTypesQuery: PreloadedQuery<HardwareTypes_getHardwareTypes_Query>;
}

const HardwareTypesContent = ({
  getHardwareTypesQuery,
}: HardwareTypesContentProps) => {
  const hardwareTypes = usePreloadedQuery(
    GET_HARDWARE_TYPES_QUERY,
    getHardwareTypesQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.HardwareTypes.title"
            defaultMessage="Hardware Types"
          />
        }
      >
        <Button as={Link} route={Route.hardwareTypesNew}>
          <FormattedMessage
            id="pages.HardwareTypes.createButton"
            defaultMessage="Create Hardware Type"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        {hardwareTypes.hardwareTypes?.count === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.HardwareTypes.noHardwareTypes.title"
                defaultMessage="This space is empty"
              />
            }
          >
            <FormattedMessage
              id="pages.HardwareTypes.noHardwareTypes.message"
              defaultMessage="You haven't created any hardware type yet."
            />
          </Result.EmptyList>
        ) : (
          <HardwareTypesTable hardwareTypesRef={hardwareTypes} />
        )}
      </Page.Main>
    </Page>
  );
};

const HardwareTypesPage = () => {
  const [getHardwareTypesQuery, getHardwareTypes] =
    useQueryLoader<HardwareTypes_getHardwareTypes_Query>(
      GET_HARDWARE_TYPES_QUERY,
    );

  const fetchHardwareTypes = useCallback(
    () =>
      getHardwareTypes(
        { first: HARDWARE_TYPES_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getHardwareTypes],
  );

  useEffect(fetchHardwareTypes, [fetchHardwareTypes]);

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
        onReset={fetchHardwareTypes}
      >
        {getHardwareTypesQuery && (
          <HardwareTypesContent getHardwareTypesQuery={getHardwareTypesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default HardwareTypesPage;
