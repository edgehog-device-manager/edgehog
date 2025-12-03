/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2025 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { Suspense, useCallback, useEffect, useState } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type {
  SystemModelCreate_getOptions_Query,
  SystemModelCreate_getOptions_Query$data,
} from "@/api/__generated__/SystemModelCreate_getOptions_Query.graphql";
import type { SystemModelCreate_createSystemModel_Mutation } from "@/api/__generated__/SystemModelCreate_createSystemModel_Mutation.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import CreateSystemModelForm from "@/forms/CreateSystemModel";
import type { SystemModelChanges } from "@/forms/CreateSystemModel";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import { Link, Route, useNavigate } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const GET_CREATE_SYSTEM_MODEL_OPTIONS_QUERY = graphql`
  query SystemModelCreate_getOptions_Query(
    $first: Int
    $after: String
    $filter: HardwareTypeFilterInput = {}
  ) {
    hardwareTypes(first: $first, after: $after, filter: $filter) {
      count
    }
    ...CreateSystemModel_OptionsFragment @arguments(filter: $filter)
  }
`;

const CREATE_SYSTEM_MODEL_MUTATION = graphql`
  mutation SystemModelCreate_createSystemModel_Mutation(
    $input: CreateSystemModelInput!
  ) {
    createSystemModel(input: $input) {
      result {
        id
      }
    }
  }
`;

type SystemModelProps = {
  systemModelOptions: SystemModelCreate_getOptions_Query$data;
};

const SystemModel = ({ systemModelOptions }: SystemModelProps) => {
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [createSystemModel, isCreatingSystemModel] =
    useMutation<SystemModelCreate_createSystemModel_Mutation>(
      CREATE_SYSTEM_MODEL_MUTATION,
    );

  const handleCreateSystemModel = useCallback(
    (systemModel: SystemModelChanges) => {
      createSystemModel({
        variables: { input: systemModel },
        onCompleted(data, errors) {
          const systemModelId = data.createSystemModel?.result?.id;
          if (systemModelId) {
            return navigate({
              route: Route.systemModelsEdit,
              params: { systemModelId },
            });
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.SystemModelCreate.creationErrorFeedback"
              defaultMessage="Could not create the system model, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createSystemModel?.result) {
            return;
          }

          const systemModel = store
            .getRootField("createSystemModel")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const connection = ConnectionHandler.getConnection(
            root,
            "SystemModelsTable_systemModels",
          );

          if (connection && systemModel) {
            const edge = ConnectionHandler.createEdge(
              store,
              connection,
              systemModel,
              "SystemModelEdge",
            );
            ConnectionHandler.insertEdgeBefore(connection, edge);
          }

          root.getLinkedRecords("devices")?.forEach((device) => {
            if (!device.getLinkedRecord("systemModel")) {
              device.invalidateRecord();
            }
          });
        },
      });
    },
    [createSystemModel, navigate],
  );

  return (
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
        optionsRef={systemModelOptions}
        onSubmit={handleCreateSystemModel}
        isLoading={isCreatingSystemModel}
      />
    </>
  );
};

const NoHardwareTypes = () => (
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
);

type SystemModelWrapperProps = {
  getCreateSystemModelOptionsQuery: PreloadedQuery<SystemModelCreate_getOptions_Query>;
};

const SystemModelWrapper = ({
  getCreateSystemModelOptionsQuery,
}: SystemModelWrapperProps) => {
  const systemModelOptions = usePreloadedQuery(
    GET_CREATE_SYSTEM_MODEL_OPTIONS_QUERY,
    getCreateSystemModelOptionsQuery,
  );
  const { hardwareTypes } = systemModelOptions;
  if (hardwareTypes?.count === 0) {
    return <NoHardwareTypes />;
  }
  return <SystemModel systemModelOptions={systemModelOptions} />;
};

const SystemModelCreatePage = () => {
  const [getCreateSystemModelOptionsQuery, getCreateSystemModelOptions] =
    useQueryLoader<SystemModelCreate_getOptions_Query>(
      GET_CREATE_SYSTEM_MODEL_OPTIONS_QUERY,
    );

  const fetchCreateSystemModelOptions = useCallback(
    () =>
      getCreateSystemModelOptions(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "network-only" },
      ),
    [getCreateSystemModelOptions],
  );

  useEffect(fetchCreateSystemModelOptions, [fetchCreateSystemModelOptions]);

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
        onReset={fetchCreateSystemModelOptions}
      >
        {getCreateSystemModelOptionsQuery && (
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
              <SystemModelWrapper
                getCreateSystemModelOptionsQuery={
                  getCreateSystemModelOptionsQuery
                }
              />
            </Page.Main>
          </Page>
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default SystemModelCreatePage;
