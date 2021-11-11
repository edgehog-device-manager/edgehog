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
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";

import type { ApplianceModelCreate_getHardwareTypes_Query } from "api/__generated__/ApplianceModelCreate_getHardwareTypes_Query.graphql";
import type { ApplianceModelCreate_createApplianceModel_Mutation } from "api/__generated__/ApplianceModelCreate_createApplianceModel_Mutation.graphql";
import Alert from "components/Alert";
import Button from "components/Button";
import Center from "components/Center";
import CreateApplianceModelForm from "forms/CreateApplianceModel";
import type { ApplianceModelData } from "forms/CreateApplianceModel";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import { Link, Route, useNavigate } from "Navigation";

const GET_HARDWARE_TYPES_QUERY = graphql`
  query ApplianceModelCreate_getHardwareTypes_Query {
    hardwareTypes {
      id
      name
    }
  }
`;

const CREATE_APPLIANCE_MODEL_MUTATION = graphql`
  mutation ApplianceModelCreate_createApplianceModel_Mutation(
    $input: CreateApplianceModelInput!
  ) {
    createApplianceModel(input: $input) {
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

type ApplianceModelContentProps = {
  getHardwareTypesQuery: PreloadedQuery<ApplianceModelCreate_getHardwareTypes_Query>;
};

const ApplianceModelContent = ({
  getHardwareTypesQuery,
}: ApplianceModelContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();
  const hardwareTypesData = usePreloadedQuery(
    GET_HARDWARE_TYPES_QUERY,
    getHardwareTypesQuery
  );

  const [createApplianceModel, isCreatingApplianceModel] =
    useMutation<ApplianceModelCreate_createApplianceModel_Mutation>(
      CREATE_APPLIANCE_MODEL_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const hardwareTypes = useMemo(
    () =>
      hardwareTypesData.hardwareTypes.map((hardwareType) => ({
        ...hardwareType,
      })),
    [hardwareTypesData]
  );

  const handleCreateApplianceModel = useCallback(
    (applianceModel: ApplianceModelData) => {
      createApplianceModel({
        variables: { input: applianceModel },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          const applianceModelId = data.createApplianceModel?.applianceModel.id;
          if (applianceModelId) {
            navigate({
              route: Route.applianceModelsEdit,
              params: { applianceModelId },
            });
          } else {
            navigate({ route: Route.applianceModels });
          }
        },
        onError(error) {
          setErrorFeedback(
            <FormattedMessage
              id="pages.ApplianceModelCreate.creationErrorFeedback"
              defaultMessage="Could not create the appliance model, please try again."
            />
          );
        },
        updater(store, data) {
          const applianceModelId = data.createApplianceModel?.applianceModel.id;
          if (applianceModelId) {
            const applianceModel = store.get(applianceModelId);
            const root = store.getRoot();
            const applianceModels = root.getLinkedRecords("applianceModels");
            if (applianceModel && applianceModels) {
              root.setLinkedRecords(
                [applianceModel, ...applianceModels],
                "applianceModels"
              );
            }
          }
        },
      });
    },
    [createApplianceModel, navigate]
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ApplianceModelCreate.title"
            defaultMessage="Create Appliance Model"
          />
        }
      />
      <Page.Main>
        {hardwareTypes.length === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.ApplianceModelCreate.noHardwareTypes.title"
                defaultMessage="You haven't created any hardware type yet"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.ApplianceModelCreate.noHardwareTypes.message"
                defaultMessage="You need at least one hardware type to create an application model"
              />
            </p>
            <Button as={Link} route={Route.hardwareTypesNew}>
              <FormattedMessage
                id="pages.ApplianceModelCreate.noHardwareTypes.createButton"
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
            <CreateApplianceModelForm
              hardwareTypes={hardwareTypes}
              onSubmit={handleCreateApplianceModel}
              isLoading={isCreatingApplianceModel}
            />
          </>
        )}
      </Page.Main>
    </Page>
  );
};

const ApplianceModelCreatePage = () => {
  const [getHardwareTypesQuery, getHardwareTypes] =
    useQueryLoader<ApplianceModelCreate_getHardwareTypes_Query>(
      GET_HARDWARE_TYPES_QUERY
    );

  useEffect(() => getHardwareTypes({}), [getHardwareTypes]);

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
        {getHardwareTypesQuery && (
          <ApplianceModelContent
            getHardwareTypesQuery={getHardwareTypesQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplianceModelCreatePage;
