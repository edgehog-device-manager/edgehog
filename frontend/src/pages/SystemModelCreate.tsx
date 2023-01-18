/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";

import type { SystemModelCreate_getHardwareTypes_Query } from "api/__generated__/SystemModelCreate_getHardwareTypes_Query.graphql";
import type { SystemModelCreate_createSystemModel_Mutation } from "api/__generated__/SystemModelCreate_createSystemModel_Mutation.graphql";
import type { SystemModelCreate_getDefaultTenantLocale_Query } from "api/__generated__/SystemModelCreate_getDefaultTenantLocale_Query.graphql";
import Alert from "components/Alert";
import Button from "components/Button";
import Center from "components/Center";
import CreateSystemModelForm from "forms/CreateSystemModel";
import type { SystemModelChanges } from "forms/CreateSystemModel";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import { Link, Route, useNavigate } from "Navigation";

const GET_HARDWARE_TYPES_QUERY = graphql`
  query SystemModelCreate_getHardwareTypes_Query {
    hardwareTypes {
      id
      name
    }
  }
`;

const GET_DEFAULT_TENANT_LOCALE_QUERY = graphql`
  query SystemModelCreate_getDefaultTenantLocale_Query {
    tenantInfo {
      defaultLocale
    }
  }
`;

const CREATE_SYSTEM_MODEL_MUTATION = graphql`
  mutation SystemModelCreate_createSystemModel_Mutation(
    $input: CreateSystemModelInput!
  ) {
    createSystemModel(input: $input) {
      systemModel {
        id
        name
        handle
        description
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

type SystemModelContentProps = {
  getHardwareTypesQuery: PreloadedQuery<SystemModelCreate_getHardwareTypes_Query>;
  getDefaultTenantLocaleQuery: PreloadedQuery<SystemModelCreate_getDefaultTenantLocale_Query>;
};

const SystemModelContent = ({
  getHardwareTypesQuery,
  getDefaultTenantLocaleQuery,
}: SystemModelContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();
  const hardwareTypesData = usePreloadedQuery(
    GET_HARDWARE_TYPES_QUERY,
    getHardwareTypesQuery
  );
  const defaultLocaleData = usePreloadedQuery(
    GET_DEFAULT_TENANT_LOCALE_QUERY,
    getDefaultTenantLocaleQuery
  );

  const [createSystemModel, isCreatingSystemModel] =
    useMutation<SystemModelCreate_createSystemModel_Mutation>(
      CREATE_SYSTEM_MODEL_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const hardwareTypes = useMemo(
    () =>
      hardwareTypesData.hardwareTypes.map((hardwareType) => ({
        ...hardwareType,
      })),
    [hardwareTypesData]
  );
  const locale = useMemo(
    () => defaultLocaleData.tenantInfo.defaultLocale,
    [defaultLocaleData]
  );

  const handleCreateSystemModel = useCallback(
    (systemModel: SystemModelChanges) => {
      createSystemModel({
        variables: { input: systemModel },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          const systemModelId = data.createSystemModel?.systemModel.id;
          if (systemModelId) {
            navigate({
              route: Route.systemModelsEdit,
              params: { systemModelId },
            });
          } else {
            navigate({ route: Route.systemModels });
          }
        },
        onError(error) {
          setErrorFeedback(
            <FormattedMessage
              id="pages.SystemModelCreate.creationErrorFeedback"
              defaultMessage="Could not create the system model, please try again."
            />
          );
        },
        updater(store) {
          const systemModel = store
            .getRootField("createSystemModel")
            .getLinkedRecord("systemModel");
          const root = store.getRoot();

          const systemModels = root.getLinkedRecords("systemModels");
          if (systemModels) {
            root.setLinkedRecords(
              [...systemModels, systemModel],
              "systemModels"
            );
          }

          root.getLinkedRecords("devices")?.forEach((device) => {
            if (!device.getLinkedRecord("systemModel")) {
              device.invalidateRecord();
            }
          });
        },
      });
    },
    [createSystemModel, navigate]
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.SystemModelCreate.title"
            defaultMessage="Create System Model"
          />
        }
      />
      <Page.Main>
        {hardwareTypes.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.SystemModelCreate.noHardwareTypes.title"
                defaultMessage="You haven't created any hardware type yet"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.SystemModelCreate.noHardwareTypes.message"
                defaultMessage="You need at least one hardware type to create an application model"
              />
            </p>
            <Button as={Link} route={Route.hardwareTypesNew}>
              <FormattedMessage
                id="pages.SystemModelCreate.noHardwareTypes.createButton"
                defaultMessage="Create Hardware Type"
              />
            </Button>
          </Result.EmptyList>
        ) : (
          <>
            <Alert
              show={!!errorFeedback}
              variant="danger"
              onClose={() => setErrorFeedback(null)}
              dismissible
            >
              {errorFeedback}
            </Alert>
            <CreateSystemModelForm
              hardwareTypes={hardwareTypes}
              locale={locale}
              onSubmit={handleCreateSystemModel}
              isLoading={isCreatingSystemModel}
            />
          </>
        )}
      </Page.Main>
    </Page>
  );
};

const SystemModelCreatePage = () => {
  const [getHardwareTypesQuery, getHardwareTypes] =
    useQueryLoader<SystemModelCreate_getHardwareTypes_Query>(
      GET_HARDWARE_TYPES_QUERY
    );
  const [getDefaultTenantLocaleQuery, getDefaultTenantLocale] =
    useQueryLoader<SystemModelCreate_getDefaultTenantLocale_Query>(
      GET_DEFAULT_TENANT_LOCALE_QUERY
    );

  useEffect(() => getHardwareTypes({}), [getHardwareTypes]);
  useEffect(() => getDefaultTenantLocale({}), [getDefaultTenantLocale]);

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
        onReset={() => getHardwareTypes({})}
      >
        {getHardwareTypesQuery && getDefaultTenantLocaleQuery && (
          <SystemModelContent
            getHardwareTypesQuery={getHardwareTypesQuery}
            getDefaultTenantLocaleQuery={getDefaultTenantLocaleQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default SystemModelCreatePage;
