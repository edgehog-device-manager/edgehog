/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import { FormattedMessage } from "react-intl";

import Button from "components/Button";
import Page from "components/Page";
import { Link, Route } from "Navigation";

const ApplianceModelsPage = () => {
  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ApplianceModels.title"
            defaultMessage="Appliance Models"
          />
        }
      >
        <Button as={Link} route={Route.applianceModelsNew}>
          <FormattedMessage
            id="pages.ApplianceModels.createButton"
            defaultMessage="Create appliance model"
          />
        </Button>
      </Page.Header>
      <Page.Main></Page.Main>
    </Page>
  );
};

export default ApplianceModelsPage;
