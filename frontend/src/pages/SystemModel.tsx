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

import type { SystemModel_getSystemModel_Query } from "api/__generated__/SystemModel_getSystemModel_Query.graphql";
import type { SystemModel_updateSystemModel_Mutation } from "api/__generated__/SystemModel_updateSystemModel_Mutation.graphql";
import type { SystemModel_getDefaultTenantLocale_Query } from "api/__generated__/SystemModel_getDefaultTenantLocale_Query.graphql";
import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateSystemModelForm from "forms/UpdateSystemModel";
import type {
  SystemModelChanges,
  SystemModelData,
} from "forms/UpdateSystemModel";

const GET_SYSTEM_MODEL_QUERY = graphql`
  query SystemModel_getSystemModel_Query($id: ID!) {
    systemModel(id: $id) {
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
  query SystemModel_getDefaultTenantLocale_Query {
    tenantInfo {
      defaultLocale
    }
  }
`;

const UPDATE_SYSTEM_MODEL_MUTATION = graphql`
  mutation SystemModel_updateSystemModel_Mutation(
    $input: UpdateSystemModelInput!
  ) {
    updateSystemModel(input: $input) {
      systemModel {
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

const systemModelDiff = (a1: SystemModelData, a2: SystemModelChanges) => {
  let diff: Partial<SystemModelChanges> = {};
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

interface SystemModelContentProps {
  getSystemModelQuery: PreloadedQuery<SystemModel_getSystemModel_Query>;
  getDefaultTenantLocaleQuery: PreloadedQuery<SystemModel_getDefaultTenantLocale_Query>;
}

const SystemModelContent = ({
  getSystemModelQuery,
  getDefaultTenantLocaleQuery,
}: SystemModelContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const systemModelData = usePreloadedQuery(
    GET_SYSTEM_MODEL_QUERY,
    getSystemModelQuery
  );
  const defaultLocaleData = usePreloadedQuery(
    GET_DEFAULT_TENANT_LOCALE_QUERY,
    getDefaultTenantLocaleQuery
  );

  const [updateSystemModel, isUpdatingSystemModel] =
    useMutation<SystemModel_updateSystemModel_Mutation>(
      UPDATE_SYSTEM_MODEL_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const systemModel = useMemo(() => {
    const systemModel = systemModelData.systemModel;
    if (!systemModel) {
      return null;
    }
    return {
      ...systemModel,
      hardwareType: { ...systemModel.hardwareType },
      partNumbers: [...systemModel.partNumbers],
    };
  }, [systemModelData.systemModel]);

  const locale = useMemo(
    () => defaultLocaleData.tenantInfo.defaultLocale,
    [defaultLocaleData]
  );

  const handleUpdateSystemModel = useCallback(
    (systemModelChanges: SystemModelChanges) => {
      if (!systemModel) {
        return null;
      }
      const input = {
        systemModelId: systemModel.id,
        ...systemModelDiff(systemModel, systemModelChanges),
      };
      updateSystemModel({
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
              id="pages.SystemModelUpdate.creationErrorFeedback"
              defaultMessage="Could not update the system model, please try again."
            />
          );
        },
        optimisticResponse: {
          updateSystemModel: {
            systemModel: {
              ...systemModel!,
              ..._.pick(systemModelChanges, [
                "name",
                "handle",
                "partNumbers",
                "description",
              ]),
              pictureUrl:
                systemModelChanges.pictureFile instanceof File
                  ? URL.createObjectURL(systemModelChanges.pictureFile)
                  : _.isString(systemModelChanges.pictureUrl) ||
                    _.isNull(systemModelChanges.pictureUrl)
                  ? systemModelChanges.pictureUrl
                  : systemModel.pictureUrl,
            },
          },
        },
      });
    },
    [updateSystemModel, systemModel]
  );

  if (!systemModel) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.SystemModel.systemModelNotFound.title"
            defaultMessage="System model not found."
          />
        }
      >
        <Link route={Route.systemModels}>
          <FormattedMessage
            id="pages.SystemModel.systemModelNotFound.message"
            defaultMessage="Return to the system model list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={systemModel.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <UpdateSystemModelForm
          initialData={systemModel}
          locale={systemModel.description?.locale || locale}
          onSubmit={handleUpdateSystemModel}
          isLoading={isUpdatingSystemModel}
        />
      </Page.Main>
    </Page>
  );
};

const SystemModelPage = () => {
  const { systemModelId = "" } = useParams();

  const [getSystemModelQuery, getSystemModel] =
    useQueryLoader<SystemModel_getSystemModel_Query>(GET_SYSTEM_MODEL_QUERY);
  const [getDefaultTenantLocaleQuery, getDefaultTenantLocale] =
    useQueryLoader<SystemModel_getDefaultTenantLocale_Query>(
      GET_DEFAULT_TENANT_LOCALE_QUERY
    );

  useEffect(() => getDefaultTenantLocale({}), [getDefaultTenantLocale]);
  useEffect(() => {
    getSystemModel({ id: systemModelId });
  }, [getSystemModel, systemModelId]);

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
          getSystemModel({ id: systemModelId });
        }}
      >
        {getSystemModelQuery && getDefaultTenantLocaleQuery && (
          <SystemModelContent
            getSystemModelQuery={getSystemModelQuery}
            getDefaultTenantLocaleQuery={getDefaultTenantLocaleQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default SystemModelPage;
