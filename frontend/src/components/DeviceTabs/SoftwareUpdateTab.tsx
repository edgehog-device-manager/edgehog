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
  useEffect,
  useState,
  useRef,
  useCallback,
  Suspense,
  useMemo,
} from "react";
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
  UseMutationConfig,
} from "react-relay/hooks";

import type { Device_getBaseImageCollections_Query } from "@/api/__generated__/Device_getBaseImageCollections_Query.graphql";
import type {
  SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation,
  SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation$data,
} from "@/api/__generated__/SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation.graphql";
import type {
  SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation,
  SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation$data,
} from "@/api/__generated__/SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation.graphql";
import type { SoftwareUpdateTab_PaginationQuery } from "@/api/__generated__/SoftwareUpdateTab_PaginationQuery.graphql";
import type { SoftwareUpdateTab_otaOperations$key } from "@/api/__generated__/SoftwareUpdateTab_otaOperations.graphql";

import Alert from "@/components/Alert";
import OperationTable from "@/components/OperationTable";
import Spinner from "@/components/Spinner";
import { Tab } from "@/components/Tabs";
import BaseImageForm from "@/forms/BaseImageForm";
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

const DEVICE_CREATE_MANUAL_OTA_OPERATION_NO_EXISTING_IMAGE_MUTATION = graphql`
  mutation SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation(
    $input: CreateManualOtaOperationNoExistingBaseImageInput!
  ) {
    createManualOtaOperationNoExistingBaseImage(input: $input) {
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

const DEVICE_CREATE_MANUAL_OTA_OPERATION_EXISTING_IMAGE_MUTATION = graphql`
  mutation SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation(
    $input: CreateManualOtaOperationExistingBaseImageInput!
  ) {
    createManualOtaOperationExistingBaseImage(input: $input) {
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

type OTAOperationFunctionIncompleteVariables = {
  input: {
    deviceId: string;
    baseImageFile?: File;
    baseImageUrl?: string;
  };
};

type OTAOperationFunctionVariables =
  UseMutationConfig<SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation>["variables"] &
    UseMutationConfig<SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation>["variables"];

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

  const { data } = usePaginationFragment<
    SoftwareUpdateTab_PaginationQuery,
    SoftwareUpdateTab_otaOperations$key
  >(DEVICE_OTA_OPERATIONS_FRAGMENT, deviceRef);

  const deviceId = data.id;

  const [
    createOtaOperationNoExistingImage,
    isCreatingOtaOperationNoExistingImage,
  ] =
    useMutation<SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation>(
      DEVICE_CREATE_MANUAL_OTA_OPERATION_NO_EXISTING_IMAGE_MUTATION,
    );
  const [createOtaOperationExistingImage, isCreatingOtaOperationExistingImage] =
    useMutation<SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation>(
      DEVICE_CREATE_MANUAL_OTA_OPERATION_EXISTING_IMAGE_MUTATION,
    );
  const pickOTAOperationFunction = useCallback(
    (...input: Array<File | string>) => {
      const variables: OTAOperationFunctionIncompleteVariables = {
        input: {
          deviceId,
        },
      };
      if (input.length === 1) {
        const [baseImage] = input;
        if (baseImage instanceof File) {
          variables.input.baseImageFile = baseImage;
          return {
            func: createOtaOperationNoExistingImage,
            vars: variables as UseMutationConfig<SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation>["variables"],
          };
        } else if (typeof baseImage === "string") {
          variables.input.baseImageUrl = baseImage;
          return {
            func: createOtaOperationExistingImage,
            vars: variables as UseMutationConfig<SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation>["variables"],
          };
        }
      }
      throw new TypeError(
        "Only one Base Image can be submitted for an update.",
      );
    },
    [
      createOtaOperationNoExistingImage,
      createOtaOperationExistingImage,
      deviceId,
    ],
  );

  const isCreatingOtaOperation = useMemo(
    () =>
      isCreatingOtaOperationNoExistingImage ||
      isCreatingOtaOperationExistingImage,
    [
      isCreatingOtaOperationNoExistingImage,
      isCreatingOtaOperationExistingImage,
    ],
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

  const launchManualOTAUpdate = (...input: Array<File | string>) => {
    const { func: createOtaOperation, vars: variables } =
      pickOTAOperationFunction(...input);
    createOtaOperation({
      variables: variables as OTAOperationFunctionVariables,
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
        if (data) {
          let mutData:
            | SoftwareUpdateTab_createManualOtaOperationNoExistingBaseImage_Mutation$data["createManualOtaOperationNoExistingBaseImage"]
            | SoftwareUpdateTab_createManualOtaOperationExistingBaseImage_Mutation$data["createManualOtaOperationExistingBaseImage"]
            | undefined;
          if ("createManualOtaOperationNoExistingBaseImage" in data) {
            mutData = data.createManualOtaOperationNoExistingBaseImage;
          } else if (
            data &&
            "createManualOtaOperationExistingBaseImage" in data
          ) {
            mutData = data.createManualOtaOperationExistingBaseImage;
          }
          const otaOperationId = mutData?.result?.id;
          if (otaOperationId) {
            const otaOperation = store.get(otaOperationId);
            const storedDevice = store.get(deviceId);
            const otaOperations =
              storedDevice?.getLinkedRecords("otaOperations");
            if (storedDevice && otaOperation && otaOperations) {
              storedDevice.setLinkedRecords(
                [otaOperation, ...otaOperations],
                "otaOperations",
              );
            }
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
          <BaseImageForm
            className="mt-3"
            onManualOTAImageSubmit={launchManualOTAUpdate}
            isLoading={isCreatingOtaOperation}
            baseImageCollectionsData={baseImageCollections}
          />
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

export const DisabledDeviceSoftwareTab = () => {
  const intl = useIntl();
  return (
    <Tab
      className="disabled"
      eventKey="device-software-update-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.SoftwareUpdateTab",
        defaultMessage: "Software Updates",
      })}
    />
  );
};

export default DeviceSoftwareUpdateTab;
