// This file is part of Edgehog.
//
// Copyright 2025-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { Card } from "react-bootstrap";
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

import type { Network_deleteNetwork_Mutation } from "@/api/__generated__/Network_deleteNetwork_Mutation.graphql";
import type { Network_updateNetwork_Mutation } from "@/api/__generated__/Network_updateNetwork_Mutation.graphql";
import type {
  Network_getNetwork_Query,
  Network_getNetwork_Query$data,
} from "@/api/__generated__/Network_getNetwork_Query.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/ui/alert/Alert";
import Center from "@/components/ui/center/Center";
import Page from "@/components/ui/page/Page";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import DeleteModal from "@/components/ui/delete-modal/DeleteModal";
import CreateNetworkForm from "@/forms/CreateNetwork";
import { NetworkFormData } from "@/forms/validation";

const GET_NETWORK_QUERY = graphql`
  query Network_getNetwork_Query($networkId: ID!) {
    network(id: $networkId) {
      id
      label
      driver
      internal
      enableIpv6
      options
    }
  }
`;

const UPDATE_NETWORK_MUTATION = graphql`
  mutation Network_updateNetwork_Mutation(
    $networkId: ID!
    $input: UpdateNetworkInput!
  ) {
    updateNetwork(id: $networkId, input: $input) {
      result {
        id
        label
        driver
        internal
        enableIpv6
        options
      }
    }
  }
`;

const DELETE_NETWORK_MUTATION = graphql`
  mutation Network_deleteNetwork_Mutation($networkId: ID!) {
    deleteNetwork(id: $networkId) {
      result {
        id
      }
    }
  }
`;

interface NetworkContentProps {
  network: NonNullable<Network_getNetwork_Query$data["network"]>;
}

const NetworkContent = ({ network }: NetworkContentProps) => {
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { networkId = "" } = useParams();

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteNetwork, isDeletingNetwork] =
    useMutation<Network_deleteNetwork_Mutation>(DELETE_NETWORK_MUTATION);

  const handleDeleteNetwork = useCallback(() => {
    deleteNetwork({
      variables: { networkId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.networks });
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
            id="pages.Network.deletionErrorFeedback"
            defaultMessage="Could not delete the Network, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
    });
  }, [deleteNetwork, networkId, navigate]);

  const [updateNetwork, isUpdatingNetwork] =
    useMutation<Network_updateNetwork_Mutation>(UPDATE_NETWORK_MUTATION);

  const handleUpdateNetwork = useCallback(
    (networkData: NetworkFormData) => {
      const input = {
        label: networkData.label.trim(),
        driver: networkData.driver?.trim() || null,
        internal: networkData.internal,
        enableIpv6: networkData.enableIpv6,
        options: networkData.options?.trim() || "{}",
      };
      updateNetwork({
        variables: { networkId, input },
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
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Network.updateErrorFeedback"
              defaultMessage="Could not update the Network, please try again."
            />,
          );
        },
      });
    },
    [updateNetwork, networkId],
  );

  const defaultValues = useMemo<NetworkFormData>(() => {
    let options = "{}";
    try {
      if (network.options) {
        options =
          typeof network.options === "string"
            ? JSON.stringify(JSON.parse(network.options), null, 2)
            : JSON.stringify(network.options, null, 2);
      }
    } catch {
      options = "{}";
    }
    return {
      label: network.label ?? "",
      driver: network.driver ?? "",
      internal: network.internal,
      enableIpv6: network.enableIpv6,
      options,
    };
  }, [network]);

  return (
    <Page>
      <Page.Header title={network.label} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
          <CreateNetworkForm
            defaultValues={defaultValues}
            onSubmit={handleUpdateNetwork}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingNetwork}
          />
        </Card>

        {showDeleteModal && (
          <DeleteModal
            confirmText={network.label ?? ""}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteNetwork}
            isDeleting={isDeletingNetwork}
            title={
              <FormattedMessage
                id="pages.Network.deleteModal.title"
                defaultMessage="Delete Network"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.Network.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Network <bold>{network}</bold>."
                values={{
                  network: network.label,
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

type NetworkWrapperProps = {
  getNetworkQuery: PreloadedQuery<Network_getNetwork_Query>;
};

const NetworkWrapper = ({ getNetworkQuery }: NetworkWrapperProps) => {
  const { network } = usePreloadedQuery<Network_getNetwork_Query>(
    GET_NETWORK_QUERY,
    getNetworkQuery,
  );

  if (!network) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Network.networkNotFound.title"
            defaultMessage="Network not found."
          />
        }
      >
        <Link route={Route.networks}>
          <FormattedMessage
            id="pages.Network.networkNotFound.message"
            defaultMessage="Return to the networks list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <NetworkContent network={network} />;
};

const NetworkPage = () => {
  const { networkId = "" } = useParams();

  const [getNetworkQuery, getNetwork] =
    useQueryLoader<Network_getNetwork_Query>(GET_NETWORK_QUERY);

  const fetchNetwork = useCallback(
    () => getNetwork({ networkId }, { fetchPolicy: "network-only" }),
    [getNetwork, networkId],
  );

  useEffect(fetchNetwork, [fetchNetwork]);

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
        onReset={fetchNetwork}
      >
        {getNetworkQuery && (
          <NetworkWrapper getNetworkQuery={getNetworkQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default NetworkPage;
