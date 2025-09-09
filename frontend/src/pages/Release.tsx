/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  PreloadedQuery,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import type {
  Release_getRelease_Query,
  Release_getRelease_Query$data,
} from "api/__generated__/Release_getRelease_Query.graphql";

import { Link, Route } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import ContainersTable from "components/ContainersTable";
import Table, { createColumnHelper } from "components/Table";
import Stack from "components/Stack";
import Button from "components/Button";
import Icon from "components/Icon";
import { Collapse } from "react-bootstrap";
import ReleaseDevicesTable from "components/ReleaseDevicesTable";

const CONTAINERS_TO_LOAD_FIRST = 5;

const GET_RELEASE_QUERY = graphql`
  query Release_getRelease_Query($releaseId: ID!, $first: Int, $after: String) {
    release(id: $releaseId) {
      version
      application {
        name
      }
      systemModels {
        id
        name
      }
      ...ContainersTable_ContainerFragment
      ...ReleaseDevicesTable_DeploymentsFragment
    }
  }
`;

type Release = NonNullable<Release_getRelease_Query$data["release"]>;
interface ReleaseContentProps {
  release: Release;
}
type SystemModels = Release["systemModels"];

// TODO: decide if include more information about the system models. if yes,
// consider de-duplicate this code and use SysteemModelsTable instead
type TableRecord = SystemModels[number];

const columnHelper = createColumnHelper<TableRecord>();
const columns = [
  columnHelper.accessor("name", {
    header: () => (
      <FormattedMessage
        id="components.ReleasesSystemModelsTable.nameTitle"
        defaultMessage="Name"
      />
    ),
    cell: ({ row, getValue }) => (
      <Link
        route={Route.systemModelsEdit}
        params={{ systemModelId: row.original.id }}
      >
        {getValue()}
      </Link>
    ),
  }),
];

type ReleaseSystemModelsProps = {
  className?: string;
  systemModels: SystemModels;
};

const ReleaseSystemModels = ({
  className,
  systemModels: data,
}: ReleaseSystemModelsProps) => {
  const [isOpenSysModsSection, setIsOpenSysModsSection] = useState(true);

  const systemModels =
    data?.filter((sm): sm is TableRecord => sm != null) ?? [];

  return (
    <div>
      <Button
        variant="light"
        className="w-100 d-flex align-items-center fw-bold"
        onClick={() => setIsOpenSysModsSection((prevState) => !prevState)}
        aria-expanded={isOpenSysModsSection}
      >
        <FormattedMessage
          id="pages.Release.systemModels"
          defaultMessage="System Models"
        />
        <span className="ms-auto">
          {isOpenSysModsSection ? (
            <Icon icon="caretUp" />
          ) : (
            <Icon icon="caretDown" />
          )}
        </span>
      </Button>
      <Collapse in={isOpenSysModsSection}>
        <div className="p-2 border-top">
          {systemModels.length ? (
            <Table
              className={className}
              columns={columns}
              data={systemModels}
              hideSearch
            />
          ) : (
            "No required system model. This release can be applied to any device."
          )}
        </div>
      </Collapse>
    </div>
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
        <Stack gap={2}>
          <Alert
            show={!!errorFeedback}
            variant="danger"
            onClose={() => setErrorFeedback(null)}
            dismissible
          >
            {errorFeedback}
          </Alert>
          <ReleaseSystemModels systemModels={release["systemModels"]} />
          <ContainersTable containersRef={release} />
          <ReleaseDevicesTable releaseDevicesRef={release} />
        </Stack>
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
        { releaseId, first: CONTAINERS_TO_LOAD_FIRST },
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
