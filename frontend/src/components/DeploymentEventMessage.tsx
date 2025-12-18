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
import { FormattedMessage } from "react-intl";

import { DeploymentTargetsTable_DeploymentTargetsFragment$data } from "@/api/__generated__/DeploymentTargetsTable_DeploymentTargetsFragment.graphql";

import CollapseItem from "@/components/CollapseItem";

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
  const addInfo = useMemo(() => {
    if (!event.addInfo || event.addInfo.length === 0) return null;

    return (
      <pre style={{ whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
        {event.addInfo.map((line, index) => (
          <div
            key={index}
            style={{
              paddingLeft: `${index * 16}px`,
            }}
          >
            {line}
          </div>
        ))}
      </pre>
    );
  }, [event.addInfo]);

  if (!event.addInfo || event.addInfo.length === 0) {
    return (
      <>
        {event.message ?? (
          <FormattedMessage
            id="components.DeploymentEventMessage.noMessage"
            defaultMessage="No message in event."
          />
        )}
      </>
    );
  }

  return (
    <CollapseItem
      title={
        event.message ?? (
          <FormattedMessage
            id="components.DeploymentEventMessage.noShortMessage"
            defaultMessage="No short message. Click to show extended info."
          />
        )
      }
      type="flat"
      open={isOpen}
      onToggle={toggleIsOpen}
      isInsideTable
    >
      <div className="mt-1 p-1 bg-light">{addInfo}</div>
    </CollapseItem>
  );
};

export default DeploymentEventMessage;
