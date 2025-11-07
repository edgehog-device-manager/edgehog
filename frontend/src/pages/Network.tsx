/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useState } from "react";
import { Form, Stack } from "react-bootstrap";
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

import type { Network_deleteNetwork_Mutation } from "api/__generated__/Network_deleteNetwork_Mutation.graphql";
import type {
  Network_getNetwork_Query,
  Network_getNetwork_Query$data,
} from "api/__generated__/Network_getNetwork_Query.graphql";

import { Link, Route, useNavigate } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import Button from "components/Button";
import DeleteModal from "components/DeleteModal";
import MonacoJsonEditor from "components/MonacoJsonEditor";
import { FormRowWithMargin as FormRow } from "components/FormRow";

const GET_NETWORK_QUERY = graphql`
  query Network_getNetwork_Query($networkId: ID!) {
    network(id: $networkId) {
      label
      driver
      internal
      enableIpv6
      options
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

  const getPrettyOptions = () => {
    try {
      if (!network.options) return "";
      if (typeof network.options === "string") {
        return JSON.stringify(JSON.parse(network.options), null, 2);
      }
      return JSON.stringify(network.options, null, 2);
    } catch (err) {
      setErrorFeedback("Failed to parse network options JSON.");
      return "";
    }
  };

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

        <FormRow
          id="networkLabel"
          label={
            <FormattedMessage id="pages.network.label" defaultMessage="Label" />
          }
        >
          <Form.Control value={network.label ?? ""} readOnly />
        </FormRow>

        <FormRow
          id="networkDriver"
          label={
            <FormattedMessage
              id="pages.network.driver"
              defaultMessage="Driver"
            />
          }
        >
          <Form.Control value={network.driver ?? ""} readOnly />
        </FormRow>

        <FormRow
          id="networkOptions"
          label={
            <FormattedMessage
              id="pages.network.options"
              defaultMessage="Options"
            />
          }
        >
          <MonacoJsonEditor
            value={getPrettyOptions()}
            onChange={() => {}}
            defaultValue={getPrettyOptions()}
            readonly={true}
            initialLines={1}
          />
        </FormRow>

        <FormRow
          id="networkInternal"
          label={
            <FormattedMessage
              id="pages.network.internal"
              defaultMessage="Internal"
            />
          }
        >
          <Form.Check type="checkbox" checked={network.internal} readOnly />
        </FormRow>

        <FormRow
          id="networkLabelEnableIpv6"
          label={
            <FormattedMessage
              id="pages.network.enableIpv6"
              defaultMessage="Enable IPv6"
            />
          }
        >
          <Form.Check type="checkbox" checked={network.enableIpv6} readOnly />
        </FormRow>

        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="danger" onClick={handleShowDeleteModal}>
            <FormattedMessage
              id="pages.Network.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>

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
  const { network } = usePreloadedQuery(GET_NETWORK_QUERY, getNetworkQuery);

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
