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
  HardwareType_getHardwareType_Query,
  HardwareType_getHardwareType_Query$data,
} from "@/api/__generated__/HardwareType_getHardwareType_Query.graphql";
import type { HardwareType_updateHardwareType_Mutation } from "@/api/__generated__/HardwareType_updateHardwareType_Mutation.graphql";
import type { HardwareType_deleteHardwareType_Mutation } from "@/api/__generated__/HardwareType_deleteHardwareType_Mutation.graphql";
import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import DeleteModal from "@/components/DeleteModal";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import UpdateHardwareTypeForm from "@/forms/UpdateHardwareType";
import type { HardwareTypeOutputData } from "@/forms/CreateHardwareType";

const GET_HARDWARE_TYPE_QUERY = graphql`
  query HardwareType_getHardwareType_Query($hardwareTypeId: ID!) {
    hardwareType(id: $hardwareTypeId) {
      id
      name
      handle
      ...UpdateHardwareType_HardwareTypeFragment
    }
  }
`;

const UPDATE_HARDWARE_TYPE_MUTATION = graphql`
  mutation HardwareType_updateHardwareType_Mutation(
    $hardwareTypeId: ID!
    $input: UpdateHardwareTypeInput!
  ) {
    updateHardwareType(id: $hardwareTypeId, input: $input) {
      result {
        id
        name
        handle
        ...UpdateHardwareType_HardwareTypeFragment
      }
    }
  }
`;

const DELETE_HARDWARE_TYPE_MUTATION = graphql`
  mutation HardwareType_deleteHardwareType_Mutation($hardwareTypeId: ID!) {
    deleteHardwareType(id: $hardwareTypeId) {
      result {
        id
      }
    }
  }
`;

interface HardwareTypeContentProps {
  hardwareType: NonNullable<
    HardwareType_getHardwareType_Query$data["hardwareType"]
  >;
}

const HardwareTypeContent = ({ hardwareType }: HardwareTypeContentProps) => {
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const hardwareTypeId = hardwareType.id;

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteHardwareType, isDeletingHardwareType] =
    useMutation<HardwareType_deleteHardwareType_Mutation>(
      DELETE_HARDWARE_TYPE_MUTATION,
    );

  const handleDeleteHardwareType = useCallback(() => {
    deleteHardwareType({
      variables: { hardwareTypeId },
      onCompleted(data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.hardwareTypes });
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
            id="pages.HardwareTypeUpdate.deletionErrorFeedback"
            defaultMessage="Could not delete the hardware type, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
      updater(store, data) {
        const hardwareTypeId = data?.deleteHardwareType?.result?.id;
        if (!hardwareTypeId) {
          return;
        }

        const root = store.getRoot();

        const connection = ConnectionHandler.getConnection(
          root,
          "HardwareTypesTable_hardwareTypes",
        );

        if (connection) {
          ConnectionHandler.deleteNode(connection, hardwareTypeId);
        }

        store.delete(hardwareTypeId);
      },
    });
  }, [deleteHardwareType, hardwareTypeId, navigate]);

  const [updateHardwareType, isUpdatingHardwareType] =
    useMutation<HardwareType_updateHardwareType_Mutation>(
      UPDATE_HARDWARE_TYPE_MUTATION,
    );

  const handleUpdateHardwareType = useCallback(
    (hardwareType: HardwareTypeOutputData) => {
      updateHardwareType({
        variables: { hardwareTypeId, input: hardwareType },
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
              id="pages.HardwareTypeUpdate.creationErrorFeedback"
              defaultMessage="Could not update the hardware type, please try again."
            />,
          );
        },
      });
    },
    [updateHardwareType, hardwareTypeId],
  );

  return (
    <Page>
      <Page.Header title={hardwareType.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <UpdateHardwareTypeForm
          hardwareTypeRef={hardwareType}
          onSubmit={handleUpdateHardwareType}
          onDelete={handleShowDeleteModal}
          isLoading={isUpdatingHardwareType}
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={hardwareType.handle}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteHardwareType}
            isDeleting={isDeletingHardwareType}
            title={
              <FormattedMessage
                id="pages.HardwareType.deleteModal.title"
                defaultMessage="Delete Hardware Type"
                description="Title for the confirmation modal to delete a Hardware Type"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.HardwareType.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Hardware Type <bold>{hardwareType}</bold>."
                description="Description for the confirmation modal to delete a Hardware Type"
                values={{
                  hardwareType: hardwareType.name,
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

type HardwareTypeWrapperProps = {
  getHardwareTypeQuery: PreloadedQuery<HardwareType_getHardwareType_Query>;
};

const HardwareTypeWrapper = ({
  getHardwareTypeQuery,
}: HardwareTypeWrapperProps) => {
  const { hardwareType } = usePreloadedQuery(
    GET_HARDWARE_TYPE_QUERY,
    getHardwareTypeQuery,
  );

  if (!hardwareType) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.HardwareType.hardwareTypeNotFound.title"
            defaultMessage="Hardware type not found."
          />
        }
      >
        <Link route={Route.hardwareTypes}>
          <FormattedMessage
            id="pages.HardwareType.hardwareTypeNotFound.message"
            defaultMessage="Return to the hardware type list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <HardwareTypeContent hardwareType={hardwareType} />;
};

const HardwareTypePage = () => {
  const { hardwareTypeId = "" } = useParams();

  const [getHardwareTypeQuery, getHardwareType] =
    useQueryLoader<HardwareType_getHardwareType_Query>(GET_HARDWARE_TYPE_QUERY);

  const fetchHardwareType = useCallback(() => {
    getHardwareType({ hardwareTypeId }, { fetchPolicy: "network-only" });
  }, [getHardwareType, hardwareTypeId]);

  useEffect(fetchHardwareType, [fetchHardwareType]);

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
        onReset={fetchHardwareType}
      >
        {getHardwareTypeQuery && (
          <HardwareTypeWrapper getHardwareTypeQuery={getHardwareTypeQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default HardwareTypePage;
