/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { useCallback, useMemo, useState } from "react";
import { Collapse } from "react-bootstrap";
import { FormattedMessage } from "react-intl";

import { DeploymentTargetsTable_DeploymentTargetsFragment$data } from "@/api/__generated__/DeploymentTargetsTable_DeploymentTargetsFragment.graphql";

import Button from "@/components/Button";
import Icon from "@/components/Icon";
import "./DeploymentEventMessage.scss";

type DeploymentEventMessageProps = {
  event: NonNullable<
    NonNullable<
      DeploymentTargetsTable_DeploymentTargetsFragment$data[number]["deployment"]
    >["events"]["edges"]
  >[number]["node"];
};

const DeploymentEventMessage = ({ event }: DeploymentEventMessageProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const toggleIsOpen = useCallback(() => setIsOpen((o) => !o), []);
  const addInfo = useMemo(
    () =>
      event.addInfo && event.addInfo.length > 0 ? (
        <pre className="deployment-event-message-wrap add-info">
          {event.addInfo.map(
            (line, index) => " ".repeat(2 * index) + line + "\n",
          )}
        </pre>
      ) : (
        <></>
      ),
    [event],
  );

  return (
    <>
      {event.addInfo && event.addInfo.length > 0 ? (
        <div className="deployment-event-message">
          <div className="deployment-event-message-wrap">
            <Button
              onClick={toggleIsOpen}
              className="pt-0 pb-2 d-flex align-items-center justify-content-start deployment-event-message-button"
            >
              {event.message ?? (
                <FormattedMessage
                  id="components.DeploymentEventMessage.noShortMessage"
                  defaultMessage="No short message. Click to show extended info."
                />
              )}
              <Icon
                icon="chevronDown"
                className={"status-chevron-icon " + (isOpen ? "closed" : "")}
              />
            </Button>
          </div>
          <Collapse in={isOpen}>{addInfo}</Collapse>
          <div className="ghost-spacer">{addInfo}</div>
        </div>
      ) : (
        (event.message ?? (
          <FormattedMessage
            id="components.DeploymentEventMessage.noMessage"
            defaultMessage="No message in event."
          />
        ))
      )}
    </>
  );
};

export default DeploymentEventMessage;
