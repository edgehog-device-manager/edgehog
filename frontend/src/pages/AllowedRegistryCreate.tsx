/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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
import { Card } from "react-bootstrap";

import type { AllowedRegistryCreate_allowedRegistryCreate_Mutation } from "@/api/__generated__/AllowedRegistryCreate_allowedRegistryCreate_Mutation.graphql";

import Alert from "@/components/ui/alert/Alert";
import Page from "@/components/ui/page/Page";
import { Route, useNavigate } from "@/Navigation";
import CreateAllowedRegistryForm from "@/forms/CreateAllowedRegistry";
import { AllowedRegistryFormData } from "@/forms/validation";

const CREATE_ALLOWED_REGISTRY_MUTATION = graphql`
  mutation AllowedRegistryCreate_allowedRegistryCreate_Mutation(
    $input: CreateAllowedRegistryInput!
  ) {
    createAllowedRegistry(input: $input) {
      result {
        id
      }
    }
  }
`;

const AllowedRegistryCreatePage = () => {
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);
  const navigate = useNavigate();

  const [createAllowedRegistry, isCreatingAllowedRegistry] =
    useMutation<AllowedRegistryCreate_allowedRegistryCreate_Mutation>(
      CREATE_ALLOWED_REGISTRY_MUTATION,
    );

  const handleCreateAllowedRegistry = useCallback(
    (allowedRegistry: AllowedRegistryFormData) => {
      createAllowedRegistry({
        variables: { input: allowedRegistry },
        onCompleted(data, errors) {
          const allowedRegistryId = data.createAllowedRegistry?.result?.id;
          if (allowedRegistryId) {
            return navigate({
              route: Route.allowedRegistries,
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
              id="pages.AllowedRegistryCreate.creationErrorFeedback"
              defaultMessage="Could not create the Allowed Registry, please try again."
            />,
          );
        },
      });
    },
    [createAllowedRegistry, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.AllowedRegistryCreate.title"
            defaultMessage="Create Allowed Registry"
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
        <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4 ">
          <CreateAllowedRegistryForm
            onSubmit={handleCreateAllowedRegistry}
            isLoading={isCreatingAllowedRegistry}
          />
        </Card>
      </Page.Main>
    </Page>
  );
};

export default AllowedRegistryCreatePage;
