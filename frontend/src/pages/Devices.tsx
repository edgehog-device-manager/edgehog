/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2025 SECO Mind Srl
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

import { Suspense, useCallback, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { Devices_getDevices_Query } from "@/api/__generated__/Devices_getDevices_Query.graphql";
import Center from "@/components/Center";
import DevicesTable from "@/components/DevicesTable";
import Page from "@/components/Page";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const GET_DEVICES_QUERY = graphql`
  query Devices_getDevices_Query(
    $first: Int
    $after: String
    $filter: DeviceFilterInput = {}
  ) {
    ...DevicesTable_DeviceFragment @arguments(filter: $filter)
  }
`;

interface DevicesContentProps {
  getDevicesQuery: PreloadedQuery<Devices_getDevices_Query>;
}

const DevicesContent = ({ getDevicesQuery }: DevicesContentProps) => {
  const devices = usePreloadedQuery(GET_DEVICES_QUERY, getDevicesQuery);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage id="pages.Devices.title" defaultMessage="Devices" />
        }
      />
      <Page.Main>
        <DevicesTable devicesRef={devices} />
      </Page.Main>
    </Page>
  );
};

const DevicesPage = () => {
  const [getDevicesQuery, getDevices] =
    useQueryLoader<Devices_getDevices_Query>(GET_DEVICES_QUERY);

  const fetchDevices = useCallback(
    () =>
      getDevices(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getDevices],
  );

  useEffect(fetchDevices, [fetchDevices]);

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
        onReset={() => getDevices({})}
      >
        {getDevicesQuery && (
          <DevicesContent getDevicesQuery={getDevicesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DevicesPage;
