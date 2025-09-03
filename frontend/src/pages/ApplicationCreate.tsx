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

import { Suspense, useCallback, useState } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useMutation } from "react-relay/hooks";
import { ErrorBoundary } from "react-error-boundary";

import type { ApplicationCreate_createApplication_Mutation } from "api/__generated__/ApplicationCreate_createApplication_Mutation.graphql";

import Alert from "components/Alert";
import Page from "components/Page";
import CreateApplicationForm from "forms/CreateApplication";
import type { ApplicationData } from "forms/CreateApplication";
import { Route, useNavigate } from "Navigation";
import Center from "components/Center";
import Spinner from "components/Spinner";

const CREATE_APPLICATION_MUTATION = graphql`
  mutation ApplicationCreate_createApplication_Mutation(
    $input: CreateApplicationInput!
  ) {
    createApplication(input: $input) {
      result {
        id
        description
      }
    }
  }
`;

const Application = () => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const [createApplication, isCreatingApplication] =
    useMutation<ApplicationCreate_createApplication_Mutation>(
      CREATE_APPLICATION_MUTATION,
    );

  const handleCreateApplication = useCallback(
    (application: ApplicationData) => {
      const newApplication = { ...application };

      createApplication({
        variables: { input: newApplication },
        onCompleted(data, errors) {
          const applicationId = data.createApplication?.result?.id;
          if (applicationId) {
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
              id="pages.ApplicationCreate.creationErrorFeedback"
              defaultMessage="Could not create the application, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createApplication?.result?.id) {
            return;
          }

          const application = store
            .getRootField("createApplication")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const applications = root.getLinkedRecord("applications", {
            id: "root",
          });

          if (applications) {
            root.setLinkedRecords(
              applications
                ? [
                    ...(applications.getLinkedRecords("applications") || []),
                    application,
                  ]
                : [application],
              "applications",
            );
          }
        },
      });
    },
    [createApplication, navigate, errorFeedback],
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
      <CreateApplicationForm
        onSubmit={handleCreateApplication}
        isLoading={isCreatingApplication}
      />
    </>
  );
};

const ApplicationWrapper = () => {
  return <Application />;
};

const ApplicationCreatePage = () => {
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
      >
        <Page>
          <Page.Header
            title={
              <FormattedMessage
                id="pages.ApplicationCreate.title"
                defaultMessage="Create Application"
              />
            }
          />
          <Page.Main>
            <ApplicationWrapper />
          </Page.Main>
        </Page>
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplicationCreatePage;
