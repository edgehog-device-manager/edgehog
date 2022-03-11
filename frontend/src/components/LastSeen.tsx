/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

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

import { FormattedDate, FormattedMessage } from "react-intl";

type Props = {
  lastConnection: string | null;
  lastDisconnection: string | null;
  online: boolean;
};

const LastSeen = ({ lastConnection, lastDisconnection, online }: Props) => {
  if (online) {
    return (
      <FormattedMessage id="components.LastSeen.now" defaultMessage="Now" />
    );
  } else if (lastDisconnection) {
    return (
      <FormattedDate
        value={new Date(lastDisconnection)}
        year="numeric"
        month="long"
        day="numeric"
        hour="numeric"
        minute="numeric"
      />
    );
  } else {
    return (
      <FormattedMessage id="components.LastSeen.never" defaultMessage="Never" />
    );
  }
};

export default LastSeen;
