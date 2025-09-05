/*
  This file is part of Edgehog.

  Copyright 2024 - 2025 SECO Mind Srl

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
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type {
  ReleaseCreate_getOptions_Query,
  ReleaseCreate_getOptions_Query$data,
} from "api/__generated__/ReleaseCreate_getOptions_Query.graphql";
import type { ReleaseCreate_createRelease_Mutation } from "api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";

import Alert from "components/Alert";
import Page from "components/Page";
import CreateRelease from "forms/CreateRelease";
import type { ReleaseSubmitData } from "forms/CreateRelease";
import { Route, useNavigate } from "Navigation";
import Spinner from "components/Spinner";
import Center from "components/Center";

const CREATE_RELEASE_PAGE_QUERY = graphql`
  query ReleaseCreate_getOptions_Query {
    ...CreateRelease_ImageCredentialsOptionsFragment
    ...CreateRelease_NetworksOptionsFragment
    ...CreateRelease_VolumesOptionsFragment
    ...CreateRelease_SystemModelsOptionsFragment
  }
`;

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
        systemModels {
          id
        }
      }
    }
  }
`;

type ReleaseOptions = {
  releaseOptions: ReleaseCreate_getOptions_Query$data;
};

const Release = ({ releaseOptions }: ReleaseOptions) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();
  const { applicationId = "" } = useParams();
  const [createRelease, isCreatingRelease] =
    useMutation<ReleaseCreate_createRelease_Mutation>(CREATE_RELEASE_MUTATION);

  const handleCreateRelease = useCallback(
    (release: ReleaseSubmitData) => {
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
    <>
      <Alert
        show={!!errorFeedback}
        variant="danger"
        onClose={() => setErrorFeedback(null)}
        dismissible
      >
        {errorFeedback}
      </Alert>
      <CreateRelease
        imageCredentialsOptionsRef={releaseOptions}
        networksOptionsRef={releaseOptions}
        volumesOptionsRef={releaseOptions}
        requiredSystemModelsOptionsRef={releaseOptions}
        onSubmit={handleCreateRelease}
        isLoading={isCreatingRelease}
      />
    </>
  );
};

type ReleaseWrapperProps = {
  getReleaseOptionsQuery: PreloadedQuery<ReleaseCreate_getOptions_Query>;
};

const ReleaseWrapper = ({ getReleaseOptionsQuery }: ReleaseWrapperProps) => {
  const releaseOptions = usePreloadedQuery(
    CREATE_RELEASE_PAGE_QUERY,
    getReleaseOptionsQuery,
  );

  return <Release releaseOptions={releaseOptions} />;
};

const ReleaseCreatePage = () => {
  const [getReleaseOptionsQuery, getReleaseOptions] =
    useQueryLoader<ReleaseCreate_getOptions_Query>(CREATE_RELEASE_PAGE_QUERY);

  const fetchReleaseOptions = useCallback(
    () => getReleaseOptions({}, { fetchPolicy: "network-only" }),
    [getReleaseOptions],
  );

  useEffect(fetchReleaseOptions, [fetchReleaseOptions]);

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
        onReset={fetchReleaseOptions}
      >
        {getReleaseOptionsQuery && (
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
              <ReleaseWrapper getReleaseOptionsQuery={getReleaseOptionsQuery} />
            </Page.Main>
          </Page>
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ReleaseCreatePage;
