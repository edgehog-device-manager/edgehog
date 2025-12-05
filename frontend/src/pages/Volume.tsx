/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import type { Volume_deleteVolume_Mutation } from "@/api/__generated__/Volume_deleteVolume_Mutation.graphql";
import type {
  Volume_getVolume_Query,
  Volume_getVolume_Query$data,
} from "@/api/__generated__/Volume_getVolume_Query.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import Button from "@/components/Button";
import DeleteModal from "@/components/DeleteModal";
import MonacoJsonEditor from "@/components/MonacoJsonEditor";
import { FormRowWithMargin as FormRow } from "@/components/FormRow";

const GET_VOLUME_QUERY = graphql`
  query Volume_getVolume_Query($volumeId: ID!) {
    volume(id: $volumeId) {
      label
      driver
      options
    }
  }
`;

const DELETE_VOLUME_MUTATION = graphql`
  mutation Volume_deleteVolume_Mutation($volumeId: ID!) {
    deleteVolume(id: $volumeId) {
      result {
        id
      }
    }
  }
`;

interface VolumeContentProps {
  volume: NonNullable<Volume_getVolume_Query$data["volume"]>;
}

const VolumeContent = ({ volume }: VolumeContentProps) => {
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { volumeId = "" } = useParams();

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteVolume, isDeletingVolume] =
    useMutation<Volume_deleteVolume_Mutation>(DELETE_VOLUME_MUTATION);

  const handleDeleteVolume = useCallback(() => {
    deleteVolume({
      variables: { volumeId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.volumes });
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
            id="pages.Volume.deletionErrorFeedback"
            defaultMessage="Could not delete the Volume, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
    });
  }, [deleteVolume, volumeId, navigate]);

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
          <MonacoJsonEditor
            value={getPrettyOptions()}
            onChange={() => {}}
            defaultValue={getPrettyOptions()}
            readonly={true}
            initialLines={1}
          />
        </FormRow>

        <Stack
          direction="horizontal"
          gap={3}
          className="justify-content-end align-items-center"
        >
          <Button variant="danger" onClick={handleShowDeleteModal}>
            <FormattedMessage
              id="pages.Volume.deleteButton"
              defaultMessage="Delete"
            />
          </Button>
        </Stack>

        {showDeleteModal && (
          <DeleteModal
            confirmText={volume.label}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteVolume}
            isDeleting={isDeletingVolume}
            title={
              <FormattedMessage
                id="pages.Volume.deleteModal.title"
                defaultMessage="Delete Volume"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.Volume.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Volume <bold>{volume}</bold>."
                values={{
                  volume: volume.label,
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
