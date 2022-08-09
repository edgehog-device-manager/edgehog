/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";
import { FormattedMessage } from "react-intl";
import _ from "lodash";

import type { DeviceGroup_getDeviceGroup_Query } from "api/__generated__/DeviceGroup_getDeviceGroup_Query.graphql";
import type { DeviceGroup_updateDeviceGroup_Mutation } from "api/__generated__/DeviceGroup_updateDeviceGroup_Mutation.graphql";
import type { DeviceGroup_deleteDeviceGroup_Mutation } from "api/__generated__/DeviceGroup_deleteDeviceGroup_Mutation.graphql";
import { Link, Route, useNavigate } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import DeleteModal from "components/DeleteModal";
import DevicesTable from "components/DevicesTable";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateDeviceGroupForm from "forms/UpdateDeviceGroup";
import type { DeviceGroupData } from "forms/UpdateDeviceGroup";

const GET_DEVICE_GROUP_QUERY = graphql`
  query DeviceGroup_getDeviceGroup_Query($id: ID!) {
    deviceGroup(id: $id) {
      id
      name
      handle
      selector
      devices {
        ...DevicesTable_DeviceFragment
      }
    }
  }
`;

const UPDATE_DEVICE_GROUP_MUTATION = graphql`
  mutation DeviceGroup_updateDeviceGroup_Mutation(
    $input: UpdateDeviceGroupInput!
  ) {
    updateDeviceGroup(input: $input) {
      deviceGroup {
        id
        name
        handle
        selector
        devices {
          ...DevicesTable_DeviceFragment
        }
      }
    }
  }
`;

const DELETE_DEVICE_GROUP_MUTATION = graphql`
  mutation DeviceGroup_deleteDeviceGroup_Mutation(
    $input: DeleteDeviceGroupInput!
  ) {
    deleteDeviceGroup(input: $input) {
      deviceGroup {
        id
      }
    }
  }
`;

interface DeviceGroupContentProps {
  getDeviceGroupQuery: PreloadedQuery<DeviceGroup_getDeviceGroup_Query>;
}

const DeviceGroupContent = ({
  getDeviceGroupQuery,
}: DeviceGroupContentProps) => {
  const { deviceGroupId = "" } = useParams();
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const deviceGroupData = usePreloadedQuery(
    GET_DEVICE_GROUP_QUERY,
    getDeviceGroupQuery
  );

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteDeviceGroup, isDeletingDeviceGroup] =
    useMutation<DeviceGroup_deleteDeviceGroup_Mutation>(
      DELETE_DEVICE_GROUP_MUTATION
    );

  const handleDeleteDeviceGroup = useCallback(() => {
    const input = {
      deviceGroupId,
    };
    deleteDeviceGroup({
      variables: { input },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map((error) => error.message)
            .join(". \n");
          setErrorFeedback(errorFeedback);
          return setShowDeleteModal(false);
        }
        navigate({ route: Route.deviceGroups });
      },
      onError(error) {
        setErrorFeedback(
          <FormattedMessage
            id="pages.DeviceGroup.deletionErrorFeedback"
            defaultMessage="Could not delete the group, please try again."
          />
        );
        setShowDeleteModal(false);
      },
      updater(store) {
        const deviceGroup = store
          .getRootField("deleteDeviceGroup")
          .getLinkedRecord("deviceGroup");
        const deviceGroupId = deviceGroup.getDataID();
        const root = store.getRoot();

        const deviceGroups = root.getLinkedRecords("deviceGroups");
        if (deviceGroups) {
          root.setLinkedRecords(
            deviceGroups.filter(
              (deviceGroup) => deviceGroup.getDataID() !== deviceGroupId
            ),
            "deviceGroups"
          );
        }

        store.delete(deviceGroupId);
      },
    });
  }, [deleteDeviceGroup, deviceGroupId, navigate]);

  const [updateDeviceGroup, isUpdatingDeviceGroup] =
    useMutation<DeviceGroup_updateDeviceGroup_Mutation>(
      UPDATE_DEVICE_GROUP_MUTATION
    );

  // TODO: handle readonly type without mapping to mutable type
  const deviceGroup = useMemo(
    () => deviceGroupData.deviceGroup && { ...deviceGroupData.deviceGroup },
    [deviceGroupData.deviceGroup]
  );

  const handleUpdateDeviceGroup = useCallback(
    (deviceGroup: DeviceGroupData) => {
      const input = {
        deviceGroupId,
        ...deviceGroup,
      };
      updateDeviceGroup({
        variables: { input },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError(error) {
          setErrorFeedback(
            <FormattedMessage
              id="pages.DeviceGroup.updateErrorFeedback"
              defaultMessage="Could not update the group, please try again."
            />
          );
        },
      });
    },
    [updateDeviceGroup, deviceGroupId]
  );

  if (!deviceGroup) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.DeviceGroup.deviceGroupNotFound.title"
            defaultMessage="Group not found."
          />
        }
      >
        <Link route={Route.deviceGroups}>
          <FormattedMessage
            id="pages.DeviceGroup.deviceGroupNotFound.message"
            defaultMessage="Return to the group list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={deviceGroup.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <div className="mb-3">
          <UpdateDeviceGroupForm
            initialData={_.pick(deviceGroup, ["name", "handle", "selector"])}
            onSubmit={handleUpdateDeviceGroup}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingDeviceGroup}
          />
        </div>
        <DevicesTable devicesRef={deviceGroup.devices} hideSearch />
        {showDeleteModal && (
          <DeleteModal
            confirmText={deviceGroup.handle}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteDeviceGroup}
            isDeleting={isDeletingDeviceGroup}
            title={
              <FormattedMessage
                id="pages.DeviceGroup.deleteModal.title"
                defaultMessage="Delete Group"
                description="Title for the confirmation modal to delete a device group"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.DeviceGroup.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Group <bold>{deviceGroup}</bold>."
                description="Description for the confirmation modal to delete a device group"
                values={{
                  deviceGroup: deviceGroup.name,
                  bold: (chunks: React.ReactNode) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

const DeviceGroupPage = () => {
  const { deviceGroupId = "" } = useParams();

  const [getDeviceGroupQuery, getDeviceGroup] =
    useQueryLoader<DeviceGroup_getDeviceGroup_Query>(GET_DEVICE_GROUP_QUERY);

  useEffect(() => {
    getDeviceGroup({ id: deviceGroupId });
  }, [getDeviceGroup, deviceGroupId]);

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
        onReset={() => {
          getDeviceGroup({ id: deviceGroupId });
        }}
      >
        {getDeviceGroupQuery && (
          <DeviceGroupContent getDeviceGroupQuery={getDeviceGroupQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeviceGroupPage;
