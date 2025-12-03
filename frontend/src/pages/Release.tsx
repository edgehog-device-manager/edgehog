/*
 * This file is part of Edgehog.
 *
 * Copyright 2024, 2025 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  PreloadedQuery,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { FormattedMessage, useIntl } from "react-intl";

import type {
  Release_getRelease_Query,
  Release_getRelease_Query$data,
} from "@/api/__generated__/Release_getRelease_Query.graphql";

import { Link, Route } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import ContainersTable from "@/components/ContainersTable";
import ReleaseDevicesTable from "@/components/ReleaseDevicesTable";
import ReleaseSystemModelsTable from "@/components/ReleaseSystemModelsTable";
import Tabs, { Tab } from "@/components/Tabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const GET_RELEASE_QUERY = graphql`
  query Release_getRelease_Query($releaseId: ID!, $first: Int, $after: String) {
    release(id: $releaseId) {
      version
      application {
        name
      }
      ...ContainersTable_ContainerFragment
      ...ReleaseSystemModelsTable_SystemModelsFragment
      ...ReleaseDevicesTable_DeploymentsFragment
    }
  }
`;

type Release = NonNullable<Release_getRelease_Query$data["release"]>;

interface ContainersTabProps {
  release: Release;
}

const ContainersTab = ({ release }: ContainersTabProps) => {
  const intl = useIntl();

  return (
    <Tab
      eventKey="containers-tab"
      title={intl.formatMessage({
        id: "pages.Release.containers",
        defaultMessage: "Containers",
      })}
    >
      <div className="mt-3">
        <ContainersTable containersRef={release} />
      </div>
    </Tab>
  );
};

interface ReleaseContentProps {
  release: Release;
}

interface SystemModelsTabProps {
  release: Release;
}

const SystemModelsTab = ({ release }: SystemModelsTabProps) => {
  const intl = useIntl();

  return (
    <Tab
      eventKey="system-models-tab"
      title={intl.formatMessage({
        id: "pages.Release.systemModels",
        defaultMessage: "System Models",
      })}
    >
      <div className="mt-3">
        <ReleaseSystemModelsTable systemModelsRef={release} />
      </div>
    </Tab>
  );
};

interface DevicesTabProps {
  release: Release;
}

const DevicesTab = ({ release }: DevicesTabProps) => {
  const intl = useIntl();

  return (
    <Tab
      eventKey="devices-tab"
      title={intl.formatMessage({
        id: "pages.Release.devices",
        defaultMessage: "Devices",
      })}
    >
      <div className="mt-3">
        <ReleaseDevicesTable releaseDevicesRef={release} />
      </div>
    </Tab>
  );
};

const ReleaseContent = ({ release }: ReleaseContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  return (
    <Page>
      <Page.Header
        title={`${release.application?.name ?? ""} (v${release.version})`}
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

        <Tabs
          defaultActiveKey="containers-tab"
          tabsOrder={["containers-tab", "system-models-tab", "devices-tab"]}
        >
          <ContainersTab release={release} />
          <SystemModelsTab release={release} />
          <DevicesTab release={release} />
        </Tabs>
      </Page.Main>
    </Page>
  );
};

type ReleaseWrapperProps = {
  getReleaseQuery: PreloadedQuery<Release_getRelease_Query>;
};

const ReleaseWrapper = ({ getReleaseQuery }: ReleaseWrapperProps) => {
  const { release } = usePreloadedQuery(GET_RELEASE_QUERY, getReleaseQuery);

  if (!release) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Release.releaseNotFound.title"
            defaultMessage="Release not found."
          />
        }
      >
        <Link route={Route.applications}>
          <FormattedMessage
            id="pages.Release.releaseNotFound.message"
            defaultMessage="Return to the applications list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <ReleaseContent release={release} />;
};

const ReleasePage = () => {
  const { releaseId = "" } = useParams();

  const [getReleaseQuery, getRelease] =
    useQueryLoader<Release_getRelease_Query>(GET_RELEASE_QUERY);

  const fetchRelease = useCallback(
    () =>
      getRelease(
        { releaseId, first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "network-only" },
      ),
    [getRelease, releaseId],
  );

  useEffect(fetchRelease, [fetchRelease]);

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
        onReset={fetchRelease}
      >
        {getReleaseQuery && (
          <ReleaseWrapper getReleaseQuery={getReleaseQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ReleasePage;
