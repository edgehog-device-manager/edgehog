/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

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

import type { HardwareTypeCreate_createHardwareType_Mutation } from "api/__generated__/HardwareTypeCreate_createHardwareType_Mutation.graphql";
import Alert from "components/Alert";
import Page from "components/Page";
import CreateHardwareTypeForm from "forms/CreateHardwareType";
import type { HardwareTypeData } from "forms/CreateHardwareType";
import { Route, useNavigate } from "Navigation";

const CREATE_HARDWARE_TYPE_MUTATION = graphql`
  mutation HardwareTypeCreate_createHardwareType_Mutation(
    $input: CreateHardwareTypeInput!
  ) {
    createHardwareType(input: $input) {
      hardwareType {
        id
      }
    }
  }
`;

const HardwareTypeCreatePage = () => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const [createHardwareType, isCreatingHardwareType] =
    useMutation<HardwareTypeCreate_createHardwareType_Mutation>(
      CREATE_HARDWARE_TYPE_MUTATION,
    );

  const handleCreateHardwareType = useCallback(
    (hardwareType: HardwareTypeData) => {
      createHardwareType({
        variables: { input: hardwareType },
        onCompleted(data, errors) {
          if (data.createHardwareType) {
            const hardwareTypeId = data.createHardwareType.hardwareType.id;
            return navigate({
              route: Route.hardwareTypesEdit,
              params: { hardwareTypeId },
            });
          }
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.HardwareTypeCreate.creationErrorFeedback"
              defaultMessage="Could not create the hardware type, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data.createHardwareType) {
            return;
          }

          const hardwareType = store
            .getRootField("createHardwareType")
            .getLinkedRecord("hardwareType");
          const root = store.getRoot();
          const hardwareTypes = root.getLinkedRecords("hardwareTypes");

          if (hardwareTypes) {
            root.setLinkedRecords(
              [...hardwareTypes, hardwareType],
              "hardwareTypes",
            );
          }
        },
      });
    },
    [createHardwareType, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.HardwareTypeCreate.title"
            defaultMessage="Create Hardware Type"
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
        <CreateHardwareTypeForm
          onSubmit={handleCreateHardwareType}
          isLoading={isCreatingHardwareType}
        />
      </Page.Main>
    </Page>
  );
};

export default HardwareTypeCreatePage;
