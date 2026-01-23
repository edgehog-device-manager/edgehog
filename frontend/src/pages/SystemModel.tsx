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
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import type {
  SystemModel_getSystemModel_Query,
  SystemModel_getSystemModel_Query$data,
} from "@/api/__generated__/SystemModel_getSystemModel_Query.graphql";
import type { SystemModel_updateSystemModel_Mutation } from "@/api/__generated__/SystemModel_updateSystemModel_Mutation.graphql";
import type { SystemModel_deleteSystemModel_Mutation } from "@/api/__generated__/SystemModel_deleteSystemModel_Mutation.graphql";
import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import DeleteModal from "@/components/DeleteModal";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import UpdateSystemModelForm from "@/forms/UpdateSystemModel";
import type { SystemModelOutputData } from "@/forms/UpdateSystemModel";

const GET_SYSTEM_MODEL_QUERY = graphql`
  query SystemModel_getSystemModel_Query($systemModelId: ID!) {
    systemModel(id: $systemModelId) {
      id
      name
      handle
      ...UpdateSystemModel_SystemModelFragment
    }
    ...UpdateSystemModel_OptionsFragment
  }
`;

const UPDATE_SYSTEM_MODEL_MUTATION = graphql`
  mutation SystemModel_updateSystemModel_Mutation(
    $systemModelId: ID!
    $input: UpdateSystemModelInput!
  ) {
    updateSystemModel(id: $systemModelId, input: $input) {
      result {
        id
        name
        handle
        ...UpdateSystemModel_SystemModelFragment
      }
    }
  }
`;

const DELETE_SYSTEM_MODEL_MUTATION = graphql`
  mutation SystemModel_deleteSystemModel_Mutation($systemModelId: ID!) {
    deleteSystemModel(id: $systemModelId) {
      result {
        id
      }
    }
  }
`;

type SystemModelContentProps = {
  systemModel: NonNullable<
    SystemModel_getSystemModel_Query$data["systemModel"]
  >;
  queryRef: SystemModel_getSystemModel_Query$data;
};

const SystemModelContent = ({
  queryRef,
  systemModel,
}: SystemModelContentProps) => {
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const systemModelId = systemModel.id;

  const [updateSystemModel, isUpdatingSystemModel] =
    useMutation<SystemModel_updateSystemModel_Mutation>(
      UPDATE_SYSTEM_MODEL_MUTATION,
    );

  const handleUpdateSystemModel = useCallback(
    (systemModelChanges: SystemModelOutputData) => {
      updateSystemModel({
        variables: { systemModelId, input: systemModelChanges },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.SystemModelUpdate.creationErrorFeedback"
              defaultMessage="Could not update the system model, please try again."
            />,
          );
        },
        updater(store, data) {
          if (
            !data?.updateSystemModel?.result ||
            !systemModelChanges.partNumbers
          ) {
            return;
          }
          const systemModelId = store
            .getRootField("updateSystemModel")
            .getLinkedRecord("result")
            .getDataID();

          store
            .getRoot()
            .getLinkedRecords("devices")
            ?.forEach((device) => {
              const systemModel = device.getLinkedRecord("systemModel");
              if (!systemModel || systemModel.getDataID() === systemModelId) {
                device.invalidateRecord();
              }
            });
        },
      });
    },
    [updateSystemModel, systemModelId],
  );

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteSystemModel, isDeletingSystemModel] =
    useMutation<SystemModel_deleteSystemModel_Mutation>(
      DELETE_SYSTEM_MODEL_MUTATION,
    );

  const handleDeleteSystemModel = useCallback(() => {
    deleteSystemModel({
      variables: { systemModelId },
      onCompleted(data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.systemModels });
        }

        const errorFeedback = errors
          .map(({ fields, message }) =>
            fields.length ? `${fields.join(" ")} ${message}` : message,
          )
          .join(". \n");
        setErrorFeedback(errorFeedback);
        setShowDeleteModal(false);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.SystemModel.deletionErrorFeedback"
            defaultMessage="Could not delete the system model, please try again."
          />,
        );
      },
      updater(store, data) {
        const systemModelId = data?.deleteSystemModel?.result?.id;
        if (!systemModelId) {
          return;
        }

        const root = store.getRoot();

        const connection = ConnectionHandler.getConnection(
          root,
          "SystemModelsTable_systemModels",
        );

        if (connection) {
          ConnectionHandler.deleteNode(connection, systemModelId);
        }

        root.getLinkedRecords("devices")?.forEach((device) => {
          const systemModel = device.getLinkedRecord("systemModel");
          if (systemModel?.getDataID() === systemModelId) {
            device.invalidateRecord();
          }
        });

        store.delete(systemModelId);
      },
    });
  }, [deleteSystemModel, systemModelId, navigate]);

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
          systemModelRef={systemModel}
          optionsRef={queryRef}
          onSubmit={handleUpdateSystemModel}
          onDelete={handleShowDeleteModal}
          isLoading={isUpdatingSystemModel}
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={systemModel.handle}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteSystemModel}
            isDeleting={isDeletingSystemModel}
            title={
              <FormattedMessage
                id="pages.SystemModel.deleteModal.title"
                defaultMessage="Delete System Model"
                description="Title for the confirmation modal to delete a System Model"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.SystemModel.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the System Model <bold>{systemModel}</bold>."
                description="Description for the confirmation modal to delete a System Model"
                values={{
                  systemModel: systemModel.name,
                  bold: (chunks: React.ReactNode) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

type SystemModelWrapperProps = {
  getSystemModelQuery: PreloadedQuery<SystemModel_getSystemModel_Query>;
};

const SystemModelWrapper = ({
  getSystemModelQuery,
}: SystemModelWrapperProps) => {
  const queryData = usePreloadedQuery(
    GET_SYSTEM_MODEL_QUERY,
    getSystemModelQuery,
  );

  if (!queryData.systemModel) {
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
    <SystemModelContent
      systemModel={queryData.systemModel}
      queryRef={queryData}
    />
  );
};

const SystemModelPage = () => {
  const { systemModelId = "" } = useParams();

  const [getSystemModelQuery, getSystemModel] =
    useQueryLoader<SystemModel_getSystemModel_Query>(GET_SYSTEM_MODEL_QUERY);

  const fetchSystemModel = useCallback(
    () => getSystemModel({ systemModelId }, { fetchPolicy: "network-only" }),
    [getSystemModel, systemModelId],
  );

  useEffect(fetchSystemModel, [fetchSystemModel]);

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
        onReset={fetchSystemModel}
      >
        {getSystemModelQuery && (
          <SystemModelWrapper getSystemModelQuery={getSystemModelQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default SystemModelPage;
