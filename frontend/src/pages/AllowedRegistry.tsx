/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { ReactNode, Suspense, useCallback, useEffect, useState } from "react";
import { Alert, Card } from "react-bootstrap";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay";
import { useParams } from "react-router-dom";

import type { AllowedRegistry_deleteAllowedRegistry_Mutation } from "@/api/__generated__/AllowedRegistry_deleteAllowedRegistry_Mutation.graphql";
import type { AllowedRegistry_updateAllowedRegistry_Mutation } from "@/api/__generated__/AllowedRegistry_updateAllowedRegistry_Mutation.graphql";
import {
  AllowedRegistry_allowedRegistry_Query,
  AllowedRegistry_allowedRegistry_Query$data,
} from "@/api/__generated__/AllowedRegistry_allowedRegistry_Query.graphql";

import Center from "@/components/ui/center/Center";
import DeleteModal from "@/components/ui/delete-modal/DeleteModal";
import Page from "@/components/ui/page/Page";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import UpdateAllowedRegistryForm from "@/forms/UpdateAllowedRegistry";
import { AllowedRegistryFormData } from "@/forms/validation";
import { Link, Route, useNavigate } from "@/Navigation";

const ALLOWED_REGISTRY_QUERY = graphql`
  query AllowedRegistry_allowedRegistry_Query($allowedRegistryId: ID!) {
    allowedRegistry(id: $allowedRegistryId) {
      id
      registry
      ...UpdateAllowedRegistry_allowedRegistry_Fragment
    }
  }
`;

const UPDATE_ALLOWED_REGISTRY_MUTATION = graphql`
  mutation AllowedRegistry_updateAllowedRegistry_Mutation(
    $allowedRegistryId: ID!
    $input: UpdateAllowedRegistryInput!
  ) {
    updateAllowedRegistry(id: $allowedRegistryId, input: $input) {
      result {
        id
        registry
        ...UpdateAllowedRegistry_allowedRegistry_Fragment
      }
    }
  }
`;

const DELETE_ALLOWED_REGISTRY_MUTATION = graphql`
  mutation AllowedRegistry_deleteAllowedRegistry_Mutation(
    $allowedRegistryId: ID!
  ) {
    deleteAllowedRegistry(id: $allowedRegistryId) {
      result {
        id
      }
    }
  }
`;

interface AllowedRegistryContentProps {
  allowedRegistry: NonNullable<
    AllowedRegistry_allowedRegistry_Query$data["allowedRegistry"]
  >;
}

const AllowedRegistryContent = ({
  allowedRegistry,
}: AllowedRegistryContentProps) => {
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

  const { allowedRegistryId = "" } = useParams();

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteAllowedRegistry, isDeletingAllowedRegistry] =
    useMutation<AllowedRegistry_deleteAllowedRegistry_Mutation>(
      DELETE_ALLOWED_REGISTRY_MUTATION,
    );

  const handleDeleteAllowedRegistry = useCallback(() => {
    deleteAllowedRegistry({
      variables: { allowedRegistryId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.allowedRegistries });
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
            id="pages.AllowedRegistry.deletionErrorFeedback"
            defaultMessage="Could not delete the Allowed Registry, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
    });
  }, [deleteAllowedRegistry, allowedRegistryId, navigate]);

  const [updateAllowedRegistry, isUpdatingAllowedRegistry] =
    useMutation<AllowedRegistry_updateAllowedRegistry_Mutation>(
      UPDATE_ALLOWED_REGISTRY_MUTATION,
    );

  const handleUpdateAllowedRegistry = useCallback(
    (data: AllowedRegistryFormData, onSuccess?: () => void) => {
      const input = {
        registry: data.registry.trim(),
      };
      updateAllowedRegistry({
        variables: { allowedRegistryId, input },
        onCompleted(_data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
          onSuccess?.();
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.AllowedRegistry.updateErrorFeedback"
              defaultMessage="Could not update the Allowed Registry, please try again."
            />,
          );
        },
      });
    },
    [updateAllowedRegistry, allowedRegistryId],
  );

  return (
    <Page>
      <Page.Header title={allowedRegistry.registry} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4 ">
          <UpdateAllowedRegistryForm
            allowedRegistryRef={allowedRegistry}
            onSubmit={handleUpdateAllowedRegistry}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingAllowedRegistry}
          />
        </Card>
        {showDeleteModal && (
          <DeleteModal
            confirmText={allowedRegistry.registry}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteAllowedRegistry}
            isDeleting={isDeletingAllowedRegistry}
            title={
              <FormattedMessage
                id="pages.AllowedRegistry.deleteModal.title"
                defaultMessage="Delete Allowed Registry"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.AllowedRegistry.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Allowed Registry <bold>{registry}</bold>."
                values={{
                  registry: allowedRegistry.registry,
                  bold: (chunks) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

interface AllowedRegistryWrapperProps {
  allowedRegistryQuery: PreloadedQuery<AllowedRegistry_allowedRegistry_Query>;
}

const AllowedRegistryWrapper = ({
  allowedRegistryQuery,
}: AllowedRegistryWrapperProps) => {
  const { allowedRegistry } =
    usePreloadedQuery<AllowedRegistry_allowedRegistry_Query>(
      ALLOWED_REGISTRY_QUERY,
      allowedRegistryQuery,
    );

  if (!allowedRegistry) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.AllowedRegistry.allowedRegistryNotFound.title"
            defaultMessage="Allowed Registry not found."
          />
        }
      >
        <Link route={Route.allowedRegistries}>
          <FormattedMessage
            id="pages.AllowedRegistry.allowedRegistryNotFound.message"
            defaultMessage="Return to the Allowed Registries list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <AllowedRegistryContent allowedRegistry={allowedRegistry} />;
};

const AllowedRegistryPage = () => {
  const { allowedRegistryId = "" } = useParams();

  const [allowedRegistryQuery, getAllowedRegistry] =
    useQueryLoader<AllowedRegistry_allowedRegistry_Query>(
      ALLOWED_REGISTRY_QUERY,
    );

  const fetchAllowedRegistry = useCallback(() => {
    getAllowedRegistry({ allowedRegistryId }, { fetchPolicy: "network-only" });
  }, [getAllowedRegistry, allowedRegistryId]);

  useEffect(fetchAllowedRegistry, [fetchAllowedRegistry]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={({ resetErrorBoundary }) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchAllowedRegistry}
      >
        {allowedRegistryQuery && (
          <AllowedRegistryWrapper allowedRegistryQuery={allowedRegistryQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default AllowedRegistryPage;
