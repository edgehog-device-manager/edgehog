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
import type { ApplianceModel_getDefaultTenantLocale_Query } from "api/__generated__/ApplianceModel_getDefaultTenantLocale_Query.graphql";
import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateApplianceModelForm from "forms/UpdateApplianceModel";
import type {
  ApplianceModelChanges,
  ApplianceModelData,
} from "forms/UpdateApplianceModel";

const GET_APPLIANCE_MODEL_QUERY = graphql`
  query ApplianceModel_getApplianceModel_Query($id: ID!) {
    applianceModel(id: $id) {
      id
      name
      handle
      description {
        locale
        text
      }
      hardwareType {
        id
        name
      }
      partNumbers
      pictureUrl
    }
  }
`;

const GET_DEFAULT_TENANT_LOCALE_QUERY = graphql`
  query ApplianceModel_getDefaultTenantLocale_Query {
    tenantInfo {
      defaultLocale
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
        description {
          locale
          text
        }
        hardwareType {
          id
          name
        }
        partNumbers
        pictureUrl
      }
    }
  }
`;

const applianceModelDiff = (
  a1: ApplianceModelData,
  a2: ApplianceModelChanges
) => {
  let diff: Partial<ApplianceModelChanges> = {};
  if (a1.name !== a2.name) {
    diff.name = a2.name;
  }
  if (a1.handle !== a2.handle) {
    diff.handle = a2.handle;
  }
  if (!_.isEqual(a1.partNumbers, a2.partNumbers)) {
    diff.partNumbers = a2.partNumbers;
  }
  if (!_.isEqual(a1.description, a2.description)) {
    diff.description = a2.description;
  }
  if ("pictureFile" in a2 && a2.pictureFile) {
    diff.pictureFile = a2.pictureFile;
  } else if (!_.isEqual(a1.pictureUrl, a2.pictureUrl)) {
    diff.pictureUrl = a2.pictureUrl;
  }
  return diff;
};

interface ApplianceModelContentProps {
  getApplianceModelQuery: PreloadedQuery<ApplianceModel_getApplianceModel_Query>;
  getDefaultTenantLocaleQuery: PreloadedQuery<ApplianceModel_getDefaultTenantLocale_Query>;
}

const ApplianceModelContent = ({
  getApplianceModelQuery,
  getDefaultTenantLocaleQuery,
}: ApplianceModelContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const applianceModelData = usePreloadedQuery(
    GET_APPLIANCE_MODEL_QUERY,
    getApplianceModelQuery
  );
  const defaultLocaleData = usePreloadedQuery(
    GET_DEFAULT_TENANT_LOCALE_QUERY,
    getDefaultTenantLocaleQuery
  );

  const [updateApplianceModel, isUpdatingApplianceModel] =
    useMutation<ApplianceModel_updateApplianceModel_Mutation>(
      UPDATE_APPLIANCE_MODEL_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const applianceModel = useMemo(() => {
    const applianceModel = applianceModelData.applianceModel;
    if (!applianceModel) {
      return null;
    }
    return {
      ...applianceModel,
      hardwareType: { ...applianceModel.hardwareType },
      partNumbers: [...applianceModel.partNumbers],
    };
  }, [applianceModelData.applianceModel]);

  const locale = useMemo(
    () => defaultLocaleData.tenantInfo.defaultLocale,
    [defaultLocaleData]
  );

  const handleUpdateApplianceModel = useCallback(
    (applianceModelChanges: ApplianceModelChanges) => {
      if (!applianceModel) {
        return null;
      }
      const input = {
        applianceModelId: applianceModel.id,
        ...applianceModelDiff(applianceModel, applianceModelChanges),
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
        optimisticResponse: {
          updateApplianceModel: {
            applianceModel: {
              ...applianceModel!,
              ..._.pick(applianceModelChanges, [
                "name",
                "handle",
                "partNumbers",
                "description",
              ]),
              pictureUrl:
                applianceModelChanges.pictureFile instanceof File
                  ? URL.createObjectURL(applianceModelChanges.pictureFile)
                  : _.isString(applianceModelChanges.pictureUrl) ||
                    _.isNull(applianceModelChanges.pictureUrl)
                  ? applianceModelChanges.pictureUrl
                  : applianceModel.pictureUrl,
            },
          },
        },
      });
    },
    [updateApplianceModel, applianceModel]
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
          initialData={applianceModel}
          locale={applianceModel.description?.locale || locale}
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
  const [getDefaultTenantLocaleQuery, getDefaultTenantLocale] =
    useQueryLoader<ApplianceModel_getDefaultTenantLocale_Query>(
      GET_DEFAULT_TENANT_LOCALE_QUERY
    );

  useEffect(() => getDefaultTenantLocale({}), [getDefaultTenantLocale]);
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
        {getApplianceModelQuery && getDefaultTenantLocaleQuery && (
          <ApplianceModelContent
            getApplianceModelQuery={getApplianceModelQuery}
            getDefaultTenantLocaleQuery={getDefaultTenantLocaleQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplianceModelPage;
