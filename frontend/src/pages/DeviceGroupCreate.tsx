/*
  This file is part of Edgehog.

  Copyright 2022-2023 SECO Mind Srl

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

import type { DeviceGroupCreate_createDeviceGroup_Mutation } from "api/__generated__/DeviceGroupCreate_createDeviceGroup_Mutation.graphql";
import Alert from "components/Alert";
import Page from "components/Page";
import DeviceGroupCreateForm from "forms/CreateDeviceGroup";
import type { DeviceGroupData } from "forms/CreateDeviceGroup";
import { Route, useNavigate } from "Navigation";

const CREATE_DEVICE_GROUP_MUTATION = graphql`
  mutation DeviceGroupCreate_createDeviceGroup_Mutation(
    $input: CreateDeviceGroupInput!
  ) {
    createDeviceGroup(input: $input) {
      deviceGroup {
        id
        name
        handle
        selector
        devices {
          id
        }
      }
    }
  }
`;

const DeviceGroupCreatePage = () => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const [createDeviceGroup, isCreatingDeviceGroup] =
    useMutation<DeviceGroupCreate_createDeviceGroup_Mutation>(
      CREATE_DEVICE_GROUP_MUTATION
    );

  const handleCreateDeviceGroup = useCallback(
    (deviceGroup: DeviceGroupData) => {
      createDeviceGroup({
        variables: { input: deviceGroup },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          const deviceGroupId = data.createDeviceGroup?.deviceGroup.id;
          if (deviceGroupId) {
            navigate({
              route: Route.deviceGroupsEdit,
              params: { deviceGroupId },
            });
          } else {
            navigate({ route: Route.deviceGroups });
          }
        },
        onError(error) {
          setErrorFeedback(
            <FormattedMessage
              id="pages.DeviceGroupCreate.creationErrorFeedback"
              defaultMessage="Could not create the group, please try again."
            />
          );
        },
        updater(store, data) {
          if (!data.createDeviceGroup) {
            return;
          }

          const deviceGroup = store
            .getRootField("createDeviceGroup")
            .getLinkedRecord("deviceGroup");
          const root = store.getRoot();

          const deviceGroups = root.getLinkedRecords("deviceGroups");
          if (deviceGroups) {
            root.setLinkedRecords(
              [...deviceGroups, deviceGroup],
              "deviceGroups"
            );
          }

          const devices = deviceGroup?.getLinkedRecords("devices");
          devices?.forEach((device) => {
            const deviceGroups = device.getLinkedRecords("deviceGroups");
            if (deviceGroups) {
              device.setLinkedRecords(
                [...deviceGroups, deviceGroup],
                "deviceGroups"
              );
            }
          });
        },
      });
    },
    [createDeviceGroup, navigate]
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.DeviceGroupCreate.title"
            defaultMessage="Create Group"
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
        <DeviceGroupCreateForm
          onSubmit={handleCreateDeviceGroup}
          isLoading={isCreatingDeviceGroup}
        />
      </Page.Main>
    </Page>
  );
};

export default DeviceGroupCreatePage;
