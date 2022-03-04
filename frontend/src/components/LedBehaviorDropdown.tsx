/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

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

import { useCallback } from "react";
import graphql from "babel-plugin-relay/macro";
import { useMutation } from "react-relay/hooks";
import { defineMessages, FormattedMessage, useIntl } from "react-intl";
import type { MessageDescriptor } from "react-intl";

import ButtonGroup from "react-bootstrap/ButtonGroup";
import Dropdown from "react-bootstrap/Dropdown";

import Spinner from "components/Spinner";

import type { LedBehaviorDropdown_setLedBehavior_Mutation } from "api/__generated__/LedBehaviorDropdown_setLedBehavior_Mutation.graphql";

const SET_LED_BEHAVIOR_MUTATION = graphql`
  mutation LedBehaviorDropdown_setLedBehavior_Mutation(
    $input: SetLedBehaviorInput!
  ) {
    setLedBehavior(input: $input) {
      behavior
    }
  }
`;

const SUPPORTED_LED_BEHAVIORS = [
  "BLINK",
  "DOUBLE_BLINK",
  "SLOW_BLINK",
] as const;
type SupportedLedBehavior = typeof SUPPORTED_LED_BEHAVIORS[number];

const supportedBehaviorMessages: Record<
  SupportedLedBehavior,
  MessageDescriptor
> = defineMessages({
  BLINK: {
    id: "components.LedBehaviorDropdown.behavior.blinkLED",
    defaultMessage: "Blink LED",
  },
  DOUBLE_BLINK: {
    id: "components.LedBehaviorDropdown.behavior.doubleBlinkLED",
    defaultMessage: "Double blink LED",
  },
  SLOW_BLINK: {
    id: "components.LedBehaviorDropdown.behavior.slowBlinkLED",
    defaultMessage: "Slow blink LED",
  },
});

function isSupportedLedBehavior(value: unknown): value is SupportedLedBehavior {
  return (
    typeof value === "string" &&
    SUPPORTED_LED_BEHAVIORS.includes(value as SupportedLedBehavior)
  );
}

interface Props {
  deviceId: string;
  disabled: boolean;
}

const LedBehaviorDropdown = ({ deviceId, disabled }: Props) => {
  const intl = useIntl();

  const [setLedBehavior, isSettingLedBehavior] =
    useMutation<LedBehaviorDropdown_setLedBehavior_Mutation>(
      SET_LED_BEHAVIOR_MUTATION
    );

  const handleSetLedBehavior = useCallback(
    (ledBehavior: unknown) => {
      if (!isSupportedLedBehavior(ledBehavior)) {
        return;
      }

      setLedBehavior({
        variables: {
          input: {
            deviceId,
            behavior: ledBehavior,
          },
        },
      });
    },
    [setLedBehavior, deviceId]
  );

  return (
    <Dropdown as={ButtonGroup} onSelect={handleSetLedBehavior}>
      <Dropdown.Toggle
        variant="secondary"
        disabled={disabled || isSettingLedBehavior}
      >
        {isSettingLedBehavior && (
          <Spinner as="span" size="sm" className="me-2" aria-hidden="true" />
        )}
        <FormattedMessage
          id="components.LedBehaviorDropdown.identify"
          defaultMessage="Identify"
        />
      </Dropdown.Toggle>
      <Dropdown.Menu>
        {SUPPORTED_LED_BEHAVIORS.map((behavior) => (
          <Dropdown.Item eventKey={behavior} key={behavior}>
            {intl.formatMessage(supportedBehaviorMessages[behavior])}
          </Dropdown.Item>
        ))}
      </Dropdown.Menu>
    </Dropdown>
  );
};

export default LedBehaviorDropdown;
