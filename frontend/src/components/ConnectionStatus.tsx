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

import React from "react";
import { useIntl } from "react-intl";

import Icon from "components/Icon";

interface Props {
  connected: boolean;
  icon?: boolean;
}

const ConnectionStatus = ({ connected, icon = true }: Props) => {
  const intl = useIntl();
  let color = "text-success";
  let label = intl.formatMessage({
    id: "components.ConnectionStatus.statusConnected",
    defaultMessage: "Connected",
  });
  if (!connected) {
    color = "text-secondary";
    label = intl.formatMessage({
      id: "components.ConnectionStatus.statusDisconnected",
      defaultMessage: "Disconnected",
    });
  }
  return (
    <div className="d-flex align-items-center">
      {icon && <Icon icon="circle" className={`me-2 ${color}`} />}
      <span>{label}</span>
    </div>
  );
};

export default ConnectionStatus;
