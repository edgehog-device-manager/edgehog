/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { Suspense } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";

import Center from "components/Center";
import Page from "components/Page";
import Spinner from "components/Spinner";

const DeploymentCampaignsContent = () => {
  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Campaigns.title"
            defaultMessage="Campaigns"
          />
        }
      />
    </Page>
  );
};

const DeploymentCampaignsPage = () => {
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
      >
        <DeploymentCampaignsContent />
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentCampaignsPage;
