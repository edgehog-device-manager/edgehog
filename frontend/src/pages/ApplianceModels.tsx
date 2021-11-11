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

import type { ApplianceModels_getApplianceModels_Query } from "api/__generated__/ApplianceModels_getApplianceModels_Query.graphql";
import Button from "components/Button";
import Center from "components/Center";
import ApplianceModelsTable from "components/ApplianceModelsTable";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import { Link, Route } from "Navigation";

const GET_APPLIANCE_MODELS_QUERY = graphql`
  query ApplianceModels_getApplianceModels_Query {
    applianceModels {
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

type ApplianceModelsContentProps = {
  getApplianceModelsQuery: PreloadedQuery<ApplianceModels_getApplianceModels_Query>;
};

const ApplianceModelsContent = ({
  getApplianceModelsQuery,
}: ApplianceModelsContentProps) => {
  const applianceModelsData = usePreloadedQuery(
    GET_APPLIANCE_MODELS_QUERY,
    getApplianceModelsQuery
  );

  // TODO: handle readonly type without mapping to mutable type
  const applianceModels = useMemo(
    () =>
      applianceModelsData.applianceModels.map((applianceModel) => ({
        ...applianceModel,
        partNumbers: [...applianceModel.partNumbers],
      })),
    [applianceModelsData]
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ApplianceModels.title"
            defaultMessage="Appliance Models"
          />
        }
      >
        <Button as={Link} route={Route.applianceModelsNew}>
          <FormattedMessage
            id="pages.ApplianceModels.createButton"
            defaultMessage="Create Appliance Model"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        {applianceModels.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.ApplianceModels.noApplianceModels.title"
                defaultMessage="This space is empty"
              />
            }
          >
            <FormattedMessage
              id="pages.ApplianceModels.noApplianceModels.message"
              defaultMessage="You haven't created any appliance model yet."
            />
          </Result.EmptyList>
        ) : (
          <ApplianceModelsTable data={applianceModels} />
        )}
      </Page.Main>
    </Page>
  );
};

const ApplianceModelsPage = () => {
  const [getApplianceModelsQuery, getApplianceModels] =
    useQueryLoader<ApplianceModels_getApplianceModels_Query>(
      GET_APPLIANCE_MODELS_QUERY
    );

  useEffect(() => getApplianceModels({}), [getApplianceModels]);

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
        onReset={() => getApplianceModels({})}
      >
        {getApplianceModelsQuery && (
          <ApplianceModelsContent
            getApplianceModelsQuery={getApplianceModelsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplianceModelsPage;
