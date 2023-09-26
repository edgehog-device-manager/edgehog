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
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";
import _ from "lodash";

import type { SystemModel_getSystemModel_Query } from "api/__generated__/SystemModel_getSystemModel_Query.graphql";
import type { SystemModel_updateSystemModel_Mutation } from "api/__generated__/SystemModel_updateSystemModel_Mutation.graphql";
import type { SystemModel_deleteSystemModel_Mutation } from "api/__generated__/SystemModel_deleteSystemModel_Mutation.graphql";
import type { SystemModel_getDefaultTenantLocale_Query } from "api/__generated__/SystemModel_getDefaultTenantLocale_Query.graphql";
import { Link, Route, useNavigate } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import DeleteModal from "components/DeleteModal";
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
      description
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

const DELETE_SYSTEM_MODEL_MUTATION = graphql`
  mutation SystemModel_deleteSystemModel_Mutation(
    $input: DeleteSystemModelInput!
  ) {
    deleteSystemModel(input: $input) {
      systemModel {
        id
      }
    }
  }
`;

const systemModelDiff = (a1: SystemModelData, a2: SystemModelChanges) => {
  const diff: Partial<SystemModelChanges> = {};
  if (a1.name !== a2.name) {
    diff.name = a2.name;
  }
  if (a1.handle !== a2.handle) {
    diff.handle = a2.handle;
  }
  if (!_.isEqual(a1.partNumbers, a2.partNumbers)) {
    diff.partNumbers = a2.partNumbers;
  }
  // TODO: update when backend implement support for updates with empty text value
  if (a1.description !== null || a2.description.text !== "") {
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
  const navigate = useNavigate();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const systemModelData = usePreloadedQuery(
    GET_SYSTEM_MODEL_QUERY,
    getSystemModelQuery,
  );
  const defaultLocaleData = usePreloadedQuery(
    GET_DEFAULT_TENANT_LOCALE_QUERY,
    getDefaultTenantLocaleQuery,
  );

  const [updateSystemModel, isUpdatingSystemModel] =
    useMutation<SystemModel_updateSystemModel_Mutation>(
      UPDATE_SYSTEM_MODEL_MUTATION,
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
    [defaultLocaleData],
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
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.SystemModelUpdate.creationErrorFeedback"
              defaultMessage="Could not update the system model, please try again."
            />,
          );
        },
        optimisticResponse: {
          updateSystemModel: {
            systemModel: {
              ...systemModel,
              ..._.pick(input, ["name", "handle", "partNumbers"]),
              description: input.description?.text ?? systemModel.description,
              pictureUrl:
                input.pictureFile instanceof File
                  ? URL.createObjectURL(input.pictureFile)
                  : _.isString(input.pictureUrl) || _.isNull(input.pictureUrl)
                  ? input.pictureUrl
                  : systemModel.pictureUrl,
            },
          },
        },
        updater(store, data) {
          if (!data.updateSystemModel || !input.partNumbers) {
            return;
          }
          const systemModelId = store
            .getRootField("updateSystemModel")
            .getLinkedRecord("systemModel")
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
    [updateSystemModel, systemModel],
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
    if (!systemModel) {
      return null;
    }
    const input = {
      systemModelId: systemModel.id,
    };
    deleteSystemModel({
      variables: { input },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map((error) => error.message)
            .join(". \n");
          setErrorFeedback(errorFeedback);
          return setShowDeleteModal(false);
        }
        navigate({ route: Route.systemModels });
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
        if (!data.deleteSystemModel) {
          return;
        }

        const systemModel = store
          .getRootField("deleteSystemModel")
          .getLinkedRecord("systemModel");
        const systemModelId = systemModel.getDataID();
        const root = store.getRoot();

        const systemModels = root.getLinkedRecords("systemModels");
        if (systemModels) {
          root.setLinkedRecords(
            systemModels.filter(
              (systemModel) => systemModel.getDataID() !== systemModelId,
            ),
            "systemModels",
          );
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
  }, [deleteSystemModel, systemModel, navigate]);

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
          locale={locale}
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

const SystemModelPage = () => {
  const { systemModelId = "" } = useParams();

  const [getSystemModelQuery, getSystemModel] =
    useQueryLoader<SystemModel_getSystemModel_Query>(GET_SYSTEM_MODEL_QUERY);
  const [getDefaultTenantLocaleQuery, getDefaultTenantLocale] =
    useQueryLoader<SystemModel_getDefaultTenantLocale_Query>(
      GET_DEFAULT_TENANT_LOCALE_QUERY,
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
