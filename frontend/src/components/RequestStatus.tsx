/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { defineMessages, FormattedMessage } from "react-intl";

import Icon from "@/components/Icon";

export type FileDownloadRequestStatus =
  | "COMPLETED"
  | "FAILED"
  | "IN_PROGRESS"
  | "PENDING"
  | "SENT";

const statusColors: Record<string, string> = {
  COMPLETED: "text-success",
  FAILED: "text-danger",
  IN_PROGRESS: "text-info",
  PENDING: "text-warning",
  SENT: "text-primary",
};

const statusMessages = defineMessages({
  COMPLETED: {
    id: "components.RequestStatus.completed",
    defaultMessage: "Completed",
  },
  FAILED: {
    id: "components.RequestStatus.failed",
    defaultMessage: "Failed",
  },
  IN_PROGRESS: {
    id: "components.RequestStatus.inProgress",
    defaultMessage: "In Progress",
  },
  PENDING: {
    id: "components.RequestStatus.pending",
    defaultMessage: "Pending",
  },
  SENT: {
    id: "components.RequestStatus.sent",
    defaultMessage: "Sent",
  },
});

const RequestStatus = ({
  status,
}: {
  status: FileDownloadRequestStatus | null;
}) => {
  if (status === null) {
    return null;
  }

  const color = statusColors[status] ?? "text-secondary";
  const message = statusMessages[status as keyof typeof statusMessages];

  const iconName = status === "IN_PROGRESS" ? "spinner" : "circle";
  const iconClass =
    status === "IN_PROGRESS"
      ? `me-2 ${color} spinner-border spinner-border-sm`
      : `me-2 ${color}`;

  return (
    <div className="d-flex align-items-center">
      <Icon icon={iconName} className={iconClass} />
      <span>{message ? <FormattedMessage id={message.id} /> : status}</span>
    </div>
  );
};

export default RequestStatus;
