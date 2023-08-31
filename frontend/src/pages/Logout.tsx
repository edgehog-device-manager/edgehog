/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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

import { useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { commitLocalUpdate, useRelayEnvironment } from "react-relay/hooks";

import Page from "components/Page";
import { useAuth } from "contexts/Auth";

const LogoutPage = () => {
  const auth = useAuth();
  const relayEnvironment = useRelayEnvironment();

  useEffect(() => {
    commitLocalUpdate(relayEnvironment, (store) => store.invalidateStore());
    auth.logout();
  }, [relayEnvironment, auth]);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage id="pages.Logout.title" defaultMessage="Logout" />
        }
      />
      <Page.Main></Page.Main>
    </Page>
  );
};

export default LogoutPage;
