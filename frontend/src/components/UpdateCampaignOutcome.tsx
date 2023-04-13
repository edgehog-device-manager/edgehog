/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import { defineMessages, FormattedMessage } from "react-intl";
import type { MessageDescriptor } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  UpdateCampaignOutcome as UpdateCampaignOutcomeEnum,
  UpdateCampaignOutcome_UpdateCampaignOutcomeFragment$key,
} from "api/__generated__/UpdateCampaignOutcome_UpdateCampaignOutcomeFragment.graphql";

import Icon from "components/Icon";

const UPDATE_CAMPAIGN_OUTCOME_FRAGMENT = graphql`
  fragment UpdateCampaignOutcome_UpdateCampaignOutcomeFragment on UpdateCampaign {
    outcome
  }
`;

const getColor = (outcome: UpdateCampaignOutcomeEnum) => {
  switch (outcome) {
    case "SUCCESS":
      return "text-success";

    case "FAILURE":
      return "text-danger";

    default:
      return "text-muted";
  }
};

const messages: Record<string, MessageDescriptor> = defineMessages({
  SUCCESS: {
    id: "components.UpdateCampaignOutcome.Success",
    defaultMessage: "Success",
  },
  FAILURE: {
    id: "components.UpdateCampaignOutcome.Failure",
    defaultMessage: "Failure",
  },
  UnknownOutcome: {
    id: "components.UpdateCampaignOutcome.Unknown",
    defaultMessage: "Unknown",
  },
});

interface Props {
  updateCampaignRef: UpdateCampaignOutcome_UpdateCampaignOutcomeFragment$key;
}

const UpdateCampaignOutcome = ({ updateCampaignRef }: Props) => {
  const { outcome } = useFragment(
    UPDATE_CAMPAIGN_OUTCOME_FRAGMENT,
    updateCampaignRef
  );

  if (outcome === null) {
    return null;
  }

  const color = getColor(outcome);
  return (
    <div className="d-flex align-items-center">
      <Icon icon="circle" className={`me-2 ${color}`} />
      <span>
        <FormattedMessage
          id={messages[outcome]?.id || messages.UnknownOutcome.id}
        />
      </span>
    </div>
  );
};

export default UpdateCampaignOutcome;
