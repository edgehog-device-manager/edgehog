/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type {
  CreateReleaseInput,
  ReleaseCreate_createRelease_Mutation,
} from "@/api/__generated__/ReleaseCreate_createRelease_Mutation.graphql";
import type {
  ReleaseCreate_getOptions_Query,
  ReleaseCreate_getOptions_Query$data,
} from "@/api/__generated__/ReleaseCreate_getOptions_Query.graphql";

import Alert from "@/components/ui/alert/Alert";
import Center from "@/components/ui/center/Center";
import Page from "@/components/ui/page/Page";
import Spinner from "@/components/ui/spinner/Spinner";
import ReleaseComposer from "@/components/apps/releases/release-composer/ReleaseComposer";
import { Route, useNavigate } from "@/Navigation";

const CREATE_RELEASE_PAGE_QUERY = graphql`
  query ReleaseCreate_getOptions_Query($applicationId: ID!) {
    application(id: $applicationId) {
      name
    }
    ...hooks_SystemModelsOptionsFragment
    ...hooks_NetworksOptionsFragment
    ...hooks_VolumesOptionsFragment
    ...hooks_ImageCredentialsOptionsFragment
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
      }
    }
  }
`;

type ReleaseProps = {
  releaseOptions: ReleaseCreate_getOptions_Query$data;
};

const Release = ({ releaseOptions }: ReleaseProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();
  const { applicationId = "" } = useParams();
  const [createRelease, isCreatingRelease] =
    useMutation<ReleaseCreate_createRelease_Mutation>(CREATE_RELEASE_MUTATION);

  const handleCreateRelease = useCallback(
    (release: CreateReleaseInput) => {
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
      <ReleaseComposer
        queryRef={releaseOptions}
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
  const releaseOptions = usePreloadedQuery<ReleaseCreate_getOptions_Query>(
    CREATE_RELEASE_PAGE_QUERY,
    getReleaseOptionsQuery,
  );

  const applicationName = releaseOptions.application?.name ?? "";

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ReleaseCreate.title"
            defaultMessage="Create Release for {applicationName}"
            values={{ applicationName }}
          />
        }
      />
      <Page.Main>
        <div className="bg-white border-0 shadow-sm flex-grow-1 p-4 rounded-3">
          <Release releaseOptions={releaseOptions} />
        </div>
      </Page.Main>
    </Page>
  );
};

const ReleaseCreatePage = () => {
  const { applicationId = "" } = useParams();

  const [getReleaseOptionsQuery, getReleaseOptions] =
    useQueryLoader<ReleaseCreate_getOptions_Query>(CREATE_RELEASE_PAGE_QUERY);

  const fetchReleaseOptions = useCallback(
    () => getReleaseOptions({ applicationId }, { fetchPolicy: "network-only" }),
    [getReleaseOptions, applicationId],
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
          <ReleaseWrapper getReleaseOptionsQuery={getReleaseOptionsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ReleaseCreatePage;
