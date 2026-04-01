/*
 * This file is part of Edgehog.
 *
 * Copyright 2025-2026 SECO Mind Srl
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

import React, {
  useCallback,
  useEffect,
  useRef,
  useState,
  Suspense,
} from "react";
import { ToggleButton, ToggleButtonGroup } from "react-bootstrap";
import type { Subscription } from "relay-runtime";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  useMutation,
  fetchQuery,
  useRelayEnvironment,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { SoftwareUpdateTab_createManualOtaOperation_Mutation } from "@/api/__generated__/SoftwareUpdateTab_createManualOtaOperation_Mutation.graphql";
import type { SoftwareUpdateTab_getBaseImageCollections_Query } from "@/api/__generated__/SoftwareUpdateTab_getBaseImageCollections_Query.graphql";
import type { SoftwareUpdateTab_PaginationQuery } from "@/api/__generated__/SoftwareUpdateTab_PaginationQuery.graphql";
import type { SoftwareUpdateTab_otaOperations$key } from "@/api/__generated__/SoftwareUpdateTab_otaOperations.graphql";

import Alert from "@/components/Alert";
import OperationTable from "@/components/OperationTable";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import ManualOtaFromCollectionForm from "@/forms/ManualOtaFromCollectionForm";
import ManualOtaFromFileForm from "@/forms/ManualOtaFromFileForm";

const DEVICE_OTA_OPERATIONS_FRAGMENT = graphql`
  fragment SoftwareUpdateTab_otaOperations on Device
  @refetchable(queryName: "SoftwareUpdateTab_PaginationQuery") {
    id
    capabilities
    otaOperations(first: $first, after: $after)
      @connection(key: "SoftwareUpdateTab_otaOperations") {
      edges {
        node {
          id
          baseImageUrl
          status
          createdAt
        }
      }
    }
    ...OperationTable_otaOperations
  }
`;

const GET_DEVICE_OTA_OPERATIONS_QUERY = graphql`
  query SoftwareUpdateTab_getDeviceOtaOperations_Query(
    $id: ID!
    $first: Int
    $after: String
  ) {
    device(id: $id) {
      id
      ...Device_connectionStatus
      ...SoftwareUpdateTab_otaOperations
    }
  }
`;

const DEVICE_CREATE_MANUAL_OTA_OPERATION_MUTATION = graphql`
  mutation SoftwareUpdateTab_createManualOtaOperation_Mutation(
    $input: CreateManualOtaOperationInput!
  ) {
    createManualOtaOperation(input: $input) {
      result {
        id
        baseImageUrl
        createdAt
        status
        statusCode
        updatedAt
      }
    }
  }
`;

const GET_BASE_IMAGE_COLL_QUERY = graphql`
  query SoftwareUpdateTab_getBaseImageCollections_Query(
    $first: Int
    $after: String
    $filterBaseImageCollections: BaseImageCollectionFilterInput = {}
  ) {
    ...ManualOtaFromCollectionForm_baseImageCollections_Fragment
      @arguments(filter: $filterBaseImageCollections)
  }
`;

type OtaOperationInput = {
  imageFile?: File;
  imageUrl?: string;
};

type ManualOtaFromCollectionFormWrapperProps = {
  baseImageCollsQueryRef: PreloadedQuery<SoftwareUpdateTab_getBaseImageCollections_Query>;
  isCreatingOtaOperation: boolean;
  launchManualOTAUpdate: (input: OtaOperationInput) => void;
};

const ManualOtaFromCollectionFormWrapper = ({
  baseImageCollsQueryRef,
  isCreatingOtaOperation,
  launchManualOTAUpdate,
}: ManualOtaFromCollectionFormWrapperProps) => {
  const baseImageCollections = usePreloadedQuery(
    GET_BASE_IMAGE_COLL_QUERY,
    baseImageCollsQueryRef,
  );

  return (
    <ManualOtaFromCollectionForm
      baseImageCollectionsData={baseImageCollections}
      isLoading={isCreatingOtaOperation}
      onManualOTAImageSubmit={launchManualOTAUpdate}
    />
  );
};

type DeviceSoftwareUpdateTabProps = {
  deviceRef: SoftwareUpdateTab_otaOperations$key;
};

const DeviceSoftwareUpdateTab = ({
  deviceRef,
}: DeviceSoftwareUpdateTabProps) => {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const intl = useIntl();
  const relayEnvironment = useRelayEnvironment();

  const [updateMode, setUpdateMode] = useState<"file" | "collection">("file");

  const { data } = usePaginationFragment<
    SoftwareUpdateTab_PaginationQuery,
    SoftwareUpdateTab_otaOperations$key
  >(DEVICE_OTA_OPERATIONS_FRAGMENT, deviceRef);

  const deviceId = data.id;

  const [createOtaOperation, isCreatingOtaOperation] =
    useMutation<SoftwareUpdateTab_createManualOtaOperation_Mutation>(
      DEVICE_CREATE_MANUAL_OTA_OPERATION_MUTATION,
    );

  const otaOperations = (
    data.otaOperations?.edges?.map(({ node }) => node) || []
  ).sort((a, b) => {
    if (a.createdAt > b.createdAt) {
      return -1;
    }
    if (a.createdAt < b.createdAt) {
      return 1;
    }
    return 0;
  });

  const lastFinishedOperationIndex = otaOperations.findIndex(
    ({ status }) => status === "SUCCESS" || status === "FAILURE",
  );

  const currentOperations =
    lastFinishedOperationIndex === -1
      ? otaOperations
      : otaOperations.slice(0, lastFinishedOperationIndex);

  // For now devices only support 1 update operation at a time
  const currentOperation = currentOperations[0] || null;

  // TODO: use GraphQL subscription (when available) to get updates about OTA operation
  const subscriptionRef = useRef<Subscription | null>(null);
  useEffect(() => {
    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
      }
    };
  }, []);

  useEffect(() => {
    if (!currentOperation || isRefreshing) {
      return;
    }
    const refreshTimerId = setTimeout(() => {
      setIsRefreshing(true);
      subscriptionRef.current = fetchQuery(
        relayEnvironment,
        GET_DEVICE_OTA_OPERATIONS_QUERY,
        {
          id: deviceId,
          first: 10_000,
        },
      ).subscribe({
        complete: () => {
          setIsRefreshing(false);
        },
        error: () => {
          setIsRefreshing(false);
        },
      });
    }, 10000);

    return () => {
      clearTimeout(refreshTimerId);
    };
  }, [
    currentOperation,
    isRefreshing,
    setIsRefreshing,
    relayEnvironment,
    deviceId,
  ]);

  const [getBaseImageCollsQuery, getBaseImageColls] =
    useQueryLoader<SoftwareUpdateTab_getBaseImageCollections_Query>(
      GET_BASE_IMAGE_COLL_QUERY,
    );

  const fetchBaseImageColls = useCallback(
    () =>
      getBaseImageColls(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getBaseImageColls],
  );

  useEffect(fetchBaseImageColls, [fetchBaseImageColls]);

  if (!data.capabilities.includes("SOFTWARE_UPDATES")) {
    return null;
  }

  const launchManualOTAUpdate = ({
    imageFile,
    imageUrl,
  }: OtaOperationInput) => {
    createOtaOperation({
      variables: {
        input: {
          deviceId,
          baseImageFile: imageFile,
          baseImageUrl: imageUrl,
        },
      },
      onCompleted(_data, errors) {
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
            id="components.DeviceTabs.SoftwareUpdateTab.otaUpdateCreationErrorFeedback"
            defaultMessage="Could not start the OTA update, please try again."
          />,
        );
      },
      updater(store, data) {
        const otaOperationId = data?.createManualOtaOperation?.result?.id;
        if (otaOperationId) {
          const otaOperation = store.get(otaOperationId);
          const storedDevice = store.get(deviceId);
          const otaOperations = storedDevice?.getLinkedRecords("otaOperations");
          if (storedDevice && otaOperation && otaOperations) {
            storedDevice.setLinkedRecords(
              [otaOperation, ...otaOperations],
              "otaOperations",
            );
          }
        }
      },
    });
  };

  return (
    <Tab
      eventKey="device-software-update-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.SoftwareUpdateTab",
        defaultMessage: "Software Updates",
      })}
    >
      <div className="mt-3">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.SoftwareUpdateTab.manualOTAUpdate"
            defaultMessage="Manual OTA Update"
          />
        </h5>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <Suspense fallback={<Spinner />}>
          <Stack direction="vertical" gap={3} className="mt-3">
            <div>
              <ToggleButtonGroup
                type="radio"
                name="updateMode"
                value={updateMode}
                onChange={setUpdateMode}
                size="sm"
              >
                <ToggleButton
                  id="mode-file"
                  value="file"
                  variant={
                    updateMode === "file" ? "primary" : "outline-secondary"
                  }
                  className="fw-medium px-3"
                >
                  <FormattedMessage
                    id="components.DeviceTabs.SoftwareUpdateTab.modeFile"
                    defaultMessage="File"
                  />
                </ToggleButton>

                <ToggleButton
                  id="mode-collection"
                  value="collection"
                  variant={
                    updateMode === "collection"
                      ? "primary"
                      : "outline-secondary"
                  }
                  className="fw-medium px-3"
                >
                  <FormattedMessage
                    id="components.DeviceTabs.SoftwareUpdateTab.modeCollection"
                    defaultMessage="Collection"
                  />
                </ToggleButton>
              </ToggleButtonGroup>
            </div>
            {updateMode === "collection" ? (
              getBaseImageCollsQuery && (
                <ManualOtaFromCollectionFormWrapper
                  baseImageCollsQueryRef={getBaseImageCollsQuery}
                  isCreatingOtaOperation={isCreatingOtaOperation}
                  launchManualOTAUpdate={launchManualOTAUpdate}
                />
              )
            ) : (
              <ManualOtaFromFileForm
                isLoading={isCreatingOtaOperation}
                onManualOTAImageSubmit={launchManualOTAUpdate}
              />
            )}
          </Stack>
        </Suspense>
        {currentOperation && (
          <div className="mt-3">
            <FormattedMessage
              id="components.DeviceTabs.SoftwareUpdateTab.updatingTo"
              defaultMessage="Updating to image <a>{baseImageName}</a>"
              values={{
                a: (chunks: React.ReactNode) => (
                  <a
                    target="_blank"
                    rel="noreferrer"
                    href={currentOperation.baseImageUrl}
                  >
                    {chunks}
                  </a>
                ),
                baseImageName: currentOperation.baseImageUrl.split("/").pop(),
              }}
            />
            {isRefreshing && <Spinner size="sm" className="ms-2" />}
          </div>
        )}
        <h5 className="mt-4">
          <FormattedMessage
            id="components.DeviceTabs.SoftwareUpdateTab.updatesHistory"
            defaultMessage="History"
          />
        </h5>
        <OperationTable deviceRef={data} />
      </div>
    </Tab>
  );
};

export default DeviceSoftwareUpdateTab;
