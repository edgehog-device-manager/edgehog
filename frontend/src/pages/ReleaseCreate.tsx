/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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

import { useCallback, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useMutation } from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type { ReleaseCreate_createRelease_Mutation } from "api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import Alert from "components/Alert";
import Page from "components/Page";
import CreateRelease from "forms/CreateRelease";
import type { ReleaseData } from "forms/CreateRelease";
import { Route, useNavigate } from "Navigation";

const CREATE_RELEASE_MUTATION = graphql`
  mutation ReleaseCreate_createRelease_Mutation($input: CreateReleaseInput!) {
    createRelease(input: $input) {
      result {
        id
        applicationId
        containers {
          edges {
            node {
              id
            }
          }
        }
      }
    }
  }
`;

const ReleaseCreatePage = () => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();
  const { applicationId = "" } = useParams();

  const [createRelease, isCreatingRelease] =
    useMutation<ReleaseCreate_createRelease_Mutation>(CREATE_RELEASE_MUTATION);

  const handleCreateRelease = useCallback(
    (release: ReleaseData) => {
      const newRelease = { ...release, applicationId };

      createRelease({
        variables: { input: newRelease },
        onCompleted(data, errors) {
          const releaseId = data.createRelease?.result?.id;
          if (releaseId) {
            return navigate({
              route: Route.application,
              params: { applicationId },
            });
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.ReleaseCreate.creationErrorFeedback"
              defaultMessage="Could not create the release, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createRelease?.result?.id) {
            return;
          }

          const release = store
            .getRootField("createRelease")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const releases = root.getLinkedRecords("releases");

          if (releases) {
            root.setLinkedRecords([...releases, release], "releases");
          }
        },
      });
    },
    [createRelease, navigate, applicationId],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ReleaseCreate.title"
            defaultMessage="Create Release"
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
        <CreateRelease
          onSubmit={handleCreateRelease}
          isLoading={isCreatingRelease}
        />
      </Page.Main>
    </Page>
  );
};

export default ReleaseCreatePage;
