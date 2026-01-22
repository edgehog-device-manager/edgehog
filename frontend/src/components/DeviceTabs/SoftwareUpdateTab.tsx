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

import React, { useEffect, useState, useRef, Suspense } from "react";
import type { Subscription } from "relay-runtime";
import { FormattedMessage, useIntl } from "react-intl";
import {
  graphql,
  useMutation,
  fetchQuery,
  useRelayEnvironment,
  usePaginationFragment,
  usePreloadedQuery,
  PreloadedQuery,
} from "react-relay/hooks";
import { Form, Stack } from "react-bootstrap";

import type { Device_getBaseImageCollections_Query } from "@/api/__generated__/Device_getBaseImageCollections_Query.graphql";
import { SoftwareUpdateTab_createManualOtaOperation_Mutation } from "@/api/__generated__/SoftwareUpdateTab_createManualOtaOperation_Mutation.graphql";
import type { SoftwareUpdateTab_PaginationQuery } from "@/api/__generated__/SoftwareUpdateTab_PaginationQuery.graphql";
import type { SoftwareUpdateTab_otaOperations$key } from "@/api/__generated__/SoftwareUpdateTab_otaOperations.graphql";

import Alert from "@/components/Alert";
import OperationTable from "@/components/OperationTable";
import Spinner from "@/components/Spinner";
import { Tab } from "@/components/Tabs";
import ManualOtaFromCollectionForm from "@/forms/ManualOtaFromCollectionForm";
import ManualOtaFromFileForm from "@/forms/ManualOtaFromFileForm";
import { GET_BASE_IMAGE_COLL_QUERY } from "@/pages/Device";

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

export type GetBaseImageCollsQueryType = PreloadedQuery<
  Device_getBaseImageCollections_Query,
  Record<string, unknown>
>;

type OtaOperationInput = {
  imageFile?: File;
  imageUrl?: string;
};

type DeviceSoftwareUpdateTabProps = {
  deviceRef: SoftwareUpdateTab_otaOperations$key;
  getBaseImageCollsQuery: GetBaseImageCollsQueryType;
};

const DeviceSoftwareUpdateTab = ({
  deviceRef,
  getBaseImageCollsQuery,
}: DeviceSoftwareUpdateTabProps) => {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const intl = useIntl();
  const relayEnvironment = useRelayEnvironment();

  const [updateMode, setUpdateMode] = useState<"collection" | "file">(
    "collection",
  );
  const modeOnChange =
    (mode: "collection" | "file") =>
    (_event: React.ChangeEvent<HTMLInputElement>) =>
      setUpdateMode(mode);

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

  const baseImageCollections = usePreloadedQuery(
    GET_BASE_IMAGE_COLL_QUERY,
    getBaseImageCollsQuery,
  );

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
          <Stack direction="vertical" className="mt-3">
            <Form.Group key="updateMode">
              <Form.Check
                name="updateMode"
                inline
                type="radio"
                label="Collection"
                id="Collection"
                onChange={modeOnChange("collection")}
                checked={updateMode === "collection"}
              />
              <Form.Check
                name="updateMode"
                inline
                type="radio"
                label="File"
                id="File"
                onChange={modeOnChange("file")}
                checked={updateMode === "file"}
              />
            </Form.Group>
            {updateMode === "collection" ? (
              <ManualOtaFromCollectionForm
                baseImageCollectionsData={baseImageCollections}
                className="mt-3 w-75"
                isLoading={isCreatingOtaOperation}
                onManualOTAImageSubmit={launchManualOTAUpdate}
              />
            ) : (
              <ManualOtaFromFileForm
                className="mt-3 w-75"
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
