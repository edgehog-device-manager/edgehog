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
    color = "text-gray";
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
