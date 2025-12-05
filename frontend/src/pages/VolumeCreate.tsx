/*
 * This file is part of Edgehog.
 *
 * Copyright 2024, 2025 SECO Mind Srl
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

import { ReactNode, useCallback, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useMutation } from "react-relay/hooks";

import type { VolumeCreate_volumeCreate_Mutation } from "@/api/__generated__/VolumeCreate_volumeCreate_Mutation.graphql";

import Alert from "@/components/Alert";
import Page from "@/components/Page";
import { Route, useNavigate } from "@/Navigation";
import CreateVolumeForm, { VolumeData } from "@/forms/CreateVolume";

const CREATE_VOLUME_MUTATION = graphql`
  mutation VolumeCreate_volumeCreate_Mutation($input: CreateVolumeInput!) {
    createVolume(input: $input) {
      result {
        id
      }
    }
  }
`;

const VolumeCreatePage = () => {
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);
  const navigate = useNavigate();

  const [createVolume, isCreatingVolume] =
    useMutation<VolumeCreate_volumeCreate_Mutation>(CREATE_VOLUME_MUTATION);

  const handleCreateVolume = useCallback(
    (volume: VolumeData) => {
      const input: VolumeData = {
        label: volume.label.trim(),
      };
      if (volume.driver && volume.driver.trim() !== "") {
        input.driver = volume.driver.trim();
      }
      if (volume.options && volume.options.trim() !== "") {
        input.options = volume.options.trim();
      }

      createVolume({
        variables: { input },
        onCompleted(data, errors) {
          const volumeId = data.createVolume?.result?.id;
          if (volumeId) {
            navigate({ route: Route.volumes });
            return;
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.VolumeCreate.creationErrorFeedback"
              defaultMessage="Could not create the Volume, please try again."
            />,
          );
        },

        updater(store, data) {
          if (!data?.createVolume?.result?.id) {
            return;
          }

          const volume = store
            .getRootField("createVolume")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const volumes = root.getLinkedRecord("volumes", {
            id: "root",
          });

          if (volumes) {
            root.setLinkedRecords(
              volumes
                ? [...(volumes.getLinkedRecords("volumes") || []), volume]
                : [volume],
              "volumes",
            );
          }
        },
      });
    },
    [createVolume, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.VolumeCreate.title"
            defaultMessage="Create Volume"
          />
        }
      />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <CreateVolumeForm
          onSubmit={handleCreateVolume}
          isLoading={isCreatingVolume}
        />
      </Page.Main>
    </Page>
  );
};

export default VolumeCreatePage;
