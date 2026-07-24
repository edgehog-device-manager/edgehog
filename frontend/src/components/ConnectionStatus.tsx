/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2026 SECO Mind Srl
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

import { useIntl } from "react-intl";

import Icon from "@/components/Icon";

interface Props {
  connected: boolean;
  icon?: boolean;
}

const ConnectionStatus = ({ connected, icon = true }: Props) => {
  const intl = useIntl();

  const color = connected ? "text-success" : "text-secondary";

  const label = connected
    ? intl.formatMessage({
        id: "components.ConnectionStatus.statusConnected",
        defaultMessage: "Online",
      })
    : intl.formatMessage({
        id: "components.ConnectionStatus.statusDisconnected",
        defaultMessage: "Offline",
      });

  const showIcon = connected ? "deviceOnline" : "deviceOffline";

  return (
    <div className="d-flex align-items-left">
      {icon && <Icon icon={showIcon} className={`me-2 ${color}`} />}
      <span>{label}</span>
    </div>
  );
};

export default ConnectionStatus;
