/*
 * This file is part of Edgehog.
 *
 * Copyright 2023 - 2026 SECO Mind Srl
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
import { graphql, useFragment } from "react-relay/hooks";

import type {
  CampaignOutcome as CampaignOutcomeEnum,
  CampaignOutcome_CampaignOutcomeFragment$key,
} from "@/api/__generated__/CampaignOutcome_CampaignOutcomeFragment.graphql";

import Icon from "@/components/Icon";

const CAMPAIGN_OUTCOME_FRAGMENT = graphql`
  fragment CampaignOutcome_CampaignOutcomeFragment on Campaign {
    outcome
  }
`;

const colors: Record<CampaignOutcomeEnum, string> = {
  SUCCESS: "text-success",
  FAILURE: "text-danger",
};

const messages = defineMessages<CampaignOutcomeEnum>({
  SUCCESS: {
    id: "components.CampaignOutcome.Success",
    defaultMessage: "Success",
  },
  FAILURE: {
    id: "components.CampaignOutcome.Failure",
    defaultMessage: "Failure",
  },
});

interface Props {
  campaignRef: CampaignOutcome_CampaignOutcomeFragment$key;
}

const CampaignOutcome = ({ campaignRef }: Props) => {
  const { outcome } = useFragment(CAMPAIGN_OUTCOME_FRAGMENT, campaignRef);

  return (
    outcome && (
      <div className="d-flex align-items-center">
        <Icon icon="circle" className={`me-2 ${colors[outcome]}`} />
        <span>
          <FormattedMessage id={messages[outcome].id} />
        </span>
      </div>
    )
  );
};

export default CampaignOutcome;
