// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { Badge, Card } from "react-bootstrap";
import { defineMessages, FormattedMessage } from "react-intl";

import { DeploymentEventType } from "@/api/__generated__/Releases_PaginationQuery.graphql";

import "@/components/DeploymentEventsCard.scss";
import type { Event } from "./DeploymentDetails";
import DeploymentEventMessage from "./DeploymentEventMessage";
import FullHeightCard from "./FullHeightCard";

const getEventTypeVariant = (eventType: DeploymentEventType): string => {
  switch (eventType) {
    case "STOPPED":
      return "secondary";
    case "STARTED":
      return "success";
    case "ERROR":
      return "danger";
    case "STARTING":
    case "STOPPING":
    case "DELETING":
    case "UPDATING":
      return "warning";
    default:
      return "secondary";
  }
};

const eventTypeMessages = defineMessages<DeploymentEventType>({
  ERROR: {
    id: "components.DeploymentLogs.EventType.Error",
    defaultMessage: "Error",
  },
  STOPPED: {
    id: "components.DeploymentLogs.EventType.Stopped",
    defaultMessage: "Stopped",
  },
  STARTING: {
    id: "components.DeploymentLogs.EventType.Starting",
    defaultMessage: "Starting",
  },
  DELETING: {
    id: "components.DeploymentLogs.EventType.Deleting",
    defaultMessage: "Deleting",
  },
  STARTED: {
    id: "components.DeploymentLogs.EventType.Started",
    defaultMessage: "Started",
  },
  STOPPING: {
    id: "components.DeploymentLogs.EventType.Stopping",
    defaultMessage: "Stopping",
  },
  UPDATING: {
    id: "components.DeploymentLogs.EventType.Updating",
    defaultMessage: "Updating",
  },
});

const EventType = ({ eventType }: { eventType: DeploymentEventType }) => (
  <div className="d-flex align-items-center">
    <Badge
      bg={getEventTypeVariant(eventType)}
      text={
        eventType === "STARTING" ||
        eventType === "DELETING" ||
        eventType === "UPDATING" ||
        eventType === "STOPPING"
          ? "dark"
          : undefined
      }
      className="me-2 event-badge"
    >
      <FormattedMessage {...eventTypeMessages[eventType]} />
    </Badge>
  </div>
);

interface TimestampProps {
  children: Date;
}

const Timestamp = ({ children }: TimestampProps): React.ReactElement => {
  const formattedTimestamp = children.toISOString();

  return (
    <small className="text-secondary font-monospace me-2">{`${formattedTimestamp}`}</small>
  );
};

interface EventProps {
  event: Event;
}

const Event = ({ event }: EventProps) => {
  return (
    <li className="px-2 py-1 mb-1 border border-2 rounded-2">
      <div className="d-flex align-items-center gap-2">
        <EventType eventType={event.type} />
        <Timestamp>{new Date(event.insertedAt)}</Timestamp>
        <DeploymentEventMessage event={event} />
      </div>
    </li>
  );
};

interface DeploymentEventsViewProps {
  events: Event[];
}

const DeploymentEventsView = ({
  events,
}: DeploymentEventsViewProps): React.ReactElement => {
  return (
    <div className="device-event-container">
      <ul className="list-unstyled">
        {events.map((event, index: number) => (
          <Event key={index} event={event} />
        ))}
      </ul>
    </div>
  );
};

interface DeploymentEventsCardProps {
  events: Event[];
  className?: string;
}

const DeploymentEventsCard = ({
  events,
  className,
}: DeploymentEventsCardProps): React.ReactElement => (
  <FullHeightCard md={8} xs={12} className={className}>
    <Card.Body className="d-flex flex-column overflow-hidden">
      <DeploymentEventsView events={events} />
    </Card.Body>
  </FullHeightCard>
);

export default DeploymentEventsCard;
