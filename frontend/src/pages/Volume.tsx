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
  Volume_getVolume_Query,
  Volume_getVolume_Query$data,
} from "api/__generated__/Volume_getVolume_Query.graphql";

import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";

const GET_VOLUME_QUERY = graphql`
  query Volume_getVolume_Query($volumeId: ID!) {
    volume(id: $volumeId) {
      label
      driver
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

interface VolumeContentProps {
  volume: NonNullable<Volume_getVolume_Query$data["volume"]>;
}

const VolumeContent = ({ volume }: VolumeContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const getPrettyOptions = () => {
    try {
      if (!volume.options) return "";
      if (typeof volume.options === "string") {
        return JSON.stringify(JSON.parse(volume.options), null, 2);
      }
      return JSON.stringify(volume.options, null, 2);
    } catch (err) {
      setErrorFeedback("Failed to parse volume options JSON.");
      return "";
    }
  };

  return (
    <Page>
      <Page.Header title={volume.label} />
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
          id="volumeLabel"
          label={
            <FormattedMessage id="pages.volume.label" defaultMessage="Label" />
          }
        >
          <Form.Control value={volume.label ?? ""} readOnly />
        </FormRow>

        <FormRow
          id="volumeDriver"
          label={
            <FormattedMessage
              id="pages.volume.driver"
              defaultMessage="Driver"
            />
          }
        >
          <Form.Control value={volume.driver ?? ""} readOnly />
        </FormRow>

        <FormRow
          id="volumeOptions"
          label={
            <FormattedMessage
              id="pages.volume.options"
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
      </Page.Main>
    </Page>
  );
};

type VolumeWrapperProps = {
  getVolumeQuery: PreloadedQuery<Volume_getVolume_Query>;
};

const VolumeWrapper = ({ getVolumeQuery }: VolumeWrapperProps) => {
  const { volume } = usePreloadedQuery(GET_VOLUME_QUERY, getVolumeQuery);

  if (!volume) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Volume.volumeNotFound.title"
            defaultMessage="Volume not found."
          />
        }
      >
        <Link route={Route.volumes}>
          <FormattedMessage
            id="pages.Volume.volumeNotFound.message"
            defaultMessage="Return to the volumes list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <VolumeContent volume={volume} />;
};

const VolumePage = () => {
  const { volumeId = "" } = useParams();

  const [getVolumeQuery, getVolume] =
    useQueryLoader<Volume_getVolume_Query>(GET_VOLUME_QUERY);

  const fetchVolume = useCallback(
    () => getVolume({ volumeId }, { fetchPolicy: "network-only" }),
    [getVolume, volumeId],
  );

  useEffect(fetchVolume, [fetchVolume]);

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
        onReset={fetchVolume}
      >
        {getVolumeQuery && <VolumeWrapper getVolumeQuery={getVolumeQuery} />}
      </ErrorBoundary>
    </Suspense>
  );
};

export default VolumePage;
