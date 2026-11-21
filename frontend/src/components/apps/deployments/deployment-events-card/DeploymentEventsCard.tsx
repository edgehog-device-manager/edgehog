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

import { useCallback, useMemo, useState } from "react";
import { Badge, Card, Col, Form, Row } from "react-bootstrap";
import { defineMessages, FormattedMessage, useIntl } from "react-intl";
import type { MultiValue } from "react-select";

import "@/components/apps/deployments/deployment-events-card/DeploymentEventsCard.scss";
import type {
  Event,
  ResourceEventType,
} from "@/components/apps/deployments/deployment-details/DeploymentDetails";
import DeploymentEventMessage from "@/components/apps/deployments/deployment-event-message/DeploymentEventMessage";
import FullHeightCard from "@/components/ui/full-height-card/FullHeightCard";
import MultiSelect from "@/components/ui/multi-select/MultiSelect";

const RESOURCE_EVENT_TYPES: readonly ResourceEventType[] = [
  "DeploymentEvent",
  "ContainerDeploymentEvent",
  "ImageDeploymentEvent",
  "VolumeDeploymentEvent",
  "NetworkDeploymentEvent",
  "EnvFileEvent",
  "FileBindEvent",
] as const;

const RESOURCE_EVENT_STATUSES = {
  DeploymentEvent: [
    "STARTING",
    "STARTED",
    "STOPPING",
    "STOPPED",
    "UPDATING",
    "DELETING",
    "ERROR",
  ],
  ContainerDeploymentEvent: [
    "ATTACH",
    "COMMIT",
    "COPY",
    "CREATE",
    "DESTROY",
    "DETACH",
    "DIE",
    "ERROR",
    "EXEC_CREATE",
    "EXEC_DETACH",
    "EXEC_DIE",
    "EXEC_START",
    "EXPORT",
    "HEALTH_STATUS",
    "KILL",
    "OOM",
    "PAUSE",
    "PRUNE",
    "RENAME",
    "RESIZE",
    "RESTART",
    "START",
    "STOP",
    "TOP",
    "UNPAUSE",
    "UPDATE",
  ],
  ImageDeploymentEvent: [
    "CREATE",
    "DELETE",
    "ERROR",
    "IMPORT",
    "LOAD",
    "PRUNE",
    "PULL",
    "PUSH",
    "SAVE",
    "TAG",
    "UNTAG",
  ],
  VolumeDeploymentEvent: [
    "CREATE",
    "DESTROY",
    "ERROR",
    "MOUNT",
    "PRUNE",
    "UNMOUNT",
  ],
  NetworkDeploymentEvent: [
    "CONNECT",
    "CREATE",
    "DESTROY",
    "DISCONNECT",
    "ERROR",
    "PRUNE",
    "REMOVE",
    "UPDATE",
  ],
  EnvFileEvent: ["ERROR"],
  FileBindEvent: ["ERROR"],
} as const satisfies Record<ResourceEventType, readonly string[]>;

export type EventStatus =
  (typeof RESOURCE_EVENT_STATUSES)[ResourceEventType][number];

const ALL_EVENT_STATUSES: readonly EventStatus[] = Array.from(
  new Set(Object.values(RESOURCE_EVENT_STATUSES).flat()),
);

const isResourceEventType = (value: string): value is ResourceEventType =>
  (RESOURCE_EVENT_TYPES as readonly string[]).includes(value);

const isEventStatus = (value: string): value is EventStatus =>
  (ALL_EVENT_STATUSES as readonly string[]).includes(value);

const getEventTypeVariant = (eventType: string): string => {
  switch (eventType) {
    case "ERROR":
    case "DIE":
    case "EXEC_DIE":
    case "KILL":
    case "OOM":
      return "danger";
    case "STARTED":
    case "START":
    case "CREATE":
    case "EXEC_CREATE":
    case "EXEC_START":
    case "PULL":
    case "IMPORT":
    case "LOAD":
    case "MOUNT":
    case "CONNECT":
    case "UNPAUSE":
    case "HEALTH_STATUS":
      return "success";
    case "STARTING":
    case "STOPPING":
    case "DELETING":
    case "UPDATING":
    case "UPDATE":
    case "RESTART":
    case "PAUSE":
    case "RENAME":
    case "RESIZE":
      return "warning";
    case "STOPPED":
    case "STOP":
    case "DESTROY":
    case "DELETE":
    case "REMOVE":
    case "PRUNE":
    case "UNMOUNT":
    case "DISCONNECT":
    case "DETACH":
    case "EXEC_DETACH":
    case "UNTAG":
    case "ATTACH":
    case "COMMIT":
    case "COPY":
    case "EXPORT":
    case "PUSH":
    case "SAVE":
    case "TAG":
    case "TOP":
    default:
      return "secondary";
  }
};

const resourceTypeMessages = defineMessages<ResourceEventType>({
  DeploymentEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.Deployment",
    defaultMessage: "Deployment",
  },
  ContainerDeploymentEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.Container",
    defaultMessage: "Container",
  },
  ImageDeploymentEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.Image",
    defaultMessage: "Image",
  },
  VolumeDeploymentEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.Volume",
    defaultMessage: "Volume",
  },
  NetworkDeploymentEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.Network",
    defaultMessage: "Network",
  },
  EnvFileEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.EnvFile",
    defaultMessage: "Env File",
  },
  FileBindEvent: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceType.FileBind",
    defaultMessage: "File Bind",
  },
});

const eventTypeMessages = defineMessages<EventStatus>({
  ATTACH: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Attach",
    defaultMessage: "Attach",
  },
  COMMIT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Commit",
    defaultMessage: "Commit",
  },
  CONNECT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Connect",
    defaultMessage: "Connect",
  },
  COPY: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Copy",
    defaultMessage: "Copy",
  },
  CREATE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Create",
    defaultMessage: "Create",
  },
  DELETE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Delete",
    defaultMessage: "Delete",
  },
  DELETING: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Deleting",
    defaultMessage: "Deleting",
  },
  DESTROY: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Destroy",
    defaultMessage: "Destroy",
  },
  DETACH: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Detach",
    defaultMessage: "Detach",
  },
  DIE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Die",
    defaultMessage: "Die",
  },
  DISCONNECT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Disconnect",
    defaultMessage: "Disconnect",
  },
  ERROR: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Error",
    defaultMessage: "Error",
  },
  EXEC_CREATE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.ExecCreate",
    defaultMessage: "Exec Create",
  },
  EXEC_DETACH: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.ExecDetach",
    defaultMessage: "Exec Detach",
  },
  EXEC_DIE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.ExecDie",
    defaultMessage: "Exec Die",
  },
  EXEC_START: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.ExecStart",
    defaultMessage: "Exec Start",
  },
  EXPORT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Export",
    defaultMessage: "Export",
  },
  HEALTH_STATUS: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.HealthStatus",
    defaultMessage: "Health Status",
  },
  IMPORT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Import",
    defaultMessage: "Import",
  },
  KILL: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Kill",
    defaultMessage: "Kill",
  },
  LOAD: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Load",
    defaultMessage: "Load",
  },
  MOUNT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Mount",
    defaultMessage: "Mount",
  },
  OOM: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Oom",
    defaultMessage: "Out of Memory",
  },
  PAUSE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Pause",
    defaultMessage: "Pause",
  },
  PRUNE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Prune",
    defaultMessage: "Prune",
  },
  PULL: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Pull",
    defaultMessage: "Pull",
  },
  PUSH: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Push",
    defaultMessage: "Push",
  },
  REMOVE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Remove",
    defaultMessage: "Remove",
  },
  RENAME: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Rename",
    defaultMessage: "Rename",
  },
  RESIZE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Resize",
    defaultMessage: "Resize",
  },
  RESTART: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Restart",
    defaultMessage: "Restart",
  },
  SAVE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Save",
    defaultMessage: "Save",
  },
  START: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Start",
    defaultMessage: "Start",
  },
  STARTED: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Started",
    defaultMessage: "Started",
  },
  STARTING: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Starting",
    defaultMessage: "Starting",
  },
  STOP: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Stop",
    defaultMessage: "Stop",
  },
  STOPPED: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Stopped",
    defaultMessage: "Stopped",
  },
  STOPPING: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Stopping",
    defaultMessage: "Stopping",
  },
  TAG: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Tag",
    defaultMessage: "Tag",
  },
  TOP: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Top",
    defaultMessage: "Top",
  },
  UNMOUNT: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Unmount",
    defaultMessage: "Unmount",
  },
  UNPAUSE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Unpause",
    defaultMessage: "Unpause",
  },
  UNTAG: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Untag",
    defaultMessage: "Untag",
  },
  UPDATE: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Update",
    defaultMessage: "Update",
  },
  UPDATING: {
    id: "components.apps.deployments.deployment-events-card.DeploymentEventsCard.Updating",
    defaultMessage: "Updating",
  },
});

const ResourceTypeBadge = ({ resourceType }: { resourceType: string }) => (
  <div className="d-flex align-items-center">
    <Badge
      bg="light"
      text="dark"
      className="me-1 border resource-badge"
      data-testid="event-resource-type"
    >
      {isResourceEventType(resourceType) ? (
        <FormattedMessage {...resourceTypeMessages[resourceType]} />
      ) : (
        resourceType
      )}
    </Badge>
  </div>
);

const EventType = ({ eventType }: { eventType: string }) => {
  const variant = getEventTypeVariant(eventType);

  return (
    <div className="d-flex align-items-center">
      <Badge
        bg={variant}
        text={variant === "warning" ? "dark" : undefined}
        className="me-2 event-badge"
        data-testid="event-status-type"
      >
        {isEventStatus(eventType) ? (
          <FormattedMessage {...eventTypeMessages[eventType]} />
        ) : (
          eventType
        )}
      </Badge>
    </div>
  );
};

interface TimestampProps {
  children: Date;
}

const Timestamp = ({ children }: TimestampProps): React.ReactElement => {
  const formattedTimestamp = Number.isNaN(children.getTime())
    ? ""
    : children.toISOString();

  return (
    <small className="text-secondary font-monospace me-2">{`${formattedTimestamp}`}</small>
  );
};

interface EventProps {
  event: Event;
}

const EventItem = ({ event }: EventProps) => {
  return (
    <li className="px-2 py-1 mb-1 border border-2 rounded-2">
      <div className="d-flex align-items-center gap-2">
        <ResourceTypeBadge resourceType={event.__typename} />
        <EventType eventType={event.status} />
        {event.timestamp && <Timestamp>{new Date(event.timestamp)}</Timestamp>}
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
          <EventItem
            key={`${event.__typename}-${event.resourceId}-${event.status}-${event.timestamp ?? index}-${index}`}
            event={event}
          />
        ))}
      </ul>
    </div>
  );
};

type FilterOption<T extends string> = {
  value: T;
  label: string;
};

interface DeploymentEventsCardProps {
  events: Event[];
  className?: string;
}

const DeploymentEventsCard = ({
  events,
  className,
}: DeploymentEventsCardProps): React.ReactElement => {
  const intl = useIntl();

  const [selectedResourceTypes, setSelectedResourceTypes] = useState<
    readonly FilterOption<ResourceEventType>[]
  >([]);
  const [selectedStatuses, setSelectedStatuses] = useState<
    readonly FilterOption<EventStatus>[]
  >([]);

  const resourceTypeOptions = useMemo<FilterOption<ResourceEventType>[]>(
    () =>
      RESOURCE_EVENT_TYPES.map((resourceType) => ({
        value: resourceType,
        label: intl.formatMessage(resourceTypeMessages[resourceType]),
      })),
    [intl],
  );

  const availableStatuses = useMemo<readonly EventStatus[]>(() => {
    if (selectedResourceTypes.length === 0) {
      return ALL_EVENT_STATUSES;
    }

    return Array.from(
      new Set(
        selectedResourceTypes.flatMap(
          (option) => RESOURCE_EVENT_STATUSES[option.value],
        ),
      ),
    );
  }, [selectedResourceTypes]);

  const eventStatusOptions = useMemo<FilterOption<EventStatus>[]>(
    () =>
      availableStatuses.map((status) => ({
        value: status,
        label: intl.formatMessage(eventTypeMessages[status]),
      })),
    [availableStatuses, intl],
  );

  const handleResourceTypesChange = useCallback(
    (nextResourceTypes: MultiValue<FilterOption<ResourceEventType>>) => {
      setSelectedResourceTypes(nextResourceTypes);

      if (nextResourceTypes.length > 0) {
        const validStatuses = new Set<string>(
          nextResourceTypes.flatMap(
            (option) => RESOURCE_EVENT_STATUSES[option.value],
          ),
        );
        setSelectedStatuses((prev) =>
          prev.filter((option) => validStatuses.has(option.value)),
        );
      }
    },
    [],
  );

  const handleStatusesChange = useCallback(
    (nextStatuses: MultiValue<FilterOption<EventStatus>>) => {
      setSelectedStatuses(nextStatuses);
    },
    [],
  );

  const filteredEvents = useMemo(() => {
    return events.filter((event) => {
      const matchesResourceType =
        selectedResourceTypes.length === 0 ||
        selectedResourceTypes.some(
          (option) => option.value === event.__typename,
        );
      const matchesStatus =
        selectedStatuses.length === 0 ||
        selectedStatuses.some((option) => option.value === event.status);

      return matchesResourceType && matchesStatus;
    });
  }, [events, selectedResourceTypes, selectedStatuses]);

  return (
    <FullHeightCard md={8} xs={12} className={className}>
      <Card.Body className="d-flex flex-column overflow-hidden">
        <Row className="g-2 mb-3">
          <Col md={6} xs={12}>
            <Form.Label className="small text-secondary mb-1">
              <FormattedMessage
                id="components.apps.deployments.deployment-events-card.DeploymentEventsCard.resourceTypeFilterLabel"
                defaultMessage="Resource Type"
              />
            </Form.Label>
            <MultiSelect
              options={resourceTypeOptions}
              value={selectedResourceTypes}
              onChange={handleResourceTypesChange}
              getOptionValue={(option) => option.value}
              getOptionLabel={(option) => option.label}
            />
          </Col>
          <Col md={6} xs={12}>
            <Form.Label className="small text-secondary mb-1">
              <FormattedMessage
                id="components.apps.deployments.deployment-events-card.DeploymentEventsCard.eventTypeFilterLabel"
                defaultMessage="Event Type"
              />
            </Form.Label>
            <MultiSelect
              options={eventStatusOptions}
              value={selectedStatuses}
              onChange={handleStatusesChange}
              getOptionValue={(option) => option.value}
              getOptionLabel={(option) => option.label}
            />
          </Col>
        </Row>
        <DeploymentEventsView events={filteredEvents} />
      </Card.Body>
    </FullHeightCard>
  );
};

export default DeploymentEventsCard;
