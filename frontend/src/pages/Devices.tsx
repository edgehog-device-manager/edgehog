import React, { Suspense, useEffect, useMemo } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";

import type { Devices_getDevices_Query } from "api/__generated__/Devices_getDevices_Query.graphql";
import Center from "components/Center";
import DevicesTable from "components/DevicesTable";
import Page from "components/Page";
import Spinner from "components/Spinner";

const GET_DEVICES_QUERY = graphql`
  query Devices_getDevices_Query {
    devices {
      id
      deviceId
      name
    }
  }
`;

interface DevicesContentProps {
  getDevicesQuery: PreloadedQuery<Devices_getDevices_Query>;
}

const DevicesContent = ({ getDevicesQuery }: DevicesContentProps) => {
  const devicesData = usePreloadedQuery(GET_DEVICES_QUERY, getDevicesQuery);

  // TODO: handle readonly type without mapping to mutable type
  const devices = useMemo(
    () => devicesData.devices.map((device) => ({ ...device, online: true })),
    [devicesData]
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Devices.title"
            defaultMessage="Device List"
          />
        }
      />
      <Page.Main>
        <DevicesTable data={devices} />
      </Page.Main>
    </Page>
  );
};

const DevicesPage = () => {
  const [getDevicesQuery, getDevices] =
    useQueryLoader<Devices_getDevices_Query>(GET_DEVICES_QUERY);

  useEffect(() => getDevices({}), [getDevices]);

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
