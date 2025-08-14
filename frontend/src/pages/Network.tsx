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
import { Form, Row, Col } from "react-bootstrap";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import type {
  Network_getNetwork_Query,
  Network_getNetwork_Query$data,
} from "api/__generated__/Network_getNetwork_Query.graphql";

import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";

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

const FormRow = ({
  id,
  label,
  children,
}: {
  id: string;
  label: React.ReactNode;
  children: React.ReactNode;
}) => (
  <Form.Group as={Row} controlId={id} className="mb-4">
    <Form.Label column sm={3} className="fw-bold">
      {label}
    </Form.Label>
    <Col sm={9}>{children}</Col>
  </Form.Group>
);

interface NetworkContentProps {
  network: NonNullable<Network_getNetwork_Query$data["network"]>;
}

const NetworkContent = ({ network }: NetworkContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

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
          <Form.Control
            as="textarea"
            value={getPrettyOptions()}
            rows={getPrettyOptions().split("\n").length}
            readOnly
            style={{ fontFamily: "monospace", whiteSpace: "pre-wrap" }}
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
