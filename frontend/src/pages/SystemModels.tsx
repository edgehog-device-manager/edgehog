/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
 */

import { Suspense, useEffect, useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";

import type { SystemModels_getSystemModels_Query } from "api/__generated__/SystemModels_getSystemModels_Query.graphql";
import Button from "components/Button";
import Center from "components/Center";
import SystemModelsTable from "components/SystemModelsTable";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import { Link, Route } from "Navigation";

const GET_SYSTEM_MODELS_QUERY = graphql`
  query SystemModels_getSystemModels_Query {
    systemModels {
      id
      handle
      name
      hardwareType {
        name
      }
      partNumbers
    }
  }
`;

type SystemModelsContentProps = {
  getSystemModelsQuery: PreloadedQuery<SystemModels_getSystemModels_Query>;
};

const SystemModelsContent = ({
  getSystemModelsQuery,
}: SystemModelsContentProps) => {
  const systemModelsData = usePreloadedQuery(
    GET_SYSTEM_MODELS_QUERY,
    getSystemModelsQuery
  );

  // TODO: handle readonly type without mapping to mutable type
  const systemModels = useMemo(
    () =>
      systemModelsData.systemModels.map((systemModel) => ({
        ...systemModel,
        partNumbers: [...systemModel.partNumbers],
      })),
    [systemModelsData]
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.SystemModels.title"
            defaultMessage="System Models"
          />
        }
      >
        <Button as={Link} route={Route.systemModelsNew}>
          <FormattedMessage
            id="pages.SystemModels.createButton"
            defaultMessage="Create System Model"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        {systemModels.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.SystemModels.noSystemModels.title"
                defaultMessage="This space is empty"
              />
            }
          >
            <FormattedMessage
              id="pages.SystemModels.noSystemModels.message"
              defaultMessage="You haven't created any system model yet."
            />
          </Result.EmptyList>
        ) : (
          <SystemModelsTable data={systemModels} />
        )}
      </Page.Main>
    </Page>
  );
};

const SystemModelsPage = () => {
  const [getSystemModelsQuery, getSystemModels] =
    useQueryLoader<SystemModels_getSystemModels_Query>(GET_SYSTEM_MODELS_QUERY);

  useEffect(() => getSystemModels({}), [getSystemModels]);

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
        onReset={() => getSystemModels({})}
      >
        {getSystemModelsQuery && (
          <SystemModelsContent getSystemModelsQuery={getSystemModelsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default SystemModelsPage;
