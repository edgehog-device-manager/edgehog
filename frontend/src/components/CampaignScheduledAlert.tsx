/*
  This file is part of Edgehog.

  Copyright 2026 SECO Mind Srl

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

import type { ReactNode } from "react";
import Countdown, { type CountdownRenderProps } from "react-countdown";
import { FormattedMessage } from "react-intl";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Icon from "@/components/Icon";

const renderCountdown = ({
  completed,
  days,
  hours,
  minutes,
  seconds,
}: CountdownRenderProps) => {
  if (completed) return null;

  const duration = [
    days > 0 ? `${days}d` : null,
    hours > 0 || days > 0 ? `${hours}h` : null,
    minutes > 0 || hours > 0 || days > 0 ? `${minutes}m` : null,
    `${seconds}s`,
  ].filter(Boolean);

  return (
    <strong>
      <FormattedMessage
        id="components.CampaignScheduledAlert.startsIn"
        defaultMessage="Starts in {duration}"
        values={{ duration: duration.join(" ") }}
      />
    </strong>
  );
};

type CampaignScheduledAlertProps = {
  show: boolean;
  scheduledAt?: string | null;
  isValidScheduledDate: boolean;
  formattedScheduledDate: ReactNode;
  onEdit: () => void;
  onDelete: () => void;
};

const CampaignScheduledAlert = ({
  show,
  scheduledAt,
  isValidScheduledDate,
  formattedScheduledDate,
  onEdit,
  onDelete,
}: CampaignScheduledAlertProps) => {
  const scheduledDate = scheduledAt ? new Date(scheduledAt) : null;

  return (
    <Alert show={show} variant="warning">
      <div className="d-flex align-items-center justify-content-start flex-wrap gap-2 w-100">
        <div className="d-flex align-items-center">
          <Icon icon="calendar" className="me-3 fs-3" />

          <div>
            <div className="fw-semibold">
              <FormattedMessage
                id="components.CampaignScheduledAlert.scheduledFor"
                defaultMessage="Scheduled for: {scheduledDate}"
                values={{ scheduledDate: formattedScheduledDate }}
              />
            </div>

            {isValidScheduledDate && scheduledDate && (
              <Countdown
                date={scheduledDate.getTime()}
                overtime
                renderer={renderCountdown}
              />
            )}
          </div>
        </div>

        <div className="vr d-none d-lg-block mx-4" />

        <div className="d-none d-lg-flex align-items-center">
          <Icon icon="faCircleInfo" className="me-3 fs-3" />

          <div>
            <div>
              <FormattedMessage
                id="components.CampaignScheduledAlert.scheduledMessage"
                defaultMessage="This campaign is scheduled and has not started yet."
              />
            </div>

            <div className="fw-semibold">
              <FormattedMessage
                id="components.CampaignScheduledAlert.scheduledActions"
                defaultMessage="You can edit or delete it before it begins."
              />
            </div>
          </div>
        </div>

        <div className="d-flex gap-2 ms-auto">
          <Button variant="outline-dark" size="sm" onClick={onEdit}>
            <Icon icon="edit" className="me-2" />

            <FormattedMessage
              id="components.CampaignScheduledAlert.editCampaign"
              defaultMessage="Edit Campaign"
            />
          </Button>

          <Button variant="outline-danger" size="sm" onClick={onDelete}>
            <Icon icon="delete" className="me-2" />

            <FormattedMessage
              id="components.CampaignScheduledAlert.deleteCampaign"
              defaultMessage="Delete Campaign"
            />
          </Button>
        </div>
      </div>
    </Alert>
  );
};

export default CampaignScheduledAlert;
