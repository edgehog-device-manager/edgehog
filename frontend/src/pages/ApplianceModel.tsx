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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";
import { FormattedMessage } from "react-intl";
import _ from "lodash";

import type { ApplianceModel_getApplianceModel_Query } from "api/__generated__/ApplianceModel_getApplianceModel_Query.graphql";
import type { ApplianceModel_updateApplianceModel_Mutation } from "api/__generated__/ApplianceModel_updateApplianceModel_Mutation.graphql";
import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateApplianceModelForm from "forms/UpdateApplianceModel";
import type { ApplianceModelData } from "forms/UpdateApplianceModel";

const GET_APPLIANCE_MODEL_QUERY = graphql`
  query ApplianceModel_getApplianceModel_Query($id: ID!) {
    applianceModel(id: $id) {
      id
      name
      handle
      hardwareType {
        name
      }
      partNumbers
    }
  }
`;

const UPDATE_APPLIANCE_MODEL_MUTATION = graphql`
  mutation ApplianceModel_updateApplianceModel_Mutation(
    $input: UpdateApplianceModelInput!
  ) {
    updateApplianceModel(input: $input) {
      applianceModel {
        id
        name
        handle
        hardwareType {
          name
        }
        partNumbers
      }
    }
  }
`;

interface ApplianceModelContentProps {
  getApplianceModelQuery: PreloadedQuery<ApplianceModel_getApplianceModel_Query>;
}

const ApplianceModelContent = ({
  getApplianceModelQuery,
}: ApplianceModelContentProps) => {
  const { applianceModelId = "" } = useParams();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const applianceModelData = usePreloadedQuery(
    GET_APPLIANCE_MODEL_QUERY,
    getApplianceModelQuery
  );

  const [updateApplianceModel, isUpdatingApplianceModel] =
    useMutation<ApplianceModel_updateApplianceModel_Mutation>(
      UPDATE_APPLIANCE_MODEL_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const applianceModel = useMemo(
    () =>
      applianceModelData.applianceModel && {
        ...applianceModelData.applianceModel,
        hardwareType: { ...applianceModelData.applianceModel.hardwareType },
        partNumbers: [...applianceModelData.applianceModel.partNumbers],
      },
    [applianceModelData.applianceModel]
  );

  const handleUpdateApplianceModel = useCallback(
    (applianceModel: ApplianceModelData) => {
      const input = {
        applianceModelId,
        name: applianceModel.name,
        handle: applianceModel.handle,
        partNumbers: applianceModel.partNumbers,
      };
      updateApplianceModel({
        variables: { input },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError(error) {
          setErrorFeedback(
            <FormattedMessage
              id="pages.ApplianceModelUpdate.creationErrorFeedback"
              defaultMessage="Could not update the appliance model, please try again."
            />
          );
        },
      });
    },
    [updateApplianceModel, applianceModelId]
  );

  if (!applianceModel) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.ApplianceModel.applianceModelNotFound.title"
            defaultMessage="Appliance model not found."
          />
        }
      >
        <Link route={Route.applianceModels}>
          <FormattedMessage
            id="pages.ApplianceModel.applianceModelNotFound.message"
            defaultMessage="Return to the appliance model list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={applianceModel.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <UpdateApplianceModelForm
          initialData={_.pick(applianceModel, [
            "name",
            "handle",
            "hardwareType",
            "partNumbers",
          ])}
          onSubmit={handleUpdateApplianceModel}
          isLoading={isUpdatingApplianceModel}
        />
      </Page.Main>
    </Page>
  );
};

const ApplianceModelPage = () => {
  const { applianceModelId = "" } = useParams();

  const [getApplianceModelQuery, getApplianceModel] =
    useQueryLoader<ApplianceModel_getApplianceModel_Query>(
      GET_APPLIANCE_MODEL_QUERY
    );

  useEffect(() => {
    getApplianceModel({ id: applianceModelId });
  }, [getApplianceModel, applianceModelId]);

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
        onReset={() => {
          getApplianceModel({ id: applianceModelId });
        }}
      >
        {getApplianceModelQuery && (
          <ApplianceModelContent
            getApplianceModelQuery={getApplianceModelQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplianceModelPage;
