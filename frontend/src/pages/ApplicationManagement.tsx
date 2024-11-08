/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import Center from "components/Center";
import Page from "components/Page";
import { FunctionComponent, Suspense } from "react";
import { Spinner } from "react-bootstrap";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";

interface Props {}

const { LoadingError, Header, Main } = Page;

const ApplicationManagement: FunctionComponent<Props> = () => (
  <Suspense
    fallback={
      <Center data-testid="page-loading">
        <Spinner />
      </Center>
    }
  >
    <ErrorBoundary
      FallbackComponent={({ resetErrorBoundary }) => (
        <Center data-testid="page-error">
          <LoadingError onRetry={resetErrorBoundary} />
        </Center>
      )}
    >
      <Page>
        <Header
          title={<FormattedMessage id="pages.ApplicationManagement.title" />}
        />
        <Main></Main>
      </Page>
    </ErrorBoundary>
  </Suspense>
);

export default ApplicationManagement;
