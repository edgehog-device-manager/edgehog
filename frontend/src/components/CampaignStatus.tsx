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
  CampaignStatus as CampaignStatusEnum,
  CampaignStatus_CampaignStatusFragment$key,
} from "@/api/__generated__/CampaignStatus_CampaignStatusFragment.graphql";

import Icon from "@/components/Icon";

const CAMPAIGN_STATUS_FRAGMENT = graphql`
  fragment CampaignStatus_CampaignStatusFragment on Campaign {
    status
  }
`;

const colors: Record<CampaignStatusEnum, string> = {
  IDLE: "text-muted",
  IN_PROGRESS: "text-warning",
  FINISHED: "text-success",
};

const messages = defineMessages<CampaignStatusEnum>({
  IDLE: {
    id: "components.CampaignStatus.Idle",
    defaultMessage: "Idle",
  },
  IN_PROGRESS: {
    id: "components.CampaignStatus.InProgress",
    defaultMessage: "In progress",
  },
  FINISHED: {
    id: "components.CampaignStatus.Finished",
    defaultMessage: "Finished",
  },
});

type Props = {
  campaignRef: CampaignStatus_CampaignStatusFragment$key;
};

const CampaignStatus = ({ campaignRef }: Props) => {
  const { status } = useFragment(CAMPAIGN_STATUS_FRAGMENT, campaignRef);

  return (
    <div className="d-flex align-items-center">
      <Icon icon="circle" className={`me-2 ${colors[status]}`} />
      <span>
        <FormattedMessage id={messages[status].id} />
      </span>
    </div>
  );
};

export default CampaignStatus;
