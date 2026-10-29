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

import type { Volume_deleteVolume_Mutation } from "@/api/__generated__/Volume_deleteVolume_Mutation.graphql";
import type { Volume_updateVolume_Mutation } from "@/api/__generated__/Volume_updateVolume_Mutation.graphql";
import type {
  Volume_getVolume_Query,
  Volume_getVolume_Query$data,
} from "@/api/__generated__/Volume_getVolume_Query.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/ui/alert/Alert";
import Center from "@/components/ui/center/Center";
import Page from "@/components/ui/page/Page";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import DeleteModal from "@/components/ui/delete-modal/DeleteModal";
import CreateVolumeForm from "@/forms/CreateVolume";
import { VolumeFormData } from "@/forms/validation";

const GET_VOLUME_QUERY = graphql`
  query Volume_getVolume_Query($volumeId: ID!) {
    volume(id: $volumeId) {
      id
      label
      driver
      options
    }
  }
`;

const UPDATE_VOLUME_MUTATION = graphql`
  mutation Volume_updateVolume_Mutation(
    $volumeId: ID!
    $input: UpdateVolumeInput!
  ) {
    updateVolume(id: $volumeId, input: $input) {
      result {
        id
        label
        driver
        options
      }
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

  const [updateVolume, isUpdatingVolume] =
    useMutation<Volume_updateVolume_Mutation>(UPDATE_VOLUME_MUTATION);

  const handleUpdateVolume = useCallback(
    (volumeData: VolumeFormData) => {
      const input = {
        label: volumeData.label.trim(),
        driver: volumeData.driver?.trim() || null,
        options: volumeData.options?.trim() || "{}",
      };
      updateVolume({
        variables: { volumeId, input },
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
              id="pages.Volume.updateErrorFeedback"
              defaultMessage="Could not update the Volume, please try again."
            />,
          );
        },
      });
    },
    [updateVolume, volumeId],
  );

  const defaultValues = useMemo<VolumeFormData>(() => {
    let options = "{}";
    try {
      if (volume.options) {
        options =
          typeof volume.options === "string"
            ? JSON.stringify(JSON.parse(volume.options), null, 2)
            : JSON.stringify(volume.options, null, 2);
      }
    } catch {
      options = "{}";
    }
    return {
      label: volume.label,
      driver: volume.driver ?? "",
      options,
    };
  }, [volume]);

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
        <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
          <CreateVolumeForm
            defaultValues={defaultValues}
            onSubmit={handleUpdateVolume}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingVolume}
          />
        </Card>
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
  const { volume } = usePreloadedQuery<Volume_getVolume_Query>(
    GET_VOLUME_QUERY,
    getVolumeQuery,
  );

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
